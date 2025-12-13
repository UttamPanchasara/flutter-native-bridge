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
  String _data = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Use generated typed code - with autocomplete!
      final model = await DeviceService.getDeviceModel();
      final version = await DeviceService.getAndroidVersion();
      final manufacturer = await DeviceService.getManufacturer();

      final battery = await BatteryService.getBatteryLevel();
      final charging = await BatteryService.isCharging();

      final greeting = await MainActivity.greet('Flutter');

      final data = await MainActivity.getData({'key': 'Value'});

      setState(() {
        _deviceInfo = '$manufacturer $model (Android $version)';
        _batteryInfo = '$battery% ${charging == true ? '(Charging)' : ''}';
        _greeting = greeting ?? '';
        _data = data.toString();
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
        appBar: AppBar(title: const Text('Flutter Native Bridge')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Device Info:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_deviceInfo),
              const SizedBox(height: 16),
              const Text('Battery:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_batteryInfo),
              const SizedBox(height: 16),
              const Text('Greeting:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_greeting),
              const SizedBox(height: 16),
              const Text('Data:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_data),
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
