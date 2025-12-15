import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_native_bridge/src/generator/generator.dart';

void main() {
  group('SwiftParser', () {
    late SwiftParser parser;
    late Directory tempDir;

    setUp(() {
      parser = SwiftParser();
      tempDir = Directory.systemTemp.createTempSync('swift_parser_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('parses class inheriting from NSObject with @objc methods', () async {
      final file = File('${tempDir.path}/DeviceService.swift');
      file.writeAsStringSync('''
import Foundation
import UIKit

class DeviceService: NSObject {
    @objc func getModel() -> String {
        return UIDevice.current.model
    }

    @objc func getVersion() -> String {
        return UIDevice.current.systemVersion
    }
}
''');

      final classes = await parser.parseFile(file);

      expect(classes.length, 1);
      expect(classes[0].name, 'DeviceService');
      expect(classes[0].platform, 'ios');
      expect(classes[0].methods.length, 2);
      expect(classes[0].methods[0].name, 'getModel');
      expect(classes[0].methods[0].returnType, 'String');
      expect(classes[0].methods[1].name, 'getVersion');
    });

    test('parses @objc class with methods', () async {
      final file = File('${tempDir.path}/ObjcService.swift');
      file.writeAsStringSync('''
@objc class ObjcService: NSObject {
    @objc func doSomething() -> Bool {
        return true
    }
}
''');

      final classes = await parser.parseFile(file);

      expect(classes.length, 1);
      expect(classes[0].name, 'ObjcService');
      expect(classes[0].methods[0].returnType, 'Bool');
    });

    test('ignores methods without @objc', () async {
      final file = File('${tempDir.path}/MixedService.swift');
      file.writeAsStringSync('''
class MixedService: NSObject {
    @objc func exposedMethod() -> String {
        return "visible"
    }

    func privateMethod() -> String {
        return "not visible"
    }

    @objc func anotherExposed() -> Int {
        return 42
    }
}
''');

      final classes = await parser.parseFile(file);

      expect(classes.length, 1);
      expect(classes[0].methods.length, 2);
      expect(classes[0].methods.any((m) => m.name == 'exposedMethod'), true);
      expect(classes[0].methods.any((m) => m.name == 'anotherExposed'), true);
      expect(classes[0].methods.any((m) => m.name == 'privateMethod'), false);
    });

    test('parses methods with parameters', () async {
      final file = File('${tempDir.path}/Calculator.swift');
      file.writeAsStringSync('''
class Calculator: NSObject {
    @objc func add(a: Int, b: Int) -> Int {
        return a + b
    }

    @objc func greet(name: String) -> String {
        return "Hello, \\(name)!"
    }
}
''');

      final classes = await parser.parseFile(file);

      expect(classes[0].methods[0].name, 'add');
      expect(classes[0].methods[0].params.length, 2);
      expect(classes[0].methods[0].params[0].name, 'a');
      expect(classes[0].methods[0].params[0].type, 'Int');
      expect(classes[0].methods[0].params[1].name, 'b');
      expect(classes[0].methods[1].params.length, 1);
      expect(classes[0].methods[1].params[0].name, 'name');
    });

    test('parses methods with underscore parameter labels', () async {
      final file = File('${tempDir.path}/Service.swift');
      file.writeAsStringSync('''
class Service: NSObject {
    @objc func process(_ value: String) -> String {
        return value
    }
}
''');

      final classes = await parser.parseFile(file);

      expect(classes[0].methods[0].params.length, 1);
      expect(classes[0].methods[0].params[0].name, 'value');
    });

    test('parses methods with Void return type', () async {
      final file = File('${tempDir.path}/Actions.swift');
      file.writeAsStringSync('''
class Actions: NSObject {
    @objc func doSomething() {
        print("done")
    }
}
''');

      final classes = await parser.parseFile(file);

      expect(classes[0].methods[0].returnType, 'Void');
    });

    test('ignores AppDelegate and Plugin classes', () async {
      final file = File('${tempDir.path}/AppDelegate.swift');
      file.writeAsStringSync('''
@objc class AppDelegate: FlutterAppDelegate {
    @objc func someMethod() -> String {
        return ""
    }
}

class MyPlugin: NSObject {
    @objc func pluginMethod() -> String {
        return ""
    }
}
''');

      final classes = await parser.parseFile(file);

      expect(classes, isEmpty);
    });

    test('ignores classes not inheriting from NSObject', () async {
      final file = File('${tempDir.path}/PureSwift.swift');
      file.writeAsStringSync('''
class PureSwiftClass {
    func pureMethod() -> String {
        return ""
    }
}
''');

      final classes = await parser.parseFile(file);

      expect(classes, isEmpty);
    });

    test('parses directory recursively', () async {
      final subDir = Directory('${tempDir.path}/Services');
      subDir.createSync();

      File('${tempDir.path}/Service1.swift').writeAsStringSync('''
class Service1: NSObject {
    @objc func method1() -> String { return "" }
}
''');

      File('${subDir.path}/Service2.swift').writeAsStringSync('''
class Service2: NSObject {
    @objc func method2() -> Int { return 0 }
}
''');

      final classes = await parser.parseDirectory(tempDir);

      expect(classes.length, 2);
      expect(classes.any((c) => c.name == 'Service1'), true);
      expect(classes.any((c) => c.name == 'Service2'), true);
    });

    test('parses public @objc methods', () async {
      final file = File('${tempDir.path}/PublicService.swift');
      file.writeAsStringSync('''
public class PublicService: NSObject {
    @objc public func publicMethod() -> String {
        return "public"
    }
}
''');

      final classes = await parser.parseFile(file);

      expect(classes.length, 1);
      expect(classes[0].methods[0].name, 'publicMethod');
    });

    test('handles various Swift return types', () async {
      final file = File('${tempDir.path}/TypesService.swift');
      file.writeAsStringSync('''
class TypesService: NSObject {
    @objc func getString() -> String { return "" }
    @objc func getInt() -> Int { return 0 }
    @objc func getDouble() -> Double { return 0.0 }
    @objc func getBool() -> Bool { return true }
    @objc func getFloat() -> Float { return 0.0 }
}
''');

      final classes = await parser.parseFile(file);

      expect(classes[0].methods.length, 5);
      expect(classes[0].methods[0].returnType, 'String');
      expect(classes[0].methods[1].returnType, 'Int');
      expect(classes[0].methods[2].returnType, 'Double');
      expect(classes[0].methods[3].returnType, 'Bool');
      expect(classes[0].methods[4].returnType, 'Float');
    });
  });
}
