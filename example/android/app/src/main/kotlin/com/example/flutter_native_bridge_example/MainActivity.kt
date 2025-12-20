package com.example.flutter_native_bridge_example

import android.content.Context
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.nativebridge.FlutterNativeBridge
import io.nativebridge.NativeBridge
import io.nativebridge.NativeFunction
import io.nativebridge.NativeIgnore
import io.nativebridge.NativeStream
import io.nativebridge.StreamSink

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // One line registers everything!
        FlutterNativeBridge.register(this)
    }

    // Expose individual methods with @NativeFunction
    @NativeFunction
    fun greet(name: String): String = "Hello, $name from Android!"

    @NativeFunction
    fun getData(data: Map<String, Any>): Map<String, Any> = data
}

/**
 * Example service class using @NativeBridge.
 * All public methods are automatically exposed.
 */
@NativeBridge
class DeviceService {

    fun getDeviceModel(): String = Build.MODEL

    fun getAndroidVersion(): Int = Build.VERSION.SDK_INT

    fun getManufacturer(): String = Build.MANUFACTURER

    // This method is excluded from Flutter access
    @NativeIgnore
    fun internalMethod(): String = "Not accessible from Flutter"
}

/**
 * Example service that needs Context.
 * Will be auto-instantiated with Context parameter.
 */
@NativeBridge
class BatteryService(private val context: Context) {

    fun getBatteryLevel(): Int {
        val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        return bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    }

    fun isCharging(): Boolean {
        val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        return bm.isCharging
    }
}

/**
 * Example service demonstrating @NativeStream for EventChannel support.
 * Emits counter values every second.
 */
@NativeBridge
class CounterService {
    private val handler = Handler(Looper.getMainLooper())
    private var counter = 0
    private var runnable: Runnable? = null

    /**
     * Stream that emits incrementing counter values every second.
     * Use @NativeStream to mark methods that emit continuous events.
     */
    @NativeStream
    fun counterUpdates(sink: StreamSink) {
        counter = 0
        runnable = object : Runnable {
            override fun run() {
                sink.success(mapOf(
                    "count" to counter,
                    "timestamp" to System.currentTimeMillis()
                ))
                counter++
                handler.postDelayed(this, 1000)
            }
        }
        handler.post(runnable!!)
    }

    /**
     * Stop the counter stream.
     */
    fun stopCounter() {
        runnable?.let { handler.removeCallbacks(it) }
        runnable = null
        counter = 0
    }
}
