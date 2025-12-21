# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-12-21

### Added
- **EventChannel/Stream Support**
  - `@NativeStream` annotation for streaming methods (Android)
  - `StreamSink` interface for emitting events to Flutter
  - iOS stream support via `WithSink:` selector pattern
  - `FlutterNativeBridge.stream<T>()` runtime API for dynamic stream subscriptions
  - `FlutterNativeBridge.discoverStreams()` for stream introspection
  - Generated Stream methods in Dart code (`Stream<dynamic>`)
- **Code Generator**
  - Generates Stream methods for `@NativeStream` annotations
  - Handles generic types (Map, List) correctly

## [1.0.0] - 2024-12-15

### Added
- Initial release of Flutter Native Bridge
- **Android Support**
  - `@NativeBridge` annotation for exposing entire classes
  - `@NativeFunction` annotation for exposing individual methods
  - `@NativeIgnore` annotation for excluding methods
  - Auto-discovery of annotated classes
  - Support for Activity, Context, and no-arg constructors
- **iOS Support**
  - Support for classes inheriting from `NSObject`
  - `@objc` method exposure
  - Manual registration via `FlutterNativeBridge.register()`
- **Code Generator**
  - Parses Kotlin files for Android annotations
  - Parses Swift files for `@objc` methods
  - Generates type-safe Dart code with IDE autocomplete
  - Merges classes from both platforms
- **Runtime API**
  - `FlutterNativeBridge.call<T>()` for dynamic method calls
  - `NativeBridge` class for instance-based calls
  - `FlutterNativeBridge.discover()` for introspection
- **Type Support**
  - Kotlin: String, Int, Long, Double, Float, Boolean, Unit, List, Map
  - Swift: String, Int, Double, Float, Bool, Void, Array, Dictionary
