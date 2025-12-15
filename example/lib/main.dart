import 'dart:io';
import 'package:flutter/material.dart';
import 'native_bridge.g.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _deviceInfo = 'Loading...';
  String _batteryInfo = 'Loading...';
  String _greeting = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Common method - works on both platforms
      final model = await DeviceService.getDeviceModel();

      // Platform-specific methods
      String deviceInfo;
      if (Platform.isAndroid) {
        final version = await DeviceService.getAndroidVersion();
        final manufacturer = await DeviceService.getManufacturer();
        final greeting = await MainActivity.greet('Flutter');
        deviceInfo = '$manufacturer $model (Android $version)';
        setState(() {
          _greeting = greeting ?? '';
        });
      } else if (Platform.isIOS) {
        final version = await DeviceService.getIOSVersion();
        final deviceName = await DeviceService.getDeviceName();
        deviceInfo = '$model - $deviceName (iOS $version)';
        setState(() {
          _greeting = 'Hello from iOS!';
        });
      } else {
        deviceInfo = model ?? 'Unknown';
      }

      // Common battery methods - work on both platforms
      final battery = await BatteryService.getBatteryLevel();
      final charging = await BatteryService.isCharging();

      // iOS-specific: getBatteryState
      String batteryState = '';
      if (Platform.isIOS) {
        batteryState = await BatteryService.getBatteryState() ?? '';
      }

      setState(() {
        _deviceInfo = deviceInfo;
        _batteryInfo = Platform.isIOS
            ? '$battery% ($batteryState)'
            : '$battery% ${charging == true ? '(Charging)' : ''}';
      });
    } catch (e) {
      setState(() {
        _deviceInfo = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Native Bridge'),
          backgroundColor: Platform.isIOS ? Colors.blue : Colors.green,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Platform: ${Platform.isIOS ? "iOS" : "Android"}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Device Info:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_deviceInfo),
              const SizedBox(height: 16),
              const Text(
                'Battery:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_batteryInfo),
              const SizedBox(height: 16),
              const Text(
                'Greeting:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_greeting),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
