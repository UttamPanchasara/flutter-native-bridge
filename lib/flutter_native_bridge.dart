/// Flutter Native Bridge
///
/// Zero-boilerplate bridge between Flutter and native Android/iOS.
/// Call native Kotlin/Swift methods from Dart with minimal setup.
/// Supports both request-response (MethodChannel) and streams (EventChannel).
///
/// ## Quick Start
///
/// 1. Add annotations in Kotlin:
/// ```kotlin
/// @NativeBridge
/// class DeviceService {
///     fun getModel(): String = Build.MODEL
///
///     @NativeStream
///     fun sensorUpdates(sink: StreamSink) {
///         sink.success(mapOf("x" to 1.0, "y" to 2.0))
///     }
/// }
/// ```
///
/// 2. Register in MainActivity:
/// ```kotlin
/// FlutterNativeBridge.register(this)
/// ```
///
/// 3. Generate Dart code:
/// ```bash
/// dart run flutter_native_bridge:generate
/// ```
///
/// 4. Use in Dart:
/// ```dart
/// final model = await DeviceService.getModel();
/// DeviceService.sensorUpdates().listen((data) => print(data));
/// ```
library;

import 'package:flutter/services.dart';

const _channel = MethodChannel('flutter_native_bridge');
const _eventChannelPrefix = 'flutter_native_bridge/events/';

/// Runtime bridge for calling native methods without code generation.
///
/// Use this for dynamic calls or when you don't want to use the generator.
///
/// Example:
/// ```dart
/// final bridge = NativeBridge('DeviceService');
/// final model = await bridge.call<String>('getModel');
///
/// // For streams:
/// bridge.stream<Map>('sensorUpdates').listen((data) {
///   print('Sensor: $data');
/// });
/// ```
class NativeBridge {
  final String className;

  const NativeBridge(this.className);

  /// Call a method on this native class.
  Future<T?> call<T>(String methodName, [dynamic arguments]) async {
    return _channel.invokeMethod<T>('$className.$methodName', arguments);
  }

  /// Subscribe to a stream from this native class.
  ///
  /// The stream will emit events from the native @NativeStream method.
  Stream<T> stream<T>(String streamName, [dynamic arguments]) {
    final channelName = '$_eventChannelPrefix$className.$streamName';
    final eventChannel = EventChannel(channelName);
    return eventChannel.receiveBroadcastStream(arguments).cast<T>();
  }

  /// Static method to call any class.method combination.
  static Future<T?> invoke<T>(
    String className,
    String methodName, [
    dynamic arguments,
  ]) async {
    return _channel.invokeMethod<T>('$className.$methodName', arguments);
  }

  /// Static method to subscribe to any class.stream combination.
  static Stream<T> invokeStream<T>(
    String className,
    String streamName, [
    dynamic arguments,
  ]) {
    final channelName = '$_eventChannelPrefix$className.$streamName';
    final eventChannel = EventChannel(channelName);
    return eventChannel.receiveBroadcastStream(arguments).cast<T>();
  }
}

/// Utility class for runtime discovery and direct method calls.
///
/// Provides methods to discover registered native classes at runtime.
class FlutterNativeBridge {
  FlutterNativeBridge._();

  /// Call a method on any registered native class.
  ///
  /// Example:
  /// ```dart
  /// final model = await FlutterNativeBridge.call<String>('DeviceService', 'getModel');
  /// ```
  static Future<T?> call<T>(
    String className,
    String methodName, [
    dynamic arguments,
  ]) {
    return NativeBridge.invoke<T>(className, methodName, arguments);
  }

  /// Subscribe to a stream from any registered native class.
  ///
  /// Example:
  /// ```dart
  /// FlutterNativeBridge.stream<Map>('SensorService', 'accelerometerUpdates')
  ///   .listen((data) => print('Sensor: $data'));
  /// ```
  static Stream<T> stream<T>(
    String className,
    String streamName, [
    dynamic arguments,
  ]) {
    return NativeBridge.invokeStream<T>(className, streamName, arguments);
  }

  /// Get all registered native class names.
  ///
  /// Useful for debugging or dynamic UI.
  static Future<List<String>> getRegisteredClasses() async {
    final result = await _channel.invokeMethod<List>('_getRegisteredClasses');
    return result?.cast<String>() ?? [];
  }

  /// Get all exposed method names for a class.
  static Future<List<String>> getMethods(String className) async {
    final result = await _channel.invokeMethod<List>('_getMethods', className);
    return result?.cast<String>() ?? [];
  }

  /// Get all stream names for a class.
  static Future<List<String>> getStreams(String className) async {
    final result = await _channel.invokeMethod<List>('_getStreams', className);
    return result?.cast<String>() ?? [];
  }

  /// Discover all registered classes and their methods.
  ///
  /// Returns a map of class names to their method lists.
  ///
  /// Example:
  /// ```dart
  /// final discovery = await FlutterNativeBridge.discover();
  /// // {'DeviceService': ['getModel', 'getBattery'], 'MainActivity': ['greet']}
  /// ```
  static Future<Map<String, List<String>>> discover() async {
    final result = await _channel.invokeMethod<Map>('_discover');
    if (result == null) return {};

    return result.map((key, value) => MapEntry(
      key as String,
      (value as List).cast<String>(),
    ));
  }

  /// Discover all registered classes and their stream methods.
  ///
  /// Returns a map of class names to their stream method lists.
  ///
  /// Example:
  /// ```dart
  /// final streams = await FlutterNativeBridge.discoverStreams();
  /// // {'SensorService': ['accelerometerUpdates', 'gyroscopeUpdates']}
  /// ```
  static Future<Map<String, List<String>>> discoverStreams() async {
    final result = await _channel.invokeMethod<Map>('_discoverStreams');
    if (result == null) return {};

    return result.map((key, value) => MapEntry(
      key as String,
      (value as List).cast<String>(),
    ));
  }
}
