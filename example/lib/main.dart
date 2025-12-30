import 'dart:async';
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

  // Stream support
  StreamSubscription? _counterSubscription;
  int _counter = 0;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _startStream() {
    if (_isStreaming) return;

    setState(() {
      _isStreaming = true;
      _counter = 0;
    });

    _counterSubscription = CounterService.counterUpdates().listen(
      (data) {
        if (data is Map) {
          setState(() {
            _counter = data['count'] as int? ?? 0;
          });
        }
      },
      onError: (error) {
        debugPrint('Stream error: $error');
        _stopStream();
      },
    );
  }

  void _stopStream() {
    _counterSubscription?.cancel();
    _counterSubscription = null;
    CounterService.stopCounter();
    setState(() {
      _isStreaming = false;
    });
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
        final greeting = await DeviceService.greetWithName('Flutter');
        deviceInfo = '$model - $deviceName (iOS $version)';
        setState(() {
          _greeting = greeting ?? '';
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
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Stream Demo (EventChannel):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Counter: $_counter',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 16),
                  if (_isStreaming)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _isStreaming ? null : _startStream,
                    child: const Text('Start Stream'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isStreaming ? _stopStream : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Stop Stream'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Refresh Device Info'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
