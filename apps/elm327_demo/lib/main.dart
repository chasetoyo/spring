import 'package:elm327_obd/elm327_obd.dart';
import 'package:elm327_obd_bluetooth/elm327_obd_bluetooth.dart';
import 'package:flutter/material.dart';

import 'connected_home_screen.dart';
import 'device_picker_screen.dart';

void main() {
  runApp(const Elm327DemoApp());
}

class Elm327DemoApp extends StatelessWidget {
  const Elm327DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ELM327 Demo',
      home: _RootScreen(),
    );
  }
}

class _RootScreen extends StatefulWidget {
  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  Elm327Client? _client;
  BluetoothElm327Transport? _transport;

  @override
  void dispose() {
    _client?.dispose();
    _transport?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    if (client == null) {
      return DevicePickerScreen(
        onConnected: (client, transport) {
          setState(() {
            _client = client;
            _transport = transport;
          });
        },
      );
    }
    return ConnectedHomeScreen(client: client);
  }
}
