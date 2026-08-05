import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// Prefixed because permission_handler's `openAppSettings` is a bare top-level
// function that would otherwise be shadowed by this class's method of the
// same name, turning the call into unbounded recursion.
import 'package:permission_handler/permission_handler.dart' as permissions;

import 'ble_backend.dart';
import 'ble_connection.dart';
import 'ble_device.dart';
import 'ble_exception.dart';
import 'ble_uuid.dart';
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

  @override
  Future<void> openAppSettings() => permissions.openAppSettings();

  /// Resolves the platform's BLE permissions into a [BleAvailability].
  ///
  /// iOS surfaces Bluetooth permission through the adapter state rather than
  /// a `permission_handler` status, so only Android is inspected here.
  Future<BleAvailability> _permissionState({required bool prompt}) async {
    if (!Platform.isAndroid) return BleAvailability.ready;

    // `bluetoothScan`/`bluetoothConnect` are the Android 12+ permissions;
    // `locationWhenInUse` covers API 30, where a BLE scan is still gated on
    // location access. Orion's minSdk is 30, so both paths are live.
    const List<permissions.Permission> required = <permissions.Permission>[
      permissions.Permission.bluetoothScan,
      permissions.Permission.bluetoothConnect,
      permissions.Permission.locationWhenInUse,
    ];

    Map<permissions.Permission, permissions.PermissionStatus> statuses;
    if (prompt) {
      statuses = await required.request();
    } else {
      statuses = <permissions.Permission, permissions.PermissionStatus>{
        for (final permissions.Permission permission in required)
          permission: await permission.status,
      };
    }

    // Permanently denied wins over plain denied: it is the one that cannot be
    // resolved by asking again, and reporting it as `denied` would leave the
    // UI offering a prompt the system will never show.
    if (statuses.values.any(
      (permissions.PermissionStatus s) => s.isPermanentlyDenied,
    )) {
      return BleAvailability.deniedForever;
    }
    if (statuses.values.any((permissions.PermissionStatus s) => !s.isGranted)) {
      return BleAvailability.denied;
    }
    return BleAvailability.ready;
  }

  @override
  Stream<BleDevice> scan({
    DeviceProfile? profile,
    Duration timeout = const Duration(seconds: 10),
  }) {
    // Deliberately a hand-driven controller rather than an `async*` generator
    // reading `FlutterBluePlus.onScanResults`, which this used to be. That
    // stream is a process-wide re-emitting controller that is **never closed**,
    // so an `await for` over it does not end when the scan window does. Two
    // things broke as a result, and both were visible in the app:
    //
    // * the caller never learned the scan had finished, so a picker sat on
    //   "Scanning…" forever with no way to tell a live scan from a dead one;
    // * cancelling the subscription deadlocked. An `async*` body can only
    //   honour a cancellation when it next resumes, and once the window has
    //   closed no further advertisement is coming — so `cancel()` never
    //   completed, and every caller that cancels before connecting (which is
    //   every one of them, since a scan and a connect must not overlap) hung
    //   on that await and appeared to ignore the tap entirely.
    //
    // Driving the controller by hand lets the window closing end the stream
    // and lets a cancellation take effect on the spot.
    final StreamController<BleDevice> controller =
        StreamController<BleDevice>();
    final Set<String> seen = <String>{};
    StreamSubscription<List<ScanResult>>? results;
    StreamSubscription<bool>? scanning;
    // Not `controller.isClosed`: a cancellation does not close the controller,
    // and permission prompts make the setup below long enough to be cancelled
    // half way through. Without this flag that leaves a scan running with
    // nothing left to stop it.
    bool released = false;

    Future<void> release() async {
      released = true;
      await results?.cancel();
      results = null;
      await scanning?.cancel();
      scanning = null;
      await stopScan();
    }

    controller
      ..onListen = () async {
        try {
          final BleAvailability state = await requestPermissions();
          if (!state.isReady) {
            throw BleUnavailableException(
              'Bluetooth unavailable: ${state.name}',
            );
          }
          if (released || controller.isClosed) return;

          await FlutterBluePlus.startScan(timeout: timeout);
          if (released || controller.isClosed) {
            await stopScan();
            return;
          }

          results = FlutterBluePlus.onScanResults.listen((
            List<ScanResult> batch,
          ) {
            for (final ScanResult result in batch) {
              final BleDevice device = _toBleDevice(result);
              if (profile != null && !profile.matches(device)) continue;
              // Dedup by id rather than `.distinct()`: consecutive-only
              // comparison lets a device reappear every time another one is
              // seen between its advertisements, which is most of them.
              if (!seen.add(device.id)) continue;
              if (released || controller.isClosed) return;
              controller.add(device);
            }
          }, onError: controller.addError);

          // The only signal that discovery is over. `isScanning` re-emits its
          // latest value on listen, and the scan is already running by here, so
          // the first event is `true` and the `false` that ends this stream is
          // the timeout firing — or someone else calling `stopScan`, which is
          // equally the end of our scan.
          scanning = FlutterBluePlus.isScanning.listen((bool on) {
            if (!on && !released && !controller.isClosed) {
              unawaited(controller.close());
            }
          });
        } catch (error, stackTrace) {
          if (released || controller.isClosed) return;
          controller.addError(error, stackTrace);
          await controller.close();
        }
      }
      // Reached both when the subscriber cancels and after `close` has
      // delivered its done event, so the radio is released down either path.
      ..onCancel = release;

    return controller.stream;
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
        services: services,
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

bool _uuidEquals(Guid guid, String uuid) => bleUuidEquals(guid.str, uuid);

/// A live link, wrapping one `flutter_blue_plus` device.
class _FbpConnection implements BleConnection {
  _FbpConnection({
    required BluetoothDevice device,
    required List<BluetoothService> services,
    required BluetoothCharacteristic writeCharacteristic,
    required BluetoothCharacteristic notifyCharacteristic,
  }) : _device = device,
       _services = services,
       _writeCharacteristic = writeCharacteristic,
       _notifyCharacteristic = notifyCharacteristic;

  final BluetoothDevice _device;

  /// Everything discovery found, not only the profile's service.
  ///
  /// Kept from the connect rather than re-discovered per read: service
  /// discovery is the slow part of opening a link, and a second pass while a
  /// device is already streaming at 25 Hz is a stall no caller asked for.
  final List<BluetoothService> _services;
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
  Future<List<int>?> readCharacteristic({
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    if (!_currentState.isConnected) {
      throw BleConnectionException('Link to $deviceId is not connected');
    }

    for (final BluetoothService service in _services) {
      if (!_uuidEquals(service.uuid, serviceUuid)) continue;
      for (final BluetoothCharacteristic characteristic
          in service.characteristics) {
        if (!_uuidEquals(characteristic.uuid, characteristicUuid)) continue;
        // Present but not readable is the same answer as absent, and asking
        // anyway earns a GATT error on some stacks and a hang on others.
        if (!characteristic.properties.read) return null;
        try {
          return await characteristic.read();
        } on FlutterBluePlusException catch (error) {
          throw BleConnectionException(
            'Read of $characteristicUuid on $deviceId failed: '
            '${error.description ?? error.code}',
          );
        }
      }
    }
    return null;
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
