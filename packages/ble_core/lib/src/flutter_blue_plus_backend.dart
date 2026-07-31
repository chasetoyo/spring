import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_backend.dart';
import 'ble_connection.dart';
import 'ble_device.dart';
import 'ble_exception.dart';
import 'device_profile.dart';

/// The `flutter_blue_plus` implementation of [BleBackend].
///
/// This is the only file in the workspace permitted to import
/// `package:flutter_blue_plus` or `package:permission_handler`. Nothing it
/// returns exposes a vendor type.
class FlutterBluePlusBackend implements BleBackend {
  FlutterBluePlusBackend();

  /// flutter_blue_plus is dual-licensed; `nonprofit` covers personal use per
  /// its LICENSE. Revisit if this workspace is ever used commercially.
  static const License _license = License.nonprofit;

  /// Requested after connecting so a notification carries a useful payload.
  ///
  /// The default 23-byte ATT MTU leaves 20 bytes per notification, which
  /// fragments anything larger — an 88-byte RaceBox packet becomes five
  /// notifications the framer has to reassemble. Reassembly is required
  /// regardless, but a larger MTU makes the common case one packet per
  /// notification. Best-effort: platforms and devices may refuse.
  static const int _preferredMtu = 247;

  @override
  Future<BleAvailability> availability() async {
    if (!await FlutterBluePlus.isSupported) {
      return BleAvailability.unsupported;
    }
    final BleAvailability permission = await _permissionState(prompt: false);
    if (!permission.isReady) return permission;
    final BluetoothAdapterState adapter =
        await FlutterBluePlus.adapterState.first;
    if (adapter != BluetoothAdapterState.on) return BleAvailability.adapterOff;
    return BleAvailability.ready;
  }

  @override
  Future<BleAvailability> requestPermissions() async {
    if (!await FlutterBluePlus.isSupported) {
      return BleAvailability.unsupported;
    }
    final BleAvailability permission = await _permissionState(prompt: true);
    if (!permission.isReady) return permission;
    final BluetoothAdapterState adapter =
        await FlutterBluePlus.adapterState.first;
    if (adapter != BluetoothAdapterState.on) return BleAvailability.adapterOff;
    return BleAvailability.ready;
  }

  /// Resolves the platform's BLE permissions into a [BleAvailability].
  ///
  /// iOS surfaces Bluetooth permission through the adapter state rather than
  /// a `permission_handler` status, so only Android is inspected here.
  Future<BleAvailability> _permissionState({required bool prompt}) async {
    if (!Platform.isAndroid) return BleAvailability.ready;

    // `bluetoothScan`/`bluetoothConnect` are the Android 12+ permissions;
    // `locationWhenInUse` covers API 30, where a BLE scan is still gated on
    // location access. Orion's minSdk is 30, so both paths are live.
    const List<Permission> required = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    Map<Permission, PermissionStatus> statuses;
    if (prompt) {
      statuses = await required.request();
    } else {
      statuses = <Permission, PermissionStatus>{
        for (final Permission permission in required)
          permission: await permission.status,
      };
    }

    // Permanently denied wins over plain denied: it is the one that cannot be
    // resolved by asking again, and reporting it as `denied` would leave the
    // UI offering a prompt the system will never show.
    if (statuses.values.any((PermissionStatus s) => s.isPermanentlyDenied)) {
      return BleAvailability.deniedForever;
    }
    if (statuses.values.any((PermissionStatus s) => !s.isGranted)) {
      return BleAvailability.denied;
    }
    return BleAvailability.ready;
  }

  @override
  Stream<BleDevice> scan({
    DeviceProfile? profile,
    Duration timeout = const Duration(seconds: 10),
  }) async* {
    final BleAvailability state = await requestPermissions();
    if (!state.isReady) {
      throw BleUnavailableException('Bluetooth unavailable: ${state.name}');
    }

    await FlutterBluePlus.startScan(timeout: timeout);
    final Set<String> seen = <String>{};
    try {
      await for (final List<ScanResult> results
          in FlutterBluePlus.onScanResults) {
        for (final ScanResult result in results) {
          final BleDevice device = _toBleDevice(result);
          if (profile != null && !profile.matches(device)) continue;
          // Dedup by id rather than `.distinct()`: consecutive-only
          // comparison lets a device reappear every time another one is seen
          // between its advertisements, which is most of them.
          if (!seen.add(device.id)) continue;
          yield device;
        }
      }
    } finally {
      await stopScan();
    }
  }

