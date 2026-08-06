import 'dart:async';

/// Where a link is in its lifecycle.
///
/// The workspace had no connection-state model at all before this: a dropped
/// adapter simply stopped emitting bytes, a pending command's `Completer`
/// never completed and never errored, and the app modelled "connected" as
/// "the client object is non-null". A GNSS logger streaming at 25 Hz from a
/// moving car will drop, so this has to be observable.
enum BleConnectionState {
  disconnected,
  connecting,
  connected;

  bool get isConnected => this == BleConnectionState.connected;
}

/// A live byte channel to one device.
///
/// Bytes only — this knows nothing about AT commands, UBX frames, or any
/// other framing. Whatever a device family speaks is that family's problem,
/// which is what lets one BLE implementation serve an ASCII request/response
/// dongle and a binary push-only logger without either leaking into it.
abstract interface class BleConnection {
  /// The device this link was opened against.
  String get deviceId;

  /// Bytes from the device, exactly as the notify characteristic delivered
  /// them.
  ///
  /// Deliberately unfiltered. The previous BLE transport stripped `0x00` here
  /// because the ELM327 datasheet notes stray NULs — which silently destroys
  /// any binary protocol, and was redundant anyway since the ELM327 framer
  /// already skips them. Byte-level quirks belong to the device layer.
  Stream<List<int>> get input;

  /// Link state, starting with the current value on listen.
  Stream<BleConnectionState> get state;

  /// The most recent state, for callers that need it synchronously.
  BleConnectionState get currentState;

  /// Sends bytes to the device.
  Future<void> write(List<int> bytes);

  /// Reads one characteristic outright, off any service the device carries.
  ///
  /// The escape hatch from `DeviceProfile`, which describes exactly one serial
  /// pair — a write characteristic and a notify characteristic — and so cannot
  /// reach a read-only attribute at all. The standard Device Information
  /// Service is the case that forced it: `0x180a` publishes a model, a serial
  /// number and firmware and hardware revisions, none of them notifiable and
  /// none of them reachable through a profile.
  ///
  /// Returns null when the device does not carry the attribute, or carries it
  /// without the read property. **Absence is ordinary**, not a fault: every
  /// characteristic in that service is optional and a device may publish three
  /// of five. Throws [BleConnectionException] when the link is down or the
  /// read is refused — failing to find out is a different fact from there
  /// being nothing to find, and a caller that conflates them will report a
  /// dropped link as a device with no serial number.
  ///
  /// Either UUID may be written at 16-, 32- or 128-bit length.
  Future<List<int>?> readCharacteristic({
    required String serviceUuid,
    required String characteristicUuid,
  });

  /// Drops the link and closes [input] and [state].
  Future<void> disconnect();
}
