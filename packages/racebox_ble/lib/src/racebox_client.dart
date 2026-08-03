import 'dart:async';

import 'package:ble_core/ble_core.dart';

import 'racebox_data.dart';
import 'racebox_profile.dart';
import 'ubx_frame.dart';

/// A RaceBox, as a [BleDeviceClient].
///
/// The opposite interaction model to the ELM327 client next door, which is
/// why `BleDeviceClient` covers only the link lifecycle: an ELM327 answers
/// questions one at a time, a RaceBox volunteers a packet ~25 times a second
/// and is asked nothing. There is no init handshake — live data is on by
/// default, so subscribing to notifications *is* the setup.
class RaceBoxClient implements BleDeviceClient {
  RaceBoxClient({
    required BleBackend backend,
    required String deviceId,
    // Nullable rather than defaulted: the profile carries a RegExp, which can
    // never be a constant, and only constants may be default values.
    DeviceProfile? profile,
  }) : _backend = backend,
       _deviceId = deviceId,
       _profile = profile ?? raceBoxProfile;

  final BleBackend _backend;
  final String _deviceId;
  final DeviceProfile _profile;

  final UbxFramer _framer = UbxFramer();
  final StreamController<RaceBoxData> _data =
      StreamController<RaceBoxData>.broadcast();
  final StreamController<BleConnectionState> _state =
      StreamController<BleConnectionState>.broadcast();

  BleConnection? _connection;
  StreamSubscription<List<int>>? _inputSubscription;
  StreamSubscription<BleConnectionState>? _stateSubscription;

  /// Readings as they arrive.
  ///
  /// Broadcast and unbuffered: a listener attached late gets the next packet,
  /// not a backlog. At 25 Hz a backlog is stale within a heartbeat, and
  /// replaying it would put a car somewhere it no longer is.
  Stream<RaceBoxData> get data => _data.stream;

  /// Every framed packet, including ones this package does not decode.
  ///
  /// Useful for diagnostics against a device whose firmware sends messages
  /// this version has never seen.
  Stream<UbxFrame> get frames => _frames.stream;

  final StreamController<UbxFrame> _frames =
      StreamController<UbxFrame>.broadcast();

  @override
  Stream<BleConnectionState> get connectionState => _state.stream;

  @override
  bool get isConnected => _connection?.currentState.isConnected ?? false;

  @override
  Future<void> connect() async {
    if (_connection != null) return;

    _state.add(BleConnectionState.connecting);
    // Anything left in the framer belongs to a previous link and can only
    // corrupt the first packet of this one.
    _framer.reset();

    final BleConnection connection = await _backend.connect(
      _deviceId,
      _profile,
    );
    _connection = connection;
    _stateSubscription = connection.state.listen(_state.add);
    _inputSubscription = connection.input.listen(_onBytes);
  }

  void _onBytes(List<int> chunk) {
    for (final UbxFrame frame in _framer.add(chunk)) {
      if (!_frames.isClosed) _frames.add(frame);
      if (!frame.isRaceBoxData) continue;
      final RaceBoxData? reading = RaceBoxData.decode(frame.payload);
      if (reading != null && !_data.isClosed) _data.add(reading);
    }
  }

  @override
  Future<void> disconnect() async {
    await _inputSubscription?.cancel();
    _inputSubscription = null;
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    await _connection?.disconnect();
    _connection = null;
    _framer.reset();
    if (!_state.isClosed) _state.add(BleConnectionState.disconnected);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _data.close();
    await _frames.close();
    await _state.close();
  }
}