  @override
  Future<void> stopScan() async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
  }

  @override
  Future<BleConnection> connect(
    String deviceId,
    DeviceProfile profile, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final BluetoothDevice device = BluetoothDevice.fromId(deviceId);

    try {
      await device.connect(license: _license, timeout: timeout);
    } on TimeoutException {
      throw BleTimeoutException(
        'Timed out connecting to $deviceId after ${timeout.inSeconds}s',
      );
    } on FlutterBluePlusException catch (error) {
      throw BleConnectionException(
        'Could not connect to $deviceId: ${error.description ?? error.code}',
      );
    }

    try {
      if (Platform.isAndroid) {
        // Android-only API, and best-effort — a refusal is not fatal.
        await device.requestMtu(_preferredMtu).catchError((_) => 0);
      }

      final List<BluetoothService> services = await device.discoverServices();
      final BluetoothService service = _require(
        services.where(
          (BluetoothService s) => _uuidEquals(s.uuid, profile.serviceUuid),
        ),
        'service ${profile.serviceUuid}',
        profile,
        deviceId,
      );
      final BluetoothCharacteristic writeCharacteristic = _require(
        service.characteristics.where(
          (BluetoothCharacteristic c) =>
              _uuidEquals(c.uuid, profile.writeCharacteristicUuid),
        ),
        'write characteristic ${profile.writeCharacteristicUuid}',
        profile,
        deviceId,
      );
      final BluetoothCharacteristic notifyCharacteristic = _require(
        service.characteristics.where(
          (BluetoothCharacteristic c) =>
              _uuidEquals(c.uuid, profile.notifyCharacteristicUuid),
        ),
        'notify characteristic ${profile.notifyCharacteristicUuid}',
        profile,
        deviceId,
      );

      final _FbpConnection connection = _FbpConnection(
        device: device,
        writeCharacteristic: writeCharacteristic,
        notifyCharacteristic: notifyCharacteristic,
      );
      await connection.start();
      return connection;
    } catch (_) {
      // A half-open link is worse than none: it holds the device against
      // another connect attempt and leaks a subscription.
      await device.disconnect().catchError((_) {});
      rethrow;
    }
  }

  @override
  Future<bool> removeBond(String deviceId) async {
    // Android-only, as flutter_blue_plus documents. iOS exposes no API for
    // clearing a bond — only the user can, from system settings — so this
    // reports false there rather than pretending to have done something.
    if (!Platform.isAndroid) return false;
    try {
      await BluetoothDevice.fromId(deviceId).removeBond();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> dispose() => stopScan();

  T _require<T>(
    Iterable<T> candidates,
    String what,
    DeviceProfile profile,
    String deviceId,
  ) {
    final Iterator<T> iterator = candidates.iterator;
    if (!iterator.moveNext()) {
      throw BleProfileException(
        '${profile.name}: $what not found on $deviceId',
      );
    }
    return iterator.current;
  }

  static BleDevice _toBleDevice(ScanResult result) {
    final String advertisedName = result.advertisementData.advName;
    return BleDevice(
      id: result.device.remoteId.str,
      name: advertisedName.isNotEmpty
          ? advertisedName
          : result.device.platformName,
      rssi: result.rssi,
      manufacturerData: <int, Uint8List>{
        for (final MapEntry<int, List<int>> entry
            in result.advertisementData.manufacturerData.entries)
          entry.key: Uint8List.fromList(entry.value),
      },
      serviceUuids: result.advertisementData.serviceUuids
          .map((Guid uuid) => uuid.str.toLowerCase())
          .toList(growable: false),
    );
  }
}

bool _uuidEquals(Guid guid, String uuid) {
  final String left = guid.str.toLowerCase().replaceAll('-', '');
  final String right = uuid.toLowerCase().replaceAll('-', '');
  return _trimBase(left) == _trimBase(right);
}

String _trimBase(String uuid) {
  if (uuid.length == 32 && uuid.endsWith('00001000800000805f9b34fb')) {
    return uuid.substring(0, 8).replaceFirst(RegExp(r'^0+'), '');
  }
  return uuid.replaceFirst(RegExp(r'^0+'), '');
}

/// A live link, wrapping one `flutter_blue_plus` device.
class _FbpConnection implements BleConnection {
  _FbpConnection({
    required BluetoothDevice device,
    required BluetoothCharacteristic writeCharacteristic,
    required BluetoothCharacteristic notifyCharacteristic,
  }) : _device = device,
       _writeCharacteristic = writeCharacteristic,
       _notifyCharacteristic = notifyCharacteristic;

  final BluetoothDevice _device;
  final BluetoothCharacteristic _writeCharacteristic;
  final BluetoothCharacteristic _notifyCharacteristic;

  final StreamController<List<int>> _input =
      StreamController<List<int>>.broadcast();
  final StreamController<BleConnectionState> _state =
      StreamController<BleConnectionState>.broadcast();

  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _stateSubscription;
  BleConnectionState _currentState = BleConnectionState.connecting;
  bool _closed = false;

  Future<void> start() async {
    _notifySubscription = _notifyCharacteristic.onValueReceived.listen(
      _input.add,
    );
    // Subscribing to the device's own state is what makes a mid-session drop
    // observable at all. Without it a dead link is indistinguishable from a
    // quiet one, and a pending command waits forever.
    _stateSubscription = _device.connectionState.listen((
      BluetoothConnectionState state,
    ) {
      _emit(switch (state) {
        BluetoothConnectionState.connected => BleConnectionState.connected,
        BluetoothConnectionState.disconnected =>
          BleConnectionState.disconnected,
      });
    });
    await _notifyCharacteristic.setNotifyValue(true);
    _emit(BleConnectionState.connected);
  }

  void _emit(BleConnectionState state) {
    if (_closed || state == _currentState) return;
    _currentState = state;
    _state.add(state);
  }

  @override
  String get deviceId => _device.remoteId.str;

  @override
  Stream<List<int>> get input => _input.stream;

  @override
  Stream<BleConnectionState> get state async* {
    yield _currentState;
    yield* _state.stream;
  }

  @override
  BleConnectionState get currentState => _currentState;

  @override
  Future<void> write(List<int> bytes) async {
    if (!_currentState.isConnected) {
      throw BleConnectionException('Link to $deviceId is not connected');
    }
    final bool withoutResponse =
        _writeCharacteristic.properties.writeWithoutResponse &&
        !_writeCharacteristic.properties.write;
    try {
      await _writeCharacteristic.write(bytes, withoutResponse: withoutResponse);
    } on FlutterBluePlusException catch (error) {
      throw BleConnectionException(
        'Write to $deviceId failed: ${error.description ?? error.code}',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    if (_closed) return;
    _closed = true;
    _currentState = BleConnectionState.disconnected;
    await _notifySubscription?.cancel();
    await _stateSubscription?.cancel();
    try {
      await _device.disconnect();
    } catch (_) {
      // Already gone is the outcome we wanted.
    }
    await _input.close();
    await _state.close();
  }
}
