package io.nativebridge

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.lang.reflect.Method

/**
 * Flutter Native Bridge Plugin
 *
 * Bridges Flutter and native Android code using reflection.
 * No code generation required on the native side.
 */
class FlutterNativeBridgePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null

    companion object {
        private const val CHANNEL_NAME = "flutter_native_bridge"
        private val registeredObjects = mutableMapOf<String, Any>()

        @JvmStatic
        fun register(name: String, obj: Any) {
            registeredObjects[name] = obj
        }

        @JvmStatic
        fun register(obj: Any) {
            registeredObjects[obj::class.java.simpleName] = obj
        }

        @JvmStatic
        fun unregister(name: String) {
            registeredObjects.remove(name)
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
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
            "_discover" -> {
                result.success(registeredObjects.mapValues { (_, obj) -> getExposedMethods(obj) })
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

    private fun findMethod(target: Any, methodName: String): Method? {
        val clazz = target::class.java
        val hasNativeBridge = clazz.isAnnotationPresent(NativeBridge::class.java)

        return clazz.methods.find { method ->
            method.name == methodName && when {
                hasNativeBridge -> !method.isAnnotationPresent(NativeIgnore::class.java)
                else -> method.isAnnotationPresent(NativeFunction::class.java)
            }
        }
    }

    private fun getExposedMethods(target: Any): List<String> {
        val clazz = target::class.java
        val hasNativeBridge = clazz.isAnnotationPresent(NativeBridge::class.java)

        return clazz.methods
            .filter { method ->
                when {
                    hasNativeBridge -> !method.isAnnotationPresent(NativeIgnore::class.java)
                    else -> method.isAnnotationPresent(NativeFunction::class.java)
                }
            }
            .filter { it.declaringClass != Any::class.java }
            .map { it.name }
            .distinct()
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
