import 'dart:io';

/// Represents a parsed native class with its callables (methods and streams).
class NativeClass {
  final String name;
  final List<NativeCallable> callables;
  final String platform; // 'android', 'ios', or 'shared'

  NativeClass(this.name, this.callables, {this.platform = 'shared'});

  /// Get only method callables.
  List<NativeMethod> get methods =>
      callables.whereType<NativeMethod>().toList();

  /// Get only stream callables.
  List<NativeStream> get streams =>
      callables.whereType<NativeStream>().toList();
}

/// Base class for native callable signatures.
abstract class NativeCallable {
  String get name;
  String get returnType;
  List<NativeParam> get params;
}

/// Represents a native method that returns `Future<T>`.
class NativeMethod implements NativeCallable {
  @override
  final String name;
  @override
  final String returnType;
  @override
  final List<NativeParam> params;

  NativeMethod(this.name, this.returnType, this.params);
}

/// Represents a native stream that returns `Stream<T>`.
class NativeStream implements NativeCallable {
  @override
  final String name;
  @override
  final String returnType;
  @override
  final List<NativeParam> params;

  NativeStream(this.name, this.returnType, this.params);
}

/// Represents a method parameter.
class NativeParam {
  final String name;
  final String type;

  NativeParam(this.name, this.type);
}

