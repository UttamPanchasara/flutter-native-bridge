// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_native_bridge/src/generator/generator.dart';

/// Flutter Native Bridge Code Generator
///
/// Scans Kotlin and Swift source files for annotated methods
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

  final outputFile = File('$projectRoot/lib/native_bridge.g.dart');
  final allClasses = <NativeClass>[];

  // Parse Android (Kotlin)
  final kotlinDir = Directory('$projectRoot/android/app/src/main/kotlin');
  if (kotlinDir.existsSync()) {
    print('Scanning Android: ${kotlinDir.path}');
    final kotlinParser = KotlinParser();
    final kotlinClasses = await kotlinParser.parseDirectory(kotlinDir);
    allClasses.addAll(kotlinClasses);
    print('  Found ${kotlinClasses.length} class(es)');
  } else {
    print('Android: No Kotlin source directory found');
  }

  // Parse iOS (Swift)
  final iosDir = Directory('$projectRoot/ios/Runner');
  if (iosDir.existsSync()) {
    print('Scanning iOS: ${iosDir.path}');
    final swiftParser = SwiftParser();
    final swiftClasses = await swiftParser.parseDirectory(iosDir);
    allClasses.addAll(swiftClasses);
    print('  Found ${swiftClasses.length} class(es)');
  } else {
    print('iOS: No Swift source directory found');
  }

  print('');

  if (allClasses.isEmpty) {
    print('No native classes found.');
    print('');
    print('Android - Add annotations to your Kotlin code:');
    print('');
    print('  @NativeBridge');
    print('  class DeviceService {');
    print('      fun getModel(): String = Build.MODEL');
    print('  }');
    print('');
    print('iOS - Add @objc to your Swift methods:');
    print('');
    print('  class DeviceService: NSObject {');
    print('      @objc func getModel() -> String {');
    print('          return UIDevice.current.model');
    print('      }');
    print('  }');
    exit(0);
  }

  print('Found ${allClasses.length} native class(es):');
  for (final cls in allClasses) {
    print('  - ${cls.name} [${cls.platform}] (${cls.methods.length} methods)');
    for (final method in cls.methods) {
      final params = method.params.map((p) => '${p.name}: ${p.type}').join(', ');
      print('      ${method.name}($params): ${method.returnType}');
    }
  }

  // Generate Dart code
  final generator = DartGenerator();
  final dartCode = generator.generate(allClasses);

  // Write output
  await outputFile.writeAsString(dartCode);

  print('');
  print('Generated: ${outputFile.path}');
  print('');
  print('Usage in your Dart code:');
  print('');
  print("  import 'native_bridge.g.dart';");
  print('');
  for (final cls in allClasses) {
    if (cls.methods.isNotEmpty) {
      final method = cls.methods.first;
      final params = method.params.map((p) => "'example'").join(', ');
      print('  final result = await ${cls.name}.${method.name}($params);');
      break;
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
