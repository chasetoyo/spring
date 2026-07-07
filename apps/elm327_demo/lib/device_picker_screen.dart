import 'dart:async';

import 'package:elm327_obd/elm327_obd.dart';
import 'package:elm327_obd_bluetooth/elm327_obd_bluetooth.dart';
import 'package:flutter/material.dart';

/// Scans for nearby BLE devices and connects to the one the user taps,
/// then hands the connected [Elm327Client] and its underlying
/// [BleElm327Transport] to [onConnected]. BLE serial-bridge adapters like
/// this typically don't need OS-level pairing first — a scan result is
/// enough to connect.
class DevicePickerScreen extends StatefulWidget {
  const DevicePickerScreen({required this.onConnected, super.key});

  final void Function(Elm327Client client, BleElm327Transport transport)
  onConnected;

  @override
  State<DevicePickerScreen> createState() => _DevicePickerScreenState();
}

class _DevicePickerScreenState extends State<DevicePickerScreen> {
  final Map<String, ScanResult> _results = {};
  StreamSubscription<ScanResult>? _scanSubscription;
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
    BleElm327Transport.stopScan();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _scanning = true;
      _error = null;
      _results.clear();
    });
    _scanSubscription?.cancel();
    _scanSubscription = BleElm327Transport.scan().listen(
      (result) => setState(() => _results[result.device.remoteId.str] = result),
      onDone: () => setState(() => _scanning = false),
      onError: (error) => setState(() {
        _error = 'Scan error: $error';
        _scanning = false;
      }),
    );
  }

  Future<void> _connect(ScanResult result) async {
    final id = result.device.remoteId.str;
    setState(() {
      _connectingId = id;
      _error = null;
    });
    try {
      final transport = await BleElm327Transport.connect(result.device);
      final client = Elm327Client(transport);
      await client.connect();
      widget.onConnected(client, transport);
    } catch (error) {
      setState(() {
        _error = 'Could not connect to $id: $error';
        _connectingId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = _results.values.toList()
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
                final result = devices[index];
                final id = result.device.remoteId.str;
                final isConnecting = _connectingId == id;
                final name = result.device.platformName.isNotEmpty
                    ? result.device.platformName
                    : result.advertisementData.advName;
                return ListTile(
                  title: Text(name.isNotEmpty ? name : id),
                  subtitle: Text('$id  •  RSSI ${result.rssi}'),
                  trailing: isConnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: isConnecting ? null : () => _connect(result),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