/// Parses Kotlin source files for @NativeBridge and @NativeFunction annotations.
class KotlinParser {
  /// Parse all Kotlin files in a directory recursively.
  Future<List<NativeClass>> parseDirectory(Directory dir) async {
    final classes = <NativeClass>[];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.kt')) {
        final parsed = await parseFile(entity);
        classes.addAll(parsed);
      }
    }

    return classes;
  }

  /// Parse a single Kotlin file for annotated classes.
  Future<List<NativeClass>> parseFile(File file) async {
    final content = await file.readAsString();
    final classes = <NativeClass>[];

    // Find @NativeBridge annotated classes
    final bridgeClassRegex = RegExp(
      r'@NativeBridge\s*(?:\([^)]*\))?\s*class\s+(\w+)(?:\s*[:(][^{]*)?\s*\{',
      multiLine: true,
    );

    for (final match in bridgeClassRegex.allMatches(content)) {
      final className = match.group(1)!;
      final classBody = _extractClassBody(content, match.end);
      final methods = _parseClassMethods(classBody, excludeIgnored: true);
      final streams = _parseStreamMethods(classBody);
      final callables = <NativeCallable>[...methods, ...streams];
      if (callables.isNotEmpty) {
        classes.add(NativeClass(className, callables, platform: 'android'));
      }
    }

    // Find classes with @NativeFunction or @NativeStream methods (not @NativeBridge)
    final classRegex = RegExp(
      r'class\s+(\w+)(?:\s*[:(][^{]*)?\s*\{',
      multiLine: true,
    );

    for (final match in classRegex.allMatches(content)) {
      final className = match.group(1)!;

      // Skip if already parsed as @NativeBridge
      if (classes.any((c) => c.name == className)) continue;

      // Check if this class has @NativeBridge annotation before it
      final beforeClass = content.substring(0, match.start);
      if (beforeClass.trimRight().endsWith('@NativeBridge')) continue;

      final classBody = _extractClassBody(content, match.end);
      final methods = _parseNativeFunctions(classBody);
      final streams = _parseStreamMethods(classBody);
      final callables = <NativeCallable>[...methods, ...streams];
      if (callables.isNotEmpty) {
        classes.add(NativeClass(className, callables, platform: 'android'));
      }
    }

    return classes;
  }

  String _extractClassBody(String content, int startIndex) {
    int braceCount = 1;
    int i = startIndex;
    final start = i;

    while (i < content.length && braceCount > 0) {
      if (content[i] == '{') braceCount++;
      if (content[i] == '}') braceCount--;
      i++;
    }

    return content.substring(start, i - 1);
  }

  /// Parse all public methods from @NativeBridge class (excluding @NativeIgnore and @NativeStream).
  List<NativeMethod> _parseClassMethods(String classBody, {bool excludeIgnored = false}) {
    final methods = <NativeMethod>[];

    // Capture return type more broadly - everything after : until { or = or newline
    final methodRegex = RegExp(
      r'(?:@NativeIgnore\s+|@NativeStream\s+)?(?:override\s+)?(?:public\s+)?fun\s+(\w+)\s*\(([^)]*)\)\s*(?::\s*([^{=\n]+))?',
      multiLine: true,
    );

    for (final match in methodRegex.allMatches(classBody)) {
      final fullMatch = match.group(0)!;

      // Skip if @NativeIgnore
      if (excludeIgnored && fullMatch.contains('@NativeIgnore')) continue;

      // Skip if @NativeStream (handled separately)
      if (fullMatch.contains('@NativeStream')) continue;

      // Skip private/internal/override methods
      if (fullMatch.contains('private ') || fullMatch.contains('internal ') || fullMatch.contains('override ')) continue;

      final methodName = match.group(1)!;
      final paramsStr = match.group(2) ?? '';
      final returnType = (match.group(3) ?? 'Unit').trim();

      // Skip methods with StreamSink parameter (they are streams)
      if (paramsStr.contains('StreamSink')) continue;

      methods.add(NativeMethod(methodName, returnType, _parseParams(paramsStr)));
    }

    return methods;
  }

  /// Parse only methods with @NativeFunction annotation.
  List<NativeMethod> _parseNativeFunctions(String classBody) {
    final methods = <NativeMethod>[];

    final methodRegex = RegExp(
      r'@NativeFunction\s*(?:\([^)]*\))?\s*(?:public\s+)?fun\s+(\w+)\s*\(([^)]*)\)\s*(?::\s*([^{=\n]+))?',
      multiLine: true,
    );

    for (final match in methodRegex.allMatches(classBody)) {
      final methodName = match.group(1)!;
      final paramsStr = match.group(2) ?? '';
      final returnType = (match.group(3) ?? 'Unit').trim();

      methods.add(NativeMethod(methodName, returnType, _parseParams(paramsStr)));
    }

    return methods;
  }

  /// Parse methods with @NativeStream annotation.
  List<NativeStream> _parseStreamMethods(String classBody) {
    final streams = <NativeStream>[];

    final methodRegex = RegExp(
      r'@NativeStream\s*(?:\([^)]*\))?\s*(?:public\s+)?fun\s+(\w+)\s*\(([^)]*)\)\s*(?::\s*([^{=\n]+))?',
      multiLine: true,
    );

    for (final match in methodRegex.allMatches(classBody)) {
      final methodName = match.group(1)!;
      final paramsStr = match.group(2) ?? '';

      // Parse params but exclude StreamSink from the generated signature
      final params = _parseParams(paramsStr)
          .where((p) => p.type != 'StreamSink')
          .toList();

      // Stream methods emit dynamic data by default
      streams.add(NativeStream(methodName, 'dynamic', params));
    }

    return streams;
  }

  List<NativeParam> _parseParams(String paramsStr) {
    if (paramsStr.trim().isEmpty) return [];

    final params = <NativeParam>[];

    // Split by commas, but respect angle bracket nesting
    final paramParts = _splitByComma(paramsStr);

    for (final part in paramParts) {
      final colonIndex = part.indexOf(':');
      if (colonIndex == -1) continue;

      final name = part.substring(0, colonIndex).trim();
      final type = part.substring(colonIndex + 1).trim();

      if (name.isNotEmpty && type.isNotEmpty) {
        params.add(NativeParam(name, type));
      }
    }

    return params;
  }

  /// Split a string by commas, respecting bracket nesting.
  List<String> _splitByComma(String str) {
    final parts = <String>[];
    var depth = 0;
    var start = 0;

    for (var i = 0; i < str.length; i++) {
      final char = str[i];
      if (char == '<' || char == '(' || char == '[') {
        depth++;
      } else if (char == '>' || char == ')' || char == ']') {
        depth--;
      } else if (char == ',' && depth == 0) {
        parts.add(str.substring(start, i).trim());
        start = i + 1;
      }
    }

    // Add the last part
    if (start < str.length) {
      parts.add(str.substring(start).trim());
    }

    return parts;
  }
}

