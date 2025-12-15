# Flutter Native Bridge

Zero-boilerplate bridge between Flutter and native platforms. Call native Kotlin/Swift methods from Dart with minimal setup.

## Features

- **Cross-Platform** - Supports both Android (Kotlin) and iOS (Swift)
- **Minimal Setup** - Just add annotations and one line of registration
- **Auto-Discovery** - Automatically finds and registers annotated classes
- **Type-Safe** - Generated Dart code with full type support
- **IDE Autocomplete** - Works seamlessly with your IDE
- **No Native Dependencies** - No KSP or annotation processors needed
- **Flexible** - Use code generation or runtime calls

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_native_bridge: ^1.0.0
```

## Quick Start

### Android (Kotlin)

#### 1. Annotate Your Kotlin Code

```kotlin
// Option A: Expose all methods with @NativeBridge
@NativeBridge
class DeviceService {
    fun getModel(): String = Build.MODEL
    fun getVersion(): Int = Build.VERSION.SDK_INT

    @NativeIgnore  // Exclude specific methods
    fun internalMethod() { }
}

// Option B: Expose specific methods with @NativeFunction
class MainActivity : FlutterActivity() {
    @NativeFunction
    fun greet(name: String): String = "Hello, $name!"
}
```

#### 2. Register in MainActivity

```kotlin
import io.nativebridge.FlutterNativeBridge

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterNativeBridge.register(this)  // One line does it all!
    }
}
```

### iOS (Swift)

#### 1. Create Your Swift Classes

```swift
import Foundation

// Inherit from NSObject and use @objc to expose methods
class DeviceService: NSObject {
    @objc func getModel() -> String {
        return UIDevice.current.model
    }

    @objc func getVersion() -> String {
        return UIDevice.current.systemVersion
    }
}
```

#### 2. Register in AppDelegate

```swift
import flutter_native_bridge

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Register your native classes
        FlutterNativeBridge.register(DeviceService())

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

### Generate Dart Code

```bash
dart run flutter_native_bridge:generate
```

This scans both Android and iOS source files and creates `lib/native_bridge.g.dart`.

### Use in Dart

```dart
import 'native_bridge.g.dart';

// Type-safe calls with autocomplete - works on both platforms!
final model = await DeviceService.getModel();
final version = await DeviceService.getVersion();
```

## Platform Comparison

| Feature | Android | iOS |
|---------|---------|-----|
| Class annotation | `@NativeBridge` | Inherit `NSObject` |
| Method annotation | `@NativeFunction` | `@objc` |
| Exclude method | `@NativeIgnore` | Don't add `@objc` |
| Registration | `FlutterNativeBridge.register(this)` | `FlutterNativeBridge.register(obj)` |

## Android Annotations

| Annotation | Target | Description |
|------------|--------|-------------|
| `@NativeBridge` | Class | Exposes all public methods to Flutter |
| `@NativeFunction` | Method | Exposes a single method to Flutter |
| `@NativeIgnore` | Method | Excludes a method (use with `@NativeBridge`) |

## iOS Requirements

- Classes must inherit from `NSObject`
- Methods must be marked with `@objc`
- Return types must be Objective-C compatible

## Auto-Discovery (Android)

When you call `FlutterNativeBridge.register(this)` on Android, the plugin automatically:

1. Registers the activity if it has `@NativeFunction` methods
2. Scans your package for classes with `@NativeBridge` or `@NativeFunction`
3. Creates instances using available constructors:
   - `Activity` parameter
   - `Context` parameter
   - No-arg constructor

## Runtime API (Without Code Generation)

You can also call methods at runtime without generating code:

```dart
import 'package:flutter_native_bridge/flutter_native_bridge.dart';

// Direct call
final model = await FlutterNativeBridge.call<String>('DeviceService', 'getModel');

// Using bridge instance
final device = NativeBridge('DeviceService');
final model = await device.call<String>('getModel');

// Discover registered classes
final classes = await FlutterNativeBridge.discover();
// {'DeviceService': ['getModel', 'getVersion']}
```

## Supported Types

| Kotlin Type | Swift Type | Dart Type |
|-------------|------------|-----------|
| `String` | `String` | `String` |
| `Int` | `Int` | `int` |
| `Long` | `Int64` | `int` |
| `Double` | `Double` | `double` |
| `Float` | `Float` | `double` |
| `Boolean` | `Bool` | `bool` |
| `List<T>` | `[T]` | `List<T>` |
| `Map<K, V>` | `[K: V]` | `Map<K, V>` |

## Complete Example

### Android (Kotlin)

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
package com.example.myapp

import io.nativebridge.FlutterNativeBridge
import io.nativebridge.NativeBridge
import io.nativebridge.NativeFunction

@NativeBridge
class DeviceService {
    fun getDeviceModel(): String = Build.MODEL
    fun getAndroidVersion(): Int = Build.VERSION.SDK_INT
}

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterNativeBridge.register(this)
    }

    @NativeFunction
    fun greet(name: String): String = "Hello, $name from Android!"
}
```

### iOS (Swift)

```swift
// ios/Runner/DeviceService.swift
import Foundation
import UIKit

class DeviceService: NSObject {
    @objc func getDeviceModel() -> String {
        return UIDevice.current.model
    }

    @objc func getIOSVersion() -> String {
        return UIDevice.current.systemVersion
    }
}

// ios/Runner/AppDelegate.swift
import flutter_native_bridge

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        FlutterNativeBridge.register(DeviceService())
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

### Dart

```dart
// lib/main.dart
import 'native_bridge.g.dart';

void main() async {
  final model = await DeviceService.getDeviceModel();
  print('Device: $model');
}
```

## Troubleshooting

### Android: Auto-discovery not working?

Use manual registration:
```kotlin
FlutterNativeBridge.registerObjects(DeviceService(), OtherService())
```

### Android: Method not found?

Ensure the method is:
- Public (not `private` or `internal`)
- Annotated with `@NativeFunction` (if class doesn't have `@NativeBridge`)
- Not annotated with `@NativeIgnore`

### iOS: Method not found?

Ensure:
- Class inherits from `NSObject`
- Method is marked with `@objc`
- Return type is Objective-C compatible

### Name conflicts?

If you have classes with the same name on both platforms or from different packages:
```kotlin
// Android
FlutterNativeBridge.register("AndroidDevice", DeviceService())

// iOS
FlutterNativeBridge.register(name: "iOSDevice", object: DeviceService())
```

## License

MIT License - see [LICENSE](LICENSE) for details.
