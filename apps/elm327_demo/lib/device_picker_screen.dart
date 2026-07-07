import 'package:elm327_obd/elm327_obd.dart';
import 'package:elm327_obd_bluetooth/elm327_obd_bluetooth.dart';
import 'package:flutter/material.dart';

/// Lists paired Bluetooth devices and connects to the one the user
/// taps, then hands the connected [Elm327Client] and its underlying
/// [BluetoothElm327Transport] to [onConnected].
class DevicePickerScreen extends StatefulWidget {
  const DevicePickerScreen({required this.onConnected, super.key});

  final void Function(Elm327Client client, BluetoothElm327Transport transport)
  onConnected;

  @override
  State<DevicePickerScreen> createState() => _DevicePickerScreenState();
}

class _DevicePickerScreenState extends State<DevicePickerScreen> {
  List<BluetoothDevice> _devices = [];
  String? _connectingAddress;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await BluetoothElm327Transport.getBondedDevices();
      setState(() => _devices = devices);
    } catch (error) {
      setState(() => _error = 'Could not list paired devices: $error');
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() {
      _connectingAddress = device.address;
      _error = null;
    });
    try {
      final transport = await BluetoothElm327Transport.connect(
        device.address,
      );
      final client = Elm327Client(transport);
      await client.connect();
      widget.onConnected(client, transport);
    } catch (error) {
      setState(() {
        _error = 'Could not connect to ${device.name}: $error';
        _connectingAddress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose an ELM327 adapter')),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDevices,
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  final isConnecting = _connectingAddress == device.address;
                  return ListTile(
                    title: Text(device.name ?? device.address),
                    subtitle: Text(device.address),
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
          ),
        ],
      ),
    );
  }
}