/// Parses Swift source files for @objc methods.
class SwiftParser {
  /// Parse all Swift files in a directory recursively.
  Future<List<NativeClass>> parseDirectory(Directory dir) async {
    final classes = <NativeClass>[];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.swift')) {
        final parsed = await parseFile(entity);
        classes.addAll(parsed);
      }
    }

    return classes;
  }

  /// Parse a single Swift file for classes with @objc methods.
  Future<List<NativeClass>> parseFile(File file) async {
    final content = await file.readAsString();
    final classes = <NativeClass>[];

    // Find classes that inherit from NSObject or have @objc
    final classRegex = RegExp(
      r'(?:@objc\s+)?(?:public\s+)?class\s+(\w+)\s*(?::\s*([^{]+))?\s*\{',
      multiLine: true,
    );

    for (final match in classRegex.allMatches(content)) {
      final className = match.group(1)!;
      final inheritance = match.group(2) ?? '';

      // Skip system classes and plugin classes
      if (className.contains('Plugin') || className.contains('AppDelegate')) continue;

      // Check if it inherits from NSObject or is @objc
      final isObjcCompatible = inheritance.contains('NSObject') ||
          match.group(0)!.contains('@objc');

      if (!isObjcCompatible) continue;

      final classBody = _extractClassBody(content, match.end);
      final methods = _parseObjcMethods(classBody);
      final streams = _parseStreamMethods(classBody);
      final callables = <NativeCallable>[...methods, ...streams];

      if (callables.isNotEmpty) {
        classes.add(NativeClass(className, callables, platform: 'ios'));
      }
    }

    return classes;
  }

  String _extractClassBody(String content, int startIndex) {
    int braceCount = 1;
    int i = startIndex;
    final start = i;

    while (i < content.length && braceCount > 0) {
      if (content[i] == '{') braceCount++;
      if (content[i] == '}') braceCount--;
      i++;
    }

    return content.substring(start, i - 1);
  }

  /// Parse @objc methods from a class body (excluding stream methods).
  List<NativeMethod> _parseObjcMethods(String classBody) {
    final methods = <NativeMethod>[];

    // Match @objc func declarations - capture return type broadly
    final methodRegex = RegExp(
      r'@objc\s+(?:public\s+)?func\s+(\w+)\s*\(([^)]*)\)\s*(?:->\s*([^{\n]+))?',
      multiLine: true,
    );

    for (final match in methodRegex.allMatches(classBody)) {
      final methodName = match.group(1)!;
      final paramsStr = match.group(2) ?? '';
      final returnType = (match.group(3) ?? 'Void').trim();

      // Skip stream methods (methods with StreamSink parameter)
      if (paramsStr.contains('StreamSink')) continue;

      methods.add(NativeMethod(methodName, returnType, _parseParams(paramsStr)));
    }

    return methods;
  }

  /// Parse stream methods from a class body (methods with StreamSink parameter).
  List<NativeStream> _parseStreamMethods(String classBody) {
    final streams = <NativeStream>[];

    // Match @objc func declarations with StreamSink parameter
    final methodRegex = RegExp(
      r'@objc\s+(?:public\s+)?func\s+(\w+)\s*\(([^)]*StreamSink[^)]*)\)',
      multiLine: true,
    );

    for (final match in methodRegex.allMatches(classBody)) {
      var methodName = match.group(1)!;
      final paramsStr = match.group(2) ?? '';

      // Remove "WithSink" suffix if present
      if (methodName.endsWith('WithSink')) {
        methodName = methodName.substring(0, methodName.length - 8);
      }

      // Parse params but exclude StreamSink from the generated signature
      final params = _parseParams(paramsStr)
          .where((p) => p.type != 'StreamSink')
          .toList();

      // Stream methods emit dynamic data by default
      streams.add(NativeStream(methodName, 'dynamic', params));
    }

    return streams;
  }

  List<NativeParam> _parseParams(String paramsStr) {
    if (paramsStr.trim().isEmpty) return [];

    final params = <NativeParam>[];

    // Split by commas, but respect bracket nesting
    final paramParts = _splitByComma(paramsStr);

    for (final part in paramParts) {
      // Swift params: name: Type or _ name: Type or externalName internalName: Type
      final colonIndex = part.indexOf(':');
      if (colonIndex == -1) continue;

      var namePart = part.substring(0, colonIndex).trim();
      final type = part.substring(colonIndex + 1).trim();

      // Handle external/internal names - take the last word before :
      final nameParts = namePart.split(RegExp(r'\s+'));
      final name = nameParts.last;

      // Skip underscore-only names
      if (name == '_') continue;

      if (name.isNotEmpty && type.isNotEmpty) {
        params.add(NativeParam(name, type));
      }
    }

    return params;
  }

  /// Split a string by commas, respecting bracket nesting.
  List<String> _splitByComma(String str) {
    final parts = <String>[];
    var depth = 0;
    var start = 0;

    for (var i = 0; i < str.length; i++) {
      final char = str[i];
      if (char == '<' || char == '(' || char == '[') {
        depth++;
      } else if (char == '>' || char == ')' || char == ']') {
        depth--;
      } else if (char == ',' && depth == 0) {
        parts.add(str.substring(start, i).trim());
        start = i + 1;
      }
    }

    // Add the last part
    if (start < str.length) {
      parts.add(str.substring(start).trim());
    }

    return parts;
  }
}

