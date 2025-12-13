package io.nativebridge

/**
 * Marks a class as a Native Bridge.
 * All public methods become callable from Flutter.
 * Use @NativeIgnore to exclude specific methods.
 *
 * Example:
 * ```kotlin
 * @NativeBridge
 * class DeviceService {
 *     fun getModel(): String = Build.MODEL
 *
 *     @NativeIgnore
 *     fun internalMethod() { }
 * }
 * ```
 */
@Target(AnnotationTarget.CLASS)
@Retention(AnnotationRetention.RUNTIME)
annotation class NativeBridge

/**
 * Marks a single method as callable from Flutter.
 * Use on classes without @NativeBridge annotation.
 *
 * Example:
 * ```kotlin
 * class MainActivity : FlutterActivity() {
 *     @NativeFunction
 *     fun greet(name: String): String = "Hello, $name!"
 * }
 * ```
 */
@Target(AnnotationTarget.FUNCTION)
@Retention(AnnotationRetention.RUNTIME)
annotation class NativeFunction

/**
 * Excludes a method from being callable from Flutter.
 * Use within @NativeBridge annotated classes.
 */
@Target(AnnotationTarget.FUNCTION)
@Retention(AnnotationRetention.RUNTIME)
annotation class NativeIgnore

/**
 * Flutter Native Bridge - Registration Helper
 *
 * Provides simple one-line registration with auto-discovery of annotated classes.
 *
 * Usage in MainActivity:
 * ```kotlin
 * override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
 *     super.configureFlutterEngine(flutterEngine)
 *     FlutterNativeBridge.register(this)
 * }
 * ```
 */
object FlutterNativeBridge {
    private const val TAG = "FlutterNativeBridge"
    private var context: android.content.Context? = null
    private var activity: android.app.Activity? = null

    /**
     * Register activity and auto-discover all @NativeBridge/@NativeFunction classes.
     *
     * This method:
     * 1. Registers the activity if it has @NativeFunction methods
     * 2. Scans the app package for classes with @NativeBridge or @NativeFunction
     * 3. Auto-instantiates and registers discovered classes
     *
     * @param activityInstance The FlutterActivity instance
     */
    fun register(activityInstance: android.app.Activity) {
        activity = activityInstance
        context = activityInstance.applicationContext

        // Register activity only if it has native methods
        if (hasNativeMethods(activityInstance.javaClass)) {
            FlutterNativeBridgePlugin.register(activityInstance)
        }

        // Auto-discover and register other classes
        autoRegisterClasses(activityInstance)
    }

    /**
     * Manually register specific objects.
     * Use when auto-discovery doesn't work or for custom instances.
     *
     * @param objects Objects to register (uses class simple name as key)
     */
    fun registerObjects(vararg objects: Any) {
        objects.forEach { FlutterNativeBridgePlugin.register(it) }
    }

    /**
     * Register an object with a custom name.
     *
     * @param name Custom name for the object
     * @param obj Object to register
     */
    fun register(name: String, obj: Any) {
        FlutterNativeBridgePlugin.register(name, obj)
    }

    private fun hasNativeMethods(clazz: Class<*>): Boolean {
        if (clazz.isAnnotationPresent(NativeBridge::class.java)) return true
        return clazz.methods.any { it.isAnnotationPresent(NativeFunction::class.java) }
    }

    private fun autoRegisterClasses(activity: android.app.Activity) {
        try {
            val packageName = activity.javaClass.`package`?.name ?: return
            val classes = findAnnotatedClasses(activity, packageName)

            for (clazz in classes) {
                if (clazz == activity.javaClass) continue

                val instance = createInstance(clazz)
                if (instance != null) {
                    FlutterNativeBridgePlugin.register(instance)
                }
            }
        } catch (e: Exception) {
            android.util.Log.w(TAG, "Auto-discovery failed, use registerObjects() as fallback: ${e.message}")
        }
    }

    private fun findAnnotatedClasses(context: android.content.Context, packageName: String): List<Class<*>> {
        val classes = mutableListOf<Class<*>>()
        try {
            val classLoader = context.classLoader
            if (classLoader is dalvik.system.BaseDexClassLoader) {
                val pathListField = dalvik.system.BaseDexClassLoader::class.java.getDeclaredField("pathList")
                pathListField.isAccessible = true
                val pathList = pathListField.get(classLoader)

                val dexElementsField = pathList.javaClass.getDeclaredField("dexElements")
                dexElementsField.isAccessible = true
                val dexElements = dexElementsField.get(pathList) as Array<*>

                for (element in dexElements) {
                    val dexFileField = element!!.javaClass.getDeclaredField("dexFile")
                    dexFileField.isAccessible = true
                    val dexFile = dexFileField.get(element) as? dalvik.system.DexFile ?: continue

                    val entries = dexFile.entries()
                    while (entries.hasMoreElements()) {
                        val className = entries.nextElement()
                        if (className.startsWith(packageName) && !className.contains("$")) {
                            try {
                                val clazz = Class.forName(className, false, context.classLoader)
                                if (hasNativeMethods(clazz)) {
                                    classes.add(clazz)
                                }
                            } catch (_: Exception) { }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.d(TAG, "Class scanning error: ${e.message}")
        }
        return classes
    }

    private fun createInstance(clazz: Class<*>): Any? {
        // Try Activity constructor
        return try {
            clazz.getConstructor(android.app.Activity::class.java).newInstance(activity)
        } catch (_: Exception) {
            // Try Context constructor
            try {
                clazz.getConstructor(android.content.Context::class.java).newInstance(context)
            } catch (_: Exception) {
                // Try no-arg constructor
                try {
                    clazz.getConstructor().newInstance()
                } catch (_: Exception) {
                    null
                }
            }
        }
    }
}
