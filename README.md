# Flutter Native Bridge

Zero-boilerplate bridge between Flutter and native Android. Call native Kotlin methods from Dart with minimal setup.

## Features

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

### 1. Annotate Your Kotlin Code

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

### 2. Register in MainActivity

```kotlin
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterNativeBridge.register(this)  // One line does it all!
    }
}
```

### 3. Generate Dart Code

```bash
dart run flutter_native_bridge:generate
```

This creates `lib/native_bridge.g.dart` with typed Dart classes.

### 4. Use in Dart

```dart
import 'native_bridge.g.dart';

// Type-safe calls with autocomplete!
final model = await DeviceService.getModel();
final version = await DeviceService.getVersion();
final greeting = await MainActivity.greet('Flutter');
```

## Annotations

| Annotation | Target | Description |
|------------|--------|-------------|
| `@NativeBridge` | Class | Exposes all public methods to Flutter |
| `@NativeFunction` | Method | Exposes a single method to Flutter |
| `@NativeIgnore` | Method | Excludes a method (use with `@NativeBridge`) |

## Auto-Discovery

When you call `FlutterNativeBridge.register(this)`, the plugin automatically:

1. Registers the activity if it has `@NativeFunction` methods
2. Scans your package for classes with `@NativeBridge` or `@NativeFunction`
3. Creates instances using available constructors:
   - `Activity` parameter
   - `Context` parameter
   - No-arg constructor

## Constructor Support

Classes can have different constructors:

```kotlin
// No-arg constructor
@NativeBridge
class SimpleService {
    fun getData(): String = "data"
}

// Context constructor (auto-injected)
@NativeBridge
class StorageService(private val context: Context) {
    fun getFilesDir(): String = context.filesDir.path
}

// Activity constructor (auto-injected)
@NativeBridge
class UIService(private val activity: Activity) {
    fun getScreenWidth(): Int = activity.resources.displayMetrics.widthPixels
}
```

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
// {'DeviceService': ['getModel', 'getVersion'], 'MainActivity': ['greet']}
```

## Manual Registration

If auto-discovery doesn't work for your use case:

```kotlin
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    // Manual registration
    FlutterNativeBridge.registerObjects(
        DeviceService(),
        StorageService(applicationContext),
        CustomService(this)
    )
}
```

## Supported Types

| Kotlin Type | Dart Type |
|-------------|-----------|
| `String` | `String` |
| `Int` | `int` |
| `Long` | `int` |
| `Double` | `double` |
| `Float` | `double` |
| `Boolean` | `bool` |
| `List<T>` | `List<T>` |
| `Map<K, V>` | `Map<K, V>` |

## Example

See the [example](example/) directory for a complete working example.

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
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

```dart
// lib/main.dart
import 'native_bridge.g.dart';

void main() async {
  final model = await DeviceService.getDeviceModel();
  final version = await DeviceService.getAndroidVersion();
  final greeting = await MainActivity.greet('Flutter');

  print('$model (Android $version)');
  print(greeting);
}
```

## Troubleshooting

### Auto-discovery not working?

Use manual registration:
```kotlin
FlutterNativeBridge.registerObjects(DeviceService(), OtherService())
```

### Method not found?

Ensure the method is:
- Public (not `private` or `internal`)
- Annotated with `@NativeFunction` (if class doesn't have `@NativeBridge`)
- Not annotated with `@NativeIgnore`

### Type mismatch?

Check that return types match between Kotlin and the generated Dart code. Run the generator again after modifying Kotlin signatures.

## License

MIT License - see [LICENSE](LICENSE) for details.
