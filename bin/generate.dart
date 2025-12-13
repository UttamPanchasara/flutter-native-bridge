import 'dart:io';
import 'package:flutter_native_bridge/src/generator/generator.dart';

/// Flutter Native Bridge Code Generator
///
/// Scans Kotlin source files for @NativeBridge and @NativeFunction annotations
/// and generates typed Dart code.
///
/// Usage:
///   dart run flutter_native_bridge:generate
void main(List<String> args) async {
  print('Flutter Native Bridge - Code Generator');
  print('=' * 40);

  // Find project root
  final projectRoot = _findProjectRoot();
  if (projectRoot == null) {
    print('Error: Could not find pubspec.yaml');
    exit(1);
  }

  final kotlinDir = Directory('$projectRoot/android/app/src/main/kotlin');
  final outputFile = File('$projectRoot/lib/native_bridge.g.dart');

  if (!kotlinDir.existsSync()) {
    print('Error: Kotlin directory not found at:');
    print('  ${kotlinDir.path}');
    print('');
    print('Make sure you are in a Flutter project with Android support.');
    exit(1);
  }

  print('Scanning: ${kotlinDir.path}');
  print('');

  // Parse Kotlin files
  final parser = KotlinParser();
  final classes = await parser.parseDirectory(kotlinDir);

  if (classes.isEmpty) {
    print('No @NativeBridge classes or @NativeFunction methods found.');
    print('');
    print('Add annotations to your Kotlin code:');
    print('');
    print('  @NativeBridge');
    print('  class DeviceService {');
    print('      fun getModel(): String = Build.MODEL');
    print('  }');
    exit(0);
  }

  print('Found ${classes.length} native class(es):');
  for (final cls in classes) {
    print('  - ${cls.name} (${cls.methods.length} methods)');
    for (final method in cls.methods) {
      final params = method.params.map((p) => '${p.name}: ${p.type}').join(', ');
      print('      ${method.name}($params): ${method.returnType}');
    }
  }

  // Generate Dart code
  final generator = DartGenerator();
  final dartCode = generator.generate(classes);

  // Write output
  await outputFile.writeAsString(dartCode);

  print('');
  print('Generated: ${outputFile.path}');
  print('');
  print('Usage in your Dart code:');
  print('');
  print("  import 'native_bridge.g.dart';");
  print('');
  for (final cls in classes) {
    if (cls.methods.isNotEmpty) {
      final method = cls.methods.first;
      final params = method.params.map((p) => "'example'").join(', ');
      print('  final result = await ${cls.name}.${method.name}($params);');
    }
  }
}

String? _findProjectRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
  return dir.path;
}
