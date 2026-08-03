import 'dart:async';

import 'package:ble_core/ble_core.dart';
import 'package:elm327_obd/elm327_obd.dart';

/// The GATT profile of a BLE serial-bridge OBD-II adapter.
///
/// Many budget adapters — including some Veepeak OBDCheck BLE/BLE+ units —
/// expose a generic "HM-10 style" UART-over-BLE profile: service `FFF0`, a
/// writable characteristic `FFF1`, and a notifying characteristic `FFF2`.
///
/// **This is commonly-referenced, not verified against a specific Veepeak
/// firmware revision.** If [BleBackend.connect] throws [BleProfileException]
/// for your adapter, inspect its actual GATT profile with a BLE scanner and
/// construct a [DeviceProfile] with the real UUIDs.
///
/// No name filter: these adapters advertise under a wide range of names
/// (`OBDII`, `Veepeak`, `V-LINK`, and worse), so a pattern would reject more
/// real devices than it filtered junk. The service UUID does the work.
const DeviceProfile elm327Profile = DeviceProfile(
  name: 'ELM327',
  serviceUuid: 'fff0',
  writeCharacteristicUuid: 'fff1',
  notifyCharacteristicUuid: 'fff2',
);

/// Adapts a [BleConnection] to the byte channel `elm327_obd` expects.
///
/// Nothing but a shim now. It used to own scanning, permissions, connecting
/// and characteristic discovery as statics — all of which moved to
/// [BleBackend], where a second device family can reach them and a test can
/// replace them.
///
/// It also used to strip `0x00` bytes here, which was both redundant — the
/// ELM327 framer in `elm327_obd` already skips them — and actively harmful
/// once a binary device family shares this plumbing, since UBX packets are
/// full of legitimate NUL bytes.
class BleElm327Transport implements Elm327Transport {
  BleElm327Transport(this._connection);

  final BleConnection _connection;

  @override
  Stream<List<int>> get input => _connection.input;

  @override
  Future<void> write(List<int> bytes) => _connection.write(bytes);
}

/// An ELM327 adapter reached over BLE, as a [BleDeviceClient].
///
/// Wraps rather than extends [Elm327Client] because `elm327_obd` is a pure
/// Dart package with no Flutter dependency — it is unit-tested with
/// `package:test` against a fake transport, and making it implement an
/// interface from the Flutter-dependent `ble_core` would cost that.
class Elm327BleClient implements BleDeviceClient {
  Elm327BleClient({
    required BleBackend backend,
    required String deviceId,
    DeviceProfile profile = elm327Profile,
  }) : _backend = backend,
       _deviceId = deviceId,
       _profile = profile;

  final BleBackend _backend;
  final String _deviceId;
  final DeviceProfile _profile;

  final StreamController<BleConnectionState> _state =
      StreamController<BleConnectionState>.broadcast();

  BleConnection? _connection;
  StreamSubscription<BleConnectionState>? _stateSubscription;
  Elm327Client? _client;

  /// The OBD-II client, available once [connect] has completed.
  ///
  /// Null before connecting and after disconnecting, so a caller cannot hold
  /// a stale client across a reconnect and send commands into a dead link.
  Elm327Client? get client => _client;

  @override
  Stream<BleConnectionState> get connectionState => _state.stream;

  @override
  bool get isConnected => _connection?.currentState.isConnected ?? false;

  @override
  Future<void> connect() async {
    if (_connection != null) return;

    _state.add(BleConnectionState.connecting);
    final BleConnection connection = await _backend.connect(
      _deviceId,
      _profile,
    );
    _connection = connection;
    _stateSubscription = connection.state.listen(_state.add);

    final Elm327Client client = Elm327Client(BleElm327Transport(connection));
    _client = client;
    // The AT init sequence, deliberately after the link is up rather than
    // folded into it: "the radio link is open" and "the adapter session is
    // configured" are different facts, and a RaceBox has only the first.
    await client.connect();
  }

  @override
  Future<void> disconnect() async {
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    await _client?.dispose();
    _client = null;
    await _connection?.disconnect();
    _connection = null;
    if (!_state.isClosed) _state.add(BleConnectionState.disconnected);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _state.close();
  }
}
