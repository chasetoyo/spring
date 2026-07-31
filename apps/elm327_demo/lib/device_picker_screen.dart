import 'dart:async';

import 'package:elm327_obd_bluetooth/elm327_obd_bluetooth.dart';
import 'package:flutter/material.dart';

/// Scans for nearby ELM327 adapters and connects to the one the user taps,
/// handing the connected [Elm327BleClient] to [onConnected]. BLE
/// serial-bridge adapters like this typically don't need OS-level pairing
/// first — a scan result is enough to connect.
class DevicePickerScreen extends StatefulWidget {
  const DevicePickerScreen({
    required this.backend,
    required this.onConnected,
    super.key,
  });

  final BleBackend backend;
  final void Function(Elm327BleClient client) onConnected;

  @override
  State<DevicePickerScreen> createState() => _DevicePickerScreenState();
}

class _DevicePickerScreenState extends State<DevicePickerScreen> {
  final Map<String, BleDevice> _devices = {};
  StreamSubscription<BleDevice>? _scanSubscription;
  String? _connectingId;
  String? _error;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    widget.backend.stopScan();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _scanning = true;
      _error = null;
      _devices.clear();
    });
    _scanSubscription?.cancel();
    // Filtered by the ELM327 profile, so the list is adapters rather than
    // every BLE device in range.
    _scanSubscription = widget.backend
        .scan(profile: elm327Profile)
        .listen(
          (device) => setState(() => _devices[device.id] = device),
          onDone: () => setState(() => _scanning = false),
          onError: (error) => setState(() {
            _error = 'Scan error: $error';
            _scanning = false;
          }),
        );
  }

  Future<void> _connect(BleDevice device) async {
    setState(() {
      _connectingId = device.id;
      _error = null;
    });
    final client = Elm327BleClient(
      backend: widget.backend,
      deviceId: device.id,
    );
    try {
      await client.connect();
      widget.onConnected(client);
    } catch (error) {
      await client.dispose();
      setState(() {
        _error = 'Could not connect to ${device.id}: $error';
        _connectingId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = _devices.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose an ELM327 adapter'),
        actions: [
          IconButton(
            icon: _scanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _scanning ? null : _startScan,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final isConnecting = _connectingId == device.id;
                return ListTile(
                  title: Text(device.name.isNotEmpty ? device.name : device.id),
                  subtitle: Text('${device.id}  •  RSSI ${device.rssi}'),
                  trailing: isConnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: isConnecting ? null : () => _connect(device),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