/// Generates Dart code from parsed native classes.
class DartGenerator {
  /// Generate Dart code for all parsed classes.
  String generate(List<NativeClass> classes) {
    final buffer = StringBuffer();

    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated by flutter_native_bridge');
    buffer.writeln('// Run: dart run flutter_native_bridge:generate');
    buffer.writeln('');
    buffer.writeln("import 'package:flutter/services.dart';");
    buffer.writeln('');
    buffer.writeln("const _channel = MethodChannel('flutter_native_bridge');");
    buffer.writeln("const _eventChannelPrefix = 'flutter_native_bridge/events/';");
    buffer.writeln('');

    // Merge classes with same name from different platforms
    final mergedClasses = _mergeClasses(classes);

    for (final cls in mergedClasses) {
      _generateClass(buffer, cls);
      buffer.writeln('');
    }

    return buffer.toString();
  }

  List<NativeClass> _mergeClasses(List<NativeClass> classes) {
    final merged = <String, NativeClass>{};

    for (final cls in classes) {
      if (merged.containsKey(cls.name)) {
        // Merge callables from both platforms
        final existing = merged[cls.name]!;
        final allNames = {
          ...existing.callables.map((c) => c.name),
          ...cls.callables.map((c) => c.name),
        };

        final combinedCallables = <NativeCallable>[];
        for (final name in allNames) {
          final callable = cls.callables.firstWhere(
            (c) => c.name == name,
            orElse: () => existing.callables.firstWhere((c) => c.name == name),
          );
          combinedCallables.add(callable);
        }

        merged[cls.name] = NativeClass(
          cls.name,
          combinedCallables,
          platform: 'shared',
        );
      } else {
        merged[cls.name] = cls;
      }
    }

    return merged.values.toList();
  }

