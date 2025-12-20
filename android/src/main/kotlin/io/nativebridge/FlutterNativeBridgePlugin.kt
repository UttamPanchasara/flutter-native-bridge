package io.nativebridge

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.lang.reflect.Method

/**
 * Flutter Native Bridge Plugin
 *
 * Bridges Flutter and native Android code using reflection.
 * Supports both MethodChannel (request-response) and EventChannel (streams).
 */
class FlutterNativeBridgePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private var binaryMessenger: BinaryMessenger? = null
    private var activity: Activity? = null

    companion object {
        private const val TAG = "FlutterNativeBridge"
        private const val CHANNEL_NAME = "flutter_native_bridge"
        private const val EVENT_CHANNEL_PREFIX = "flutter_native_bridge/events/"
        private val registeredObjects = mutableMapOf<String, Any>()

        // Track active event channels and their sinks
        private val activeEventChannels = mutableMapOf<String, EventChannel>()
        private val activeStreamSinks = mutableMapOf<String, EventSinkWrapper>()

        // Reference to the plugin instance for setting up event channels
        private var pluginInstance: FlutterNativeBridgePlugin? = null

        /**
         * Register an object with a custom name.
         * Use this to avoid conflicts when classes have the same simple name.
         */
        @JvmStatic
        fun register(name: String, obj: Any) {
            if (registeredObjects.containsKey(name)) {
                val existing = registeredObjects[name]!!::class.java.name
                val new = obj::class.java.name
                android.util.Log.w(TAG, "Overwriting '$name': $existing -> $new")
            }
            registeredObjects[name] = obj
            // Setup event channels for newly registered object
            pluginInstance?.setupEventChannelsForObject(name, obj)
        }

        /**
         * Register an object using its class simple name.
         * Warns if a class with the same name is already registered.
         */
        @JvmStatic
        fun register(obj: Any) {
            val name = obj::class.java.simpleName
            if (registeredObjects.containsKey(name)) {
                val existing = registeredObjects[name]!!::class.java.name
                val new = obj::class.java.name
                if (existing != new) {
                    android.util.Log.e(TAG,
                        "Name conflict! '$name' already registered as $existing. " +
                        "Use register(\"CustomName\", obj) for $new")
                    return  // Don't overwrite with conflicting class
                }
            }
            registeredObjects[name] = obj
            // Setup event channels for newly registered object
            pluginInstance?.setupEventChannelsForObject(name, obj)
        }

        @JvmStatic
        fun unregister(name: String) {
            // Clean up any event channels for this object
            val prefix = "${EVENT_CHANNEL_PREFIX}$name."
            activeEventChannels.keys.filter { it.startsWith(prefix) }.forEach { channelName ->
                activeEventChannels[channelName]?.setStreamHandler(null)
                activeEventChannels.remove(channelName)
                activeStreamSinks.remove(channelName)
            }
            registeredObjects.remove(name)
        }

        /**
         * Check if a name is already registered.
         */
        @JvmStatic
        fun isRegistered(name: String): Boolean = registeredObjects.containsKey(name)

        /**
         * Get all registered class names.
         */
        @JvmStatic
        fun getRegisteredNames(): Set<String> = registeredObjects.keys.toSet()
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binaryMessenger = binding.binaryMessenger
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)

        // Store plugin instance for late registration
        pluginInstance = this

        // Setup event channels for any already registered stream methods
        setupEventChannels()
    }

    /**
     * Setup EventChannels for all @NativeStream annotated methods.
     */
    private fun setupEventChannels() {
        for ((className, target) in registeredObjects) {
            setupEventChannelsForObject(className, target)
        }
    }

    /**
     * Setup EventChannels for a single registered object.
     * Called when a new object is registered.
     */
    fun setupEventChannelsForObject(className: String, target: Any) {
        val messenger = binaryMessenger ?: return

        val streamMethods = getStreamMethods(target)
        for (methodName in streamMethods) {
            val channelName = "$EVENT_CHANNEL_PREFIX$className.$methodName"

            // Skip if already setup
            if (activeEventChannels.containsKey(channelName)) continue

            val eventChannel = EventChannel(messenger, channelName)
            eventChannel.setStreamHandler(createStreamHandler(className, methodName, target))
            activeEventChannels[channelName] = eventChannel

            android.util.Log.d(TAG, "Setup EventChannel: $channelName")
        }
    }

    /**
     * Create a StreamHandler for a specific stream method.
     */
    private fun createStreamHandler(
        className: String,
        methodName: String,
        target: Any
    ): EventChannel.StreamHandler {
        return object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                if (events == null) return

                val channelName = "$EVENT_CHANNEL_PREFIX$className.$methodName"
                val sinkWrapper = EventSinkWrapper(events)
                activeStreamSinks[channelName] = sinkWrapper

                // Find and invoke the stream method with the sink
                try {
                    val method = findStreamMethod(target, methodName)
                    if (method != null) {
                        invokeStreamMethod(target, method, sinkWrapper, arguments)
                    } else {
                        events.error("NOT_FOUND", "Stream method '$methodName' not found", null)
                    }
                } catch (e: Exception) {
                    events.error("INVOKE_ERROR", e.message ?: "Unknown error", e.stackTraceToString())
                }
            }

            override fun onCancel(arguments: Any?) {
                val channelName = "$EVENT_CHANNEL_PREFIX$className.$methodName"
                activeStreamSinks.remove(channelName)
                android.util.Log.d(TAG, "Stream cancelled: $channelName")
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        // Handle discovery methods
        when (call.method) {
            "_getRegisteredClasses" -> {
                result.success(registeredObjects.keys.toList())
                return
            }
            "_getMethods" -> {
                handleGetMethods(call, result)
                return
            }
            "_getStreams" -> {
                handleGetStreams(call, result)
                return
            }
            "_discover" -> {
                result.success(registeredObjects.mapValues { (_, obj) -> getExposedMethods(obj) })
                return
            }
            "_discoverStreams" -> {
                result.success(registeredObjects.mapValues { (_, obj) -> getStreamMethods(obj) })
                return
            }
        }

        // Handle regular method calls (ClassName.methodName)
        val parts = call.method.split(".")
        if (parts.size != 2) {
            result.error("INVALID_FORMAT", "Method must be 'ClassName.methodName'", null)
            return
        }

        val (className, methodName) = parts
        val target = registeredObjects[className]

        if (target == null) {
            result.error("NOT_FOUND", "Class '$className' not registered", null)
            return
        }

        val method = findMethod(target, methodName)
        if (method == null) {
            result.error("NOT_FOUND", "Method '$methodName' not found or not exposed", null)
            return
        }

        try {
            val returnValue = invokeMethod(target, method, call.arguments)
            result.success(returnValue)
        } catch (e: Exception) {
            result.error("INVOKE_ERROR", e.message ?: "Unknown error", e.stackTraceToString())
        }
    }

    private fun handleGetMethods(call: MethodCall, result: Result) {
        val className = call.arguments as? String
        if (className == null) {
            result.error("INVALID_ARG", "Class name required", null)
            return
        }
        val target = registeredObjects[className]
        if (target == null) {
            result.error("NOT_FOUND", "Class '$className' not registered", null)
            return
        }
        result.success(getExposedMethods(target))
    }

    private fun handleGetStreams(call: MethodCall, result: Result) {
        val className = call.arguments as? String
        if (className == null) {
            result.error("INVALID_ARG", "Class name required", null)
            return
        }
        val target = registeredObjects[className]
        if (target == null) {
            result.error("NOT_FOUND", "Class '$className' not registered", null)
            return
        }
        result.success(getStreamMethods(target))
    }

    private fun findMethod(target: Any, methodName: String): Method? {
        val clazz = target::class.java
        val hasNativeBridge = clazz.isAnnotationPresent(NativeBridge::class.java)

        return clazz.methods.find { method ->
            method.name == methodName && when {
                hasNativeBridge -> {
                    !method.isAnnotationPresent(NativeIgnore::class.java) &&
                    !method.isAnnotationPresent(NativeStream::class.java)
                }
                else -> method.isAnnotationPresent(NativeFunction::class.java)
            }
        }
    }

    private fun getExposedMethods(target: Any): List<String> {
        val clazz = target::class.java
        val hasNativeBridge = clazz.isAnnotationPresent(NativeBridge::class.java)

        return clazz.methods
            .filter { method ->
                // Exclude stream methods from regular methods
                if (method.isAnnotationPresent(NativeStream::class.java)) return@filter false

                when {
                    hasNativeBridge -> !method.isAnnotationPresent(NativeIgnore::class.java)
                    else -> method.isAnnotationPresent(NativeFunction::class.java)
                }
            }
            .filter { it.declaringClass != Any::class.java }
            .map { it.name }
            .distinct()
    }

    /**
     * Get all @NativeStream annotated methods for a target.
     */
    private fun getStreamMethods(target: Any): List<String> {
        val clazz = target::class.java
        return clazz.methods
            .filter { it.isAnnotationPresent(NativeStream::class.java) }
            .filter { it.declaringClass != Any::class.java }
            .map { it.name }
            .distinct()
    }

    /**
     * Find a @NativeStream annotated method by name.
     */
    private fun findStreamMethod(target: Any, methodName: String): Method? {
        val clazz = target::class.java
        return clazz.methods.find { method ->
            method.name == methodName && method.isAnnotationPresent(NativeStream::class.java)
        }
    }

    /**
     * Invoke a stream method, passing the StreamSink as parameter.
     */
    private fun invokeStreamMethod(target: Any, method: Method, sink: StreamSink, args: Any?) {
        method.isAccessible = true

        // Check if method expects StreamSink as first parameter
        val params = method.parameters
        when {
            params.isEmpty() -> {
                // No parameters - shouldn't happen for stream methods
                method.invoke(target)
            }
            params.size == 1 && params[0].type == StreamSink::class.java -> {
                // Just StreamSink
                method.invoke(target, sink)
            }
            params.size == 2 && params[0].type == StreamSink::class.java -> {
                // StreamSink + arguments
                method.invoke(target, sink, args)
            }
            params[0].type == StreamSink::class.java && args is Map<*, *> -> {
                // StreamSink + multiple arguments as map
                val values = mutableListOf<Any?>(sink)
                params.drop(1).forEach { param ->
                    values.add(args[param.name] ?: args[param.name.removePrefix("arg")])
                }
                method.invoke(target, *values.toTypedArray())
            }
            else -> {
                // Fallback: try to invoke with sink and args
                method.invoke(target, sink, args)
            }
        }
    }

    private fun invokeMethod(target: Any, method: Method, args: Any?): Any? {
        method.isAccessible = true

        return when {
            method.parameterCount == 0 -> method.invoke(target)
            method.parameterCount == 1 -> method.invoke(target, args)
            args is Map<*, *> -> {
                val values = method.parameters.map { param ->
                    args[param.name] ?: args[param.name.removePrefix("arg")]
                }.toTypedArray()
                method.invoke(target, *values)
            }
            args is List<*> -> method.invoke(target, *args.toTypedArray())
            else -> method.invoke(target, args)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)

        // Clean up all event channels
        activeEventChannels.values.forEach { it.setStreamHandler(null) }
        activeEventChannels.clear()
        activeStreamSinks.clear()
        binaryMessenger = null
        pluginInstance = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}

/**
 * Wraps Flutter's EventChannel.EventSink to implement our StreamSink interface.
 * This allows native code to emit events without depending on Flutter classes directly.
 */
internal class EventSinkWrapper(private val eventSink: EventChannel.EventSink) : StreamSink {

    override fun success(event: Any?) {
        eventSink.success(event)
    }

    override fun error(code: String, message: String?, details: Any?) {
        eventSink.error(code, message, details)
    }

    override fun endOfStream() {
        eventSink.endOfStream()
    }
}
