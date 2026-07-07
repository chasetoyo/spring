import 'dart:async';

import 'package:elm327_obd/elm327_obd.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// An [Elm327Transport] over a Bluetooth Low Energy (BLE) connection to an
/// ELM327 adapter. Contains no AT/OBD knowledge — it only moves bytes,
/// stripping stray NULL (0x00) bytes the datasheet notes the ELM327 can
/// occasionally emit.
///
/// Many budget BLE-serial OBD-II adapters (including some Veepeak
/// OBDCheck BLE/BLE+ units) expose a generic "HM-10 style" UART-over-BLE
/// GATT profile: service `FFF0`, a writable characteristic `FFF1`, and a
/// notifying characteristic `FFF2`. [defaultServiceUuid]/
/// [defaultWriteCharacteristicUuid]/[defaultNotifyCharacteristicUuid]
/// default to that pattern, but **this is commonly-referenced, not
/// verified against a specific Veepeak firmware revision** — if `connect`
/// fails to find these UUIDs on your adapter, inspect its actual GATT
/// profile (e.g. with a generic BLE scanner app) and pass the real ones.
class BleElm327Transport implements Elm327Transport {
  BleElm327Transport._(this._device, this._writeCharacteristic);

  static const defaultServiceUuid = 'fff0';
  static const defaultWriteCharacteristicUuid = 'fff1';
  static const defaultNotifyCharacteristicUuid = 'fff2';

  final BluetoothDevice _device;
  final BluetoothCharacteristic _writeCharacteristic;
  final _inputController = StreamController<List<int>>.broadcast();
  StreamSubscription<List<int>>? _notifySubscription;

  /// Requests the runtime permissions Android needs before scanning for
  /// or connecting to a BLE device (scan/connect on Android 12+, location
  /// on older Android versions that tie BLE discovery to location
  /// access). A no-op on platforms that don't require it.
  static Future<void> _ensurePermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  /// Starts a BLE scan and streams devices as they're discovered, for a
  /// device-picker UI to show live and let the user tap one to connect.
  /// BLE serial-bridge adapters like this typically don't need OS-level
  /// pairing first — unlike Bluetooth Classic, a scan result is enough.
  static Stream<ScanResult> scan({
    Duration timeout = const Duration(seconds: 10),
  }) async* {
    await _ensurePermissions();
    await FlutterBluePlus.startScan(timeout: timeout);
    yield* FlutterBluePlus.onScanResults
        .expand((results) => results)
        .distinct((a, b) => a.device.remoteId == b.device.remoteId);
  }

  /// Stops an in-progress scan started by [scan].
  static Future<void> stopScan() => FlutterBluePlus.stopScan();

  /// Connects to [device] and locates its write/notify characteristics,
  /// defaulting to the common FFF0/FFF1/FFF2 pattern (see the class doc
  /// comment) — override the UUID parameters for adapters that differ.
  static Future<BleElm327Transport> connect(
    BluetoothDevice device, {
    String serviceUuid = defaultServiceUuid,
    String writeCharacteristicUuid = defaultWriteCharacteristicUuid,
    String notifyCharacteristicUuid = defaultNotifyCharacteristicUuid,
  }) async {
    await _ensurePermissions();
    // flutter_blue_plus is dual-licensed; `nonprofit` covers personal use
    // per its LICENSE. Revisit if this app is ever used commercially.
    await device.connect(license: License.nonprofit);
    final services = await device.discoverServices();
    final service = services.firstWhere(
      (s) => s.uuid == Guid(serviceUuid),
      orElse: () => throw Elm327TransportException(
        'BLE service $serviceUuid not found on ${device.remoteId.str}',
      ),
    );
    final writeCharacteristic = service.characteristics.firstWhere(
      (c) => c.uuid == Guid(writeCharacteristicUuid),
      orElse: () => throw Elm327TransportException(
        'BLE write characteristic $writeCharacteristicUuid not found in '
        'service $serviceUuid on ${device.remoteId.str}',
      ),
    );
    final notifyCharacteristic = service.characteristics.firstWhere(
      (c) => c.uuid == Guid(notifyCharacteristicUuid),
      orElse: () => throw Elm327TransportException(
        'BLE notify characteristic $notifyCharacteristicUuid not found in '
        'service $serviceUuid on ${device.remoteId.str}',
      ),
    );

    final transport = BleElm327Transport._(device, writeCharacteristic);
    transport._notifySubscription = notifyCharacteristic.onValueReceived
        .listen(transport._onRawData);
    await notifyCharacteristic.setNotifyValue(true);
    return transport;
  }

  void _onRawData(List<int> chunk) {
    _inputController.add(chunk.where((byte) => byte != 0x00).toList());
  }

  @override
  Stream<List<int>> get input => _inputController.stream;

  @override
  Future<void> write(List<int> bytes) async {
    final sendWithoutResponse =
        _writeCharacteristic.properties.writeWithoutResponse &&
        !_writeCharacteristic.properties.write;
    await _writeCharacteristic.write(
      bytes,
      withoutResponse: sendWithoutResponse,
    );
  }

  /// Disconnects from the device and closes the input stream.
  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    await _device.disconnect();
    await _inputController.close();
  }
}