  void _generateClass(StringBuffer buffer, NativeClass cls) {
    buffer.writeln('/// Generated bridge for ${cls.name}');
    buffer.writeln('class ${cls.name} {');
    buffer.writeln('  ${cls.name}._();');

    for (final callable in cls.callables) {
      buffer.writeln('');
      switch (callable) {
        case NativeMethod method:
          _generateMethod(buffer, cls.name, method);
        case NativeStream stream:
          _generateStreamMethod(buffer, cls.name, stream);
      }
    }

    buffer.writeln('}');
  }

  void _generateMethod(StringBuffer buffer, String className, NativeMethod method) {
    final dartReturnType = _nativeToDartType(method.returnType);
    final params = method.params;
    final paramList = params.map((p) => '${_nativeToDartType(p.type)} ${p.name}').join(', ');

    // void cannot be nullable in Dart
    final futureType = dartReturnType == 'void' ? 'void' : '$dartReturnType?';

    buffer.writeln('  /// Calls native $className.${method.name}');
    buffer.writeln('  static Future<$futureType> ${method.name}($paramList) async {');

    if (params.isEmpty) {
      buffer.writeln("    return _channel.invokeMethod<$dartReturnType>('$className.${method.name}');");
    } else if (params.length == 1) {
      buffer.writeln("    return _channel.invokeMethod<$dartReturnType>('$className.${method.name}', ${params.first.name});");
    } else {
      final mapEntries = params.map((p) => "'${p.name}': ${p.name}").join(', ');
      buffer.writeln("    return _channel.invokeMethod<$dartReturnType>('$className.${method.name}', {$mapEntries});");
    }

    buffer.writeln('  }');
  }

  void _generateStreamMethod(StringBuffer buffer, String className, NativeStream stream) {
    final dartReturnType = _nativeToDartType(stream.returnType);
    final params = stream.params;
    final paramList = params.map((p) => '${_nativeToDartType(p.type)} ${p.name}').join(', ');

    buffer.writeln('  /// Subscribes to native $className.${stream.name} stream');
    buffer.writeln('  static Stream<$dartReturnType> ${stream.name}($paramList) {');
    buffer.writeln("    const channelName = '\${_eventChannelPrefix}$className.${stream.name}';");
    buffer.writeln('    const eventChannel = EventChannel(channelName);');

    if (params.isEmpty) {
      buffer.writeln('    return eventChannel.receiveBroadcastStream().cast<$dartReturnType>();');
    } else if (params.length == 1) {
      buffer.writeln('    return eventChannel.receiveBroadcastStream(${params.first.name}).cast<$dartReturnType>();');
    } else {
      final mapEntries = params.map((p) => "'${p.name}': ${p.name}").join(', ');
      buffer.writeln('    return eventChannel.receiveBroadcastStream({$mapEntries}).cast<$dartReturnType>();');
    }

    buffer.writeln('  }');
  }

  String _nativeToDartType(String nativeType) {
    final type = nativeType.replaceAll('?', '').trim();

    return switch (type) {
      // Kotlin types
      'String' => 'String',
      'Int' => 'int',
      'Long' => 'int',
      'Double' => 'double',
      'Float' => 'double',
      'Boolean' => 'bool',
      'Unit' => 'void',
      // Swift types
      'Void' => 'void',
      'Bool' => 'bool',
      'Int32' || 'Int64' => 'int',
      'Float32' || 'Float64' => 'double',
      'NSString' => 'String',
      'NSNumber' => 'num',
      'NSArray' => 'List<dynamic>',
      'NSDictionary' => 'Map<dynamic, dynamic>',
      // Collections
      'List<String>' || '[String]' => 'List<String>',
      'List<Int>' || '[Int]' => 'List<int>',
      'Map<String, Any>' || '[String: Any]' => 'Map<String, dynamic>',
      _ when type.startsWith('List<') || type.startsWith('[') => 'List<dynamic>',
      _ when type.startsWith('Map<') || type.contains(':') => 'Map<dynamic, dynamic>',
      _ => 'dynamic',
    };
  }
}
