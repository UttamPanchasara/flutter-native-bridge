# Flutter Native Bridge

Zero-boilerplate bridge between Flutter and native platforms. Call native Kotlin/Swift methods from Dart with minimal setup.

Supports both **MethodChannel** (request-response) and **EventChannel** (streams) communication patterns.

## Features

- **MethodChannel Support** - Call native methods and get responses (`Future<T>`)
- **EventChannel Support** - Subscribe to native streams for real-time data (`Stream<T>`)
- **Cross-Platform** - Supports both Android (Kotlin) and iOS (Swift)
- **Minimal Setup** - Just add annotations and one line of registration
- **Auto-Discovery** - Automatically finds and registers annotated classes (Android)
- **Type-Safe** - Generated Dart code with full type support
- **IDE Autocomplete** - Works seamlessly with your IDE
- **No Native Dependencies** - No KSP or annotation processors needed

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_native_bridge: ^1.1.0
```

## Quick Start

### 1. Write Native Code

**Android (Kotlin)**

```kotlin
// Android: MainActivity.kt
import io.nativebridge.*

@NativeBridge
class DeviceService {
    // Method (MethodChannel)
    fun getDeviceModel(): String = Build.MODEL
    fun getBatteryLevel(): Int = // ...

    @NativeIgnore  // Exclude from Flutter
    fun internalMethod() { }
}

@NativeBridge
class CounterService {
    private val handler = Handler(Looper.getMainLooper())
    private var counter = 0
    private var runnable: Runnable? = null

    // Stream (EventChannel)
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

    fun stopCounter() {
        runnable?.let { handler.removeCallbacks(it) }
        runnable = null
        counter = 0
    }
}
```

**iOS (Swift)**

```swift
// iOS: DeviceService.swift & CounterService.swift
import Foundation
import UIKit

class DeviceService: NSObject {
    // Method (MethodChannel)
    @objc func getDeviceModel() -> String {
        return UIDevice.current.model
    }

    @objc func getBatteryLevel() -> Int {
        return Int(UIDevice.current.batteryLevel * 100)
    }
}

class CounterService: NSObject {
    private var timer: Timer?
    private var counter = 0
    private var activeSink: StreamSink?

    // Stream (EventChannel)
    @objc func counterUpdatesWithSink(_ sink: StreamSink) {
        activeSink = sink
        counter = 0

        DispatchQueue.main.async { [weak self] in
            self?.timer = Timer.scheduledTimer(
                withTimeInterval: 1.0,
                repeats: true
            ) { [weak self] _ in
                guard let self = self else { return }
                self.activeSink?.success([
                    "count": self.counter,
                    "timestamp": Date().timeIntervalSince1970 * 1000
                ])
                self.counter += 1
            }
        }
    }

    @objc func stopCounter() {
        timer?.invalidate()
        timer = nil
        activeSink = nil
    }
}
```

### 2. Register Native Classes

**Android (Kotlin)**

```kotlin
// Android: MainActivity.kt
import io.nativebridge.FlutterNativeBridge

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Auto-discovers all @NativeBridge classes
        FlutterNativeBridge.register(this)
    }
}
```

**iOS (Swift)**

```swift
// iOS: AppDelegate.swift
import flutter_native_bridge

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Register each service
        FlutterNativeBridge.register(DeviceService())
        FlutterNativeBridge.register(CounterService())

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

### 3. Generate Dart Code

```bash
dart run flutter_native_bridge:generate
```

This creates `lib/native_bridge.g.dart` with type-safe Dart classes.

### 4. Use in Dart

**Dart (Flutter)**

```dart
// Dart: lib/main.dart
// Type-safe calls with full IDE autocomplete support!
import 'native_bridge.g.dart';

// MethodChannel - Request/Response (Future<T>)
final model = await DeviceService.getDeviceModel();
final battery = await DeviceService.getBatteryLevel();

// EventChannel - Streams (Stream<T>)
StreamSubscription? subscription;

void startListening() {
  subscription = CounterService.counterUpdates().listen((data) {
    if (data is Map) {
      print('Count: ${data['count']}');
    }
  });
}

void stopListening() {
  subscription?.cancel();
  CounterService.stopCounter();
}
```

## Platform Reference

### Annotations & Requirements

| Feature | Android (Kotlin) | iOS (Swift) |
|---------|------------------|-------------|
| **Class Setup** | `@NativeBridge` on class | Inherit from `NSObject` |
| **Expose Method** | Automatic (public methods) | Add `@objc` to method |
| **Expose Single Method** | `@NativeFunction` | Add `@objc` to method |
| **Exclude Method** | `@NativeIgnore` | Don't add `@objc` |
| **Stream Method** | `@NativeStream` + `StreamSink` param | `@objc` + `StreamSink` param |
| **Registration** | `FlutterNativeBridge.register(this)` | `FlutterNativeBridge.register(obj)` |

### Android Annotations

