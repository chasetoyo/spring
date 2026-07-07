import 'dart:async';
import 'dart:typed_data';

import 'package:elm327_obd/elm327_obd.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

/// An [Elm327Transport] over a Bluetooth Classic SPP connection to an
/// ELM327 adapter. Contains no AT/OBD knowledge — it only moves bytes,
/// stripping stray NULL (0x00) bytes the datasheet notes the ELM327 can
/// occasionally emit.
class BluetoothElm327Transport implements Elm327Transport {
  BluetoothElm327Transport._(this._connection);

  final BluetoothConnection _connection;
  final _inputController = StreamController<List<int>>.broadcast();
  StreamSubscription<Uint8List>? _rawSubscription;

  /// Requests the runtime permissions Android needs before scanning for
  /// or connecting to a Bluetooth Classic device (scan/connect on
  /// Android 12+, location on older Android versions that tie
  /// Bluetooth discovery to location access). A no-op on platforms that
  /// don't require it.
  static Future<void> _ensurePermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  /// Lists devices already paired with this system, for a device-picker
  /// UI to choose from. ELM327 adapters are Bluetooth Classic (SPP), so
  /// they must be paired at the OS level before they show up here.
  static Future<List<BluetoothDevice>> getBondedDevices() async {
    await _ensurePermissions();
    return FlutterBluetoothSerial.instance.getBondedDevices();
  }

  /// Opens an SPP connection to the device at [address] and returns a
  /// ready-to-use transport.
  static Future<BluetoothElm327Transport> connect(String address) async {
    await _ensurePermissions();
    final connection = await BluetoothConnection.toAddress(address);
    final transport = BluetoothElm327Transport._(connection);
    transport._rawSubscription = connection.input?.listen(
      transport._onRawData,
      onDone: () => transport._inputController.close(),
    );
    return transport;
  }

  void _onRawData(List<int> chunk) {
    _inputController.add(chunk.where((byte) => byte != 0x00).toList());
  }

  @override
  Stream<List<int>> get input => _inputController.stream;

  @override
  Future<void> write(List<int> bytes) async {
    _connection.output.add(Uint8List.fromList(bytes));
    await _connection.output.allSent;
  }

  /// Closes the SPP connection and the input stream.
  Future<void> disconnect() async {
    await _rawSubscription?.cancel();
    await _connection.close();
    await _inputController.close();
  }
}
