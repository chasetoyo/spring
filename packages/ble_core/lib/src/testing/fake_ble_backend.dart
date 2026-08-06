import 'dart:async';

import '../ble_backend.dart';
import '../ble_connection.dart';
import '../ble_device.dart';
import '../ble_exception.dart';
import '../ble_uuid.dart';
import '../device_profile.dart';

/// An in-memory [BleConnection] a test drives directly.
///
/// Tests push bytes in with [emit], read what the code under test sent from
/// [written], and sever the link with [drop] to exercise the mid-session
/// disconnect path that no test could reach before `ble_core` existed.
class FakeBleConnection implements BleConnection {
  FakeBleConnection({this.deviceId = 'fake-device'});

  @override
  final String deviceId;

  final List<List<int>> written = <List<int>>[];

  final StreamController<List<int>> _input =
      StreamController<List<int>>.broadcast();
  final StreamController<BleConnectionState> _state =
      StreamController<BleConnectionState>.broadcast();

  BleConnectionState _currentState = BleConnectionState.connected;

  /// Set to have [write] throw, simulating a link that died between the
  /// state check and the characteristic write.
  Object? writeError;

  /// Values [readCharacteristic] will return, keyed by characteristic UUID at
  /// any length. A characteristic with no entry is one the device does not
  /// carry, which is the ordinary case for most of the Device Information
  /// Service.
  final Map<String, List<int>> characteristicValues = <String, List<int>>{};

  /// Characteristic UUIDs [readCharacteristic] was asked for, in order, so a
  /// test can assert a caller did not re-read what it had already cached.
  final List<String> reads = <String>[];

  /// Set to have [readCharacteristic] throw, simulating a link that dropped
  /// partway through a multi-characteristic read.
  Object? readError;

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
    final Object? error = writeError;
    if (error != null) throw error;
    if (!_currentState.isConnected) {
      throw BleConnectionException('Link to $deviceId is not connected');
    }
    written.add(List<int>.unmodifiable(bytes));
  }

  @override
  Future<List<int>?> readCharacteristic({
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    reads.add(characteristicUuid);
    final Object? error = readError;
    if (error != null) throw error;
    if (!_currentState.isConnected) {
      throw BleConnectionException('Link to $deviceId is not connected');
    }
    for (final MapEntry<String, List<int>> entry
        in characteristicValues.entries) {
      if (bleUuidEquals(entry.key, characteristicUuid)) {
        return List<int>.unmodifiable(entry.value);
      }
    }
    return null;
  }

  @override
  Future<void> disconnect() async {
    if (_currentState == BleConnectionState.disconnected) return;
    _currentState = BleConnectionState.disconnected;
    if (!_state.isClosed) _state.add(BleConnectionState.disconnected);
    await _input.close();
    await _state.close();
  }

  /// Delivers [bytes] as though the device had notified them.
  void emit(List<int> bytes) => _input.add(bytes);

  /// Simulates the device dropping out from under us, leaving the streams
  /// open so a listener still observes the state change.
  void drop() {
    if (_currentState == BleConnectionState.disconnected) return;
    _currentState = BleConnectionState.disconnected;
    _state.add(BleConnectionState.disconnected);
  }
}

/// A [BleBackend] that talks to nothing.
///
/// The point of the whole `BleBackend` seam: the vendor-backed
/// implementation calls platform statics and cannot be stood up in a unit
/// test, so before this the BLE layer had no test coverage at all.
class FakeBleBackend implements BleBackend {
  FakeBleBackend({
    this.availabilityResult = BleAvailability.ready,
    this.requestResult,
    List<BleDevice>? devices,
  }) : devices = devices ?? <BleDevice>[];

  /// What [availability] reports.
  BleAvailability availabilityResult;

  /// What [requestPermissions] reports; falls back to [availabilityResult].
  BleAvailability? requestResult;

  /// Devices [scan] will emit, before profile filtering.
  List<BleDevice> devices;

  /// Connections handed out by [connect], keyed by device id. A device with
  /// no entry gets a fresh [FakeBleConnection].
  final Map<String, FakeBleConnection> connections =
      <String, FakeBleConnection>{};

  /// Device ids [connect] should reject, and with what.
  final Map<String, Object> connectErrors = <String, Object>{};

  /// Device ids that have had [removeBond] called on them.
  final List<String> bondsRemoved = <String>[];

  /// What [removeBond] reports — false models iOS, where no API exists.
  bool bondRemovalSupported = true;

  int scanCount = 0;
  int stopScanCount = 0;
  int openAppSettingsCount = 0;
  bool disposed = false;

  @override
  Future<BleAvailability> availability() async => availabilityResult;

  @override
  Future<BleAvailability> requestPermissions() async =>
      requestResult ?? availabilityResult;

  @override
  Future<void> openAppSettings() async => openAppSettingsCount++;

  @override
  Stream<BleDevice> scan({
    DeviceProfile? profile,
    Duration timeout = const Duration(seconds: 10),
  }) async* {
    scanCount++;
    final BleAvailability state = requestResult ?? availabilityResult;
    if (!state.isReady) {
      throw BleUnavailableException('Bluetooth unavailable: ${state.name}');
    }
    for (final BleDevice device in devices) {
      if (profile != null && !profile.matches(device)) continue;
      yield device;
    }
  }

  @override
  Future<void> stopScan() async => stopScanCount++;

  @override
  Future<BleConnection> connect(
    String deviceId,
    DeviceProfile profile, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final Object? error = connectErrors[deviceId];
    if (error != null) throw error;
    return connections.putIfAbsent(
      deviceId,
      () => FakeBleConnection(deviceId: deviceId),
    );
  }

  @override
  Future<bool> removeBond(String deviceId) async {
    if (!bondRemovalSupported) return false;
    bondsRemoved.add(deviceId);
    return true;
  }

  @override
  Future<void> dispose() async => disposed = true;
}
