import 'dart:io';

/// Represents a parsed native class with its methods.
class NativeClass {
  final String name;
  final List<NativeMethod> methods;

  NativeClass(this.name, this.methods);
}

/// Represents a native method with its signature.
class NativeMethod {
  final String name;
  final String returnType;
  final List<NativeParam> params;

  NativeMethod(this.name, this.returnType, this.params);
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
      r'@NativeBridge\s*(?:\([^)]*\))?\s*class\s+(\w+)',
      multiLine: true,
    );

    for (final match in bridgeClassRegex.allMatches(content)) {
      final className = match.group(1)!;
      final classBody = _extractClassBody(content, match.end);
      final methods = _parseClassMethods(classBody, excludeIgnored: true);
      if (methods.isNotEmpty) {
        classes.add(NativeClass(className, methods));
      }
    }

    // Find classes with @NativeFunction methods (not @NativeBridge)
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
      if (methods.isNotEmpty) {
        classes.add(NativeClass(className, methods));
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

  /// Parse all public methods from @NativeBridge class (excluding @NativeIgnore).
  List<NativeMethod> _parseClassMethods(String classBody, {bool excludeIgnored = false}) {
    final methods = <NativeMethod>[];

    final methodRegex = RegExp(
      r'(?:@NativeIgnore\s+)?(?:public\s+)?fun\s+(\w+)\s*\(([^)]*)\)\s*(?::\s*([^\s{=]+))?',
      multiLine: true,
    );

    for (final match in methodRegex.allMatches(classBody)) {
      final fullMatch = match.group(0)!;

      // Skip if @NativeIgnore
      if (excludeIgnored && fullMatch.contains('@NativeIgnore')) continue;

      // Skip private/internal methods
      if (fullMatch.contains('private ') || fullMatch.contains('internal ')) continue;

      final methodName = match.group(1)!;
      final paramsStr = match.group(2) ?? '';
      final returnType = match.group(3) ?? 'Unit';

      methods.add(NativeMethod(methodName, returnType, _parseParams(paramsStr)));
    }

    return methods;
  }

  /// Parse only methods with @NativeFunction annotation.
  List<NativeMethod> _parseNativeFunctions(String classBody) {
    final methods = <NativeMethod>[];

    final methodRegex = RegExp(
      r'@NativeFunction\s*(?:\([^)]*\))?\s*(?:public\s+)?fun\s+(\w+)\s*\(([^)]*)\)\s*(?::\s*([^\s{=]+))?',
      multiLine: true,
    );

    for (final match in methodRegex.allMatches(classBody)) {
      final methodName = match.group(1)!;
      final paramsStr = match.group(2) ?? '';
      final returnType = match.group(3) ?? 'Unit';

      methods.add(NativeMethod(methodName, returnType, _parseParams(paramsStr)));
    }

    return methods;
  }

  List<NativeParam> _parseParams(String paramsStr) {
    if (paramsStr.trim().isEmpty) return [];

    final params = <NativeParam>[];
    final paramRegex = RegExp(r'(\w+)\s*:\s*([^,]+)');

    for (final match in paramRegex.allMatches(paramsStr)) {
      params.add(NativeParam(match.group(1)!, match.group(2)!.trim()));
    }

    return params;
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
    buffer.writeln('');

    for (final cls in classes) {
      _generateClass(buffer, cls);
      buffer.writeln('');
    }

    return buffer.toString();
  }

  void _generateClass(StringBuffer buffer, NativeClass cls) {
    buffer.writeln('/// Generated bridge for ${cls.name}');
    buffer.writeln('class ${cls.name} {');
    buffer.writeln('  ${cls.name}._();');

    for (final method in cls.methods) {
      buffer.writeln('');
      _generateMethod(buffer, cls.name, method);
    }

    buffer.writeln('}');
  }

  void _generateMethod(StringBuffer buffer, String className, NativeMethod method) {
    final dartReturnType = _kotlinToDartType(method.returnType);
    final params = method.params;
    final paramList = params.map((p) => '${_kotlinToDartType(p.type)} ${p.name}').join(', ');

    buffer.writeln('  /// Calls native $className.${method.name}');
    buffer.writeln('  static Future<$dartReturnType?> ${method.name}($paramList) async {');

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

  String _kotlinToDartType(String kotlinType) {
    final type = kotlinType.replaceAll('?', '').trim();

    return switch (type) {
      'String' => 'String',
      'Int' => 'int',
      'Long' => 'int',
      'Double' => 'double',
      'Float' => 'double',
      'Boolean' => 'bool',
      'Unit' => 'void',
      'List<String>' => 'List<String>',
      'List<Int>' => 'List<int>',
      'Map<String, Any>' => 'Map<String, dynamic>',
      _ when type.startsWith('List<') => 'List<dynamic>',
      _ when type.startsWith('Map<') => 'Map<dynamic, dynamic>',
      _ => 'dynamic',
    };
  }
}