| Annotation | Target | Description |
|------------|--------|-------------|
| `@NativeBridge` | Class | Exposes all public methods to Flutter |
| `@NativeFunction` | Method | Exposes a single method (use without `@NativeBridge`) |
| `@NativeIgnore` | Method | Excludes a method from Flutter access |
| `@NativeStream` | Method | Marks method as EventChannel stream |

### iOS Requirements

- Classes must inherit from `NSObject`
- Methods must be marked with `@objc`
- Stream methods must have `StreamSink` parameter with selector ending in `WithSink:`
- Return types must be Objective-C compatible

## Supported Types

| Kotlin | Swift | Dart |
|--------|-------|------|
| `String` | `String` | `String` |
| `Int` | `Int` | `int` |
| `Long` | `Int64` | `int` |
| `Double` | `Double` | `double` |
| `Float` | `Float` | `double` |
| `Boolean` | `Bool` | `bool` |
| `Unit` | `Void` | `void` |
| `List<T>` | `[T]` | `List<T>` |
| `Map<K, V>` | `[K: V]` | `Map<K, V>` |

## Auto-Discovery (Android Only)

When you call `FlutterNativeBridge.register(this)`, the plugin automatically:

1. Registers the activity if it has `@NativeFunction` methods
2. Scans your package for classes with `@NativeBridge` or `@NativeFunction`
3. Creates instances using available constructors:
   - `Activity` parameter
   - `Context` parameter
   - No-arg constructor

## Runtime API

Call native methods without code generation:

```dart
import 'package:flutter_native_bridge/flutter_native_bridge.dart';

// Methods (MethodChannel)
final model = await FlutterNativeBridge.call<String>('DeviceService', 'getDeviceModel');

// Streams (EventChannel)
FlutterNativeBridge.stream<Map>('CounterService', 'counterUpdates').listen((data) {
  print('Count: ${data['count']}');
});

// Discovery
final classes = await FlutterNativeBridge.discover();
final streams = await FlutterNativeBridge.discoverStreams();
```

## Complete Example

See the [example](example/) directory for a full working implementation.

**Android (Kotlin)**

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
import io.nativebridge.*

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterNativeBridge.register(this)  // Auto-discovers all @NativeBridge classes
    }
}

@NativeBridge
class DeviceService {
    fun getDeviceModel(): String = Build.MODEL
    fun getBatteryLevel(): Int = // ...
}

@NativeBridge
class CounterService {
    @NativeStream
    fun counterUpdates(sink: StreamSink) {
        // Emit events: sink.success(mapOf("count" to counter))
    }
    fun stopCounter() { /* cleanup */ }
}
```

**iOS (Swift)**

```swift
// ios/Runner/AppDelegate.swift
import flutter_native_bridge

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(...) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        FlutterNativeBridge.register(DeviceService())
        FlutterNativeBridge.register(CounterService())
        return super.application(...)
    }
}

// ios/Runner/Services.swift
class DeviceService: NSObject {
    @objc func getDeviceModel() -> String { UIDevice.current.model }
    @objc func getBatteryLevel() -> Int { /* ... */ }
}

class CounterService: NSObject {
    @objc func counterUpdatesWithSink(_ sink: StreamSink) {
        // Emit events: sink.success(["count": counter])
    }
    @objc func stopCounter() { /* cleanup */ }
}
```

**Dart (Flutter)**

```dart
// lib/main.dart
import 'native_bridge.g.dart';

// MethodChannel - Request/Response (Future<T>)
final model = await DeviceService.getDeviceModel();
final battery = await DeviceService.getBatteryLevel();

// EventChannel - Streams (Stream<T>)
final subscription = CounterService.counterUpdates().listen((data) {
  print('Count: ${data['count']}');
});

// Stop stream
subscription.cancel();
CounterService.stopCounter();
```

## Troubleshooting

### Method not found?

**Android:**
- Ensure method is `public` (not `private` or `internal`)
- For non-`@NativeBridge` classes, add `@NativeFunction` annotation
- Check method is not annotated with `@NativeIgnore`

**iOS:**
- Ensure class inherits from `NSObject`
- Ensure method is marked with `@objc`
- Check return type is Objective-C compatible

### Stream not working?

**Android:**
- Add `@NativeStream` annotation to the method
- Method must have `StreamSink` as parameter

**iOS:**
- Method selector must end with `WithSink:` (e.g., `counterUpdatesWithSink:`)
- Parameter must be of type `StreamSink`

### Auto-discovery not working? (Android)

Use manual registration:
```kotlin
FlutterNativeBridge.registerObjects(DeviceService(), CounterService())
```

### Name conflicts?

Register with custom names:
```kotlin
// Android
FlutterNativeBridge.register("MyDevice", DeviceService())
```
```swift
// iOS
FlutterNativeBridge.register(name: "MyDevice", object: DeviceService())
```

## License

MIT License - see [LICENSE](LICENSE) for details.
