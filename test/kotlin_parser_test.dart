import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_native_bridge/src/generator/generator.dart';

void main() {
  group('KotlinParser', () {
    late KotlinParser parser;
    late Directory tempDir;

    setUp(() {
      parser = KotlinParser();
      tempDir = Directory.systemTemp.createTempSync('kotlin_parser_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('parses @NativeBridge annotated class', () async {
      final file = File('${tempDir.path}/DeviceService.kt');
      file.writeAsStringSync('''
package com.example.app

@NativeBridge
class DeviceService {
    fun getModel(): String = Build.MODEL
    fun getVersion(): Int = Build.VERSION.SDK_INT
}
''');

      final classes = await parser.parseFile(file);

      expect(classes.length, 1);
      expect(classes[0].name, 'DeviceService');
      expect(classes[0].platform, 'android');
      expect(classes[0].methods.length, 2);
      expect(classes[0].methods[0].name, 'getModel');
      expect(classes[0].methods[0].returnType, 'String');
      expect(classes[0].methods[1].name, 'getVersion');
      expect(classes[0].methods[1].returnType, 'Int');
    });

    test('parses @NativeFunction annotated methods', () async {
      final file = File('${tempDir.path}/MainActivity.kt');
      file.writeAsStringSync('''
package com.example.app

class MainActivity : FlutterActivity() {
    @NativeFunction
    fun greet(name: String): String = "Hello, \$name!"

    @NativeFunction
    fun add(a: Int, b: Int): Int = a + b

    fun privateMethod(): String = "Not exposed"
}
''');

      final classes = await parser.parseFile(file);

      expect(classes.length, 1);
      expect(classes[0].name, 'MainActivity');
      expect(classes[0].methods.length, 2);
      expect(classes[0].methods[0].name, 'greet');
      expect(classes[0].methods[0].params.length, 1);
      expect(classes[0].methods[0].params[0].name, 'name');
      expect(classes[0].methods[0].params[0].type, 'String');
      expect(classes[0].methods[1].name, 'add');
      expect(classes[0].methods[1].params.length, 2);
    });

    test('excludes @NativeIgnore methods from @NativeBridge class', () async {
      final file = File('${tempDir.path}/Service.kt');
      file.writeAsStringSync('''
@NativeBridge
class Service {
    fun publicMethod(): String = "exposed"

    @NativeIgnore
    fun ignoredMethod(): String = "not exposed"

    fun anotherPublic(): Int = 42
}
''');

      final classes = await parser.parseFile(file);

      expect(classes.length, 1);
      expect(classes[0].methods.length, 2);
      expect(classes[0].methods.any((m) => m.name == 'publicMethod'), true);
      expect(classes[0].methods.any((m) => m.name == 'anotherPublic'), true);
      expect(classes[0].methods.any((m) => m.name == 'ignoredMethod'), false);
    });

    test('parses methods with no parameters', () async {
      final file = File('${tempDir.path}/Test.kt');
      file.writeAsStringSync('''
@NativeBridge
class Test {
    fun noParams(): String = "hello"
}
''');

      final classes = await parser.parseFile(file);

      expect(classes[0].methods[0].params, isEmpty);
    });

    test('parses methods with multiple parameters', () async {
      final file = File('${tempDir.path}/Calculator.kt');
      file.writeAsStringSync('''
@NativeBridge
class Calculator {
    fun calculate(a: Int, b: Int, operation: String): Int = 0
}
''');

      final classes = await parser.parseFile(file);

      expect(classes[0].methods[0].params.length, 3);
      expect(classes[0].methods[0].params[0].name, 'a');
      expect(classes[0].methods[0].params[0].type, 'Int');
      expect(classes[0].methods[0].params[1].name, 'b');
      expect(classes[0].methods[0].params[2].name, 'operation');
      expect(classes[0].methods[0].params[2].type, 'String');
    });

    test('parses methods with Unit return type', () async {
      final file = File('${tempDir.path}/Actions.kt');
      file.writeAsStringSync('''
@NativeBridge
class Actions {
    fun doSomething() {
        println("done")
    }
}
''');

      final classes = await parser.parseFile(file);

      expect(classes[0].methods[0].returnType, 'Unit');
    });

    test('parses directory recursively', () async {
      final subDir = Directory('${tempDir.path}/subpackage');
      subDir.createSync();

      File('${tempDir.path}/Service1.kt').writeAsStringSync('''
@NativeBridge
class Service1 {
    fun method1(): String = ""
}
''');

      File('${subDir.path}/Service2.kt').writeAsStringSync('''
@NativeBridge
class Service2 {
    fun method2(): Int = 0
}
''');

      final classes = await parser.parseDirectory(tempDir);

      expect(classes.length, 2);
      expect(classes.any((c) => c.name == 'Service1'), true);
      expect(classes.any((c) => c.name == 'Service2'), true);
    });

    test('ignores files without annotations', () async {
      final file = File('${tempDir.path}/Plain.kt');
      file.writeAsStringSync('''
class PlainClass {
    fun regularMethod(): String = "not exposed"
}
''');

      final classes = await parser.parseFile(file);

      expect(classes, isEmpty);
    });

    test('handles class with inheritance', () async {
      final file = File('${tempDir.path}/Extended.kt');
      file.writeAsStringSync('''
@NativeBridge
class Extended : BaseClass(), SomeInterface {
    fun extendedMethod(): String = ""
}
''');

      final classes = await parser.parseFile(file);

      expect(classes.length, 1);
      expect(classes[0].name, 'Extended');
    });
  });
}
