import 'package:elm327_obd_bluetooth/elm327_obd_bluetooth.dart';
import 'package:elm327_obd_vehicle_pids/vehicle_profile.dart';
import 'package:flutter/material.dart';

import 'connected_home_screen.dart';
import 'device_picker_screen.dart';
import 'vehicle_select_screen.dart';

void main() {
  runApp(const Elm327DemoApp());
}

class Elm327DemoApp extends StatelessWidget {
  const Elm327DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'ELM327 Demo', home: _RootScreen());
  }
}

class _RootScreen extends StatefulWidget {
  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  final BleBackend _backend = FlutterBluePlusBackend();
  Elm327BleClient? _client;
  VehicleProfile? _vehicleProfile;
  bool _vehicleSelected = false;

  @override
  void dispose() {
    _client?.dispose();
    _backend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = _client?.client;
    if (client == null) {
      return DevicePickerScreen(
        backend: _backend,
        onConnected: (connected) => setState(() => _client = connected),
      );
    }
    if (!_vehicleSelected) {
      return VehicleSelectScreen(
        onSelected: (profile) {
          setState(() {
            _vehicleProfile = profile;
            _vehicleSelected = true;
          });
        },
      );
    }
    return ConnectedHomeScreen(client: client, vehicleProfile: _vehicleProfile);
  }
}
