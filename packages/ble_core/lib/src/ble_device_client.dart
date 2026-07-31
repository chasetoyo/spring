import 'dart:async';

import 'ble_connection.dart';

/// What every device family's client can do, regardless of what it speaks.
///
/// Only the link lifecycle lives here. Device-specific capability —
/// `queryPid` on an ELM327, a `Stream<RaceBoxData>` on a RaceBox — hangs off
/// the concrete client, because the two families have genuinely nothing in
/// common past this point: one is synchronous request/response over ASCII,
/// the other is push-only binary at ~25 Hz. Forcing a shared data method onto
/// both would mean inventing an abstraction neither wants.
abstract interface class BleDeviceClient {
  /// Link state for the device this client owns.
  Stream<BleConnectionState> get connectionState;

  /// Whether the link is currently up.
  bool get isConnected;

  /// Opens the link and performs whatever session setup the family needs.
  ///
  /// Separated from the backend's link-level connect on purpose: the ELM327
  /// runs an AT init sequence here, a RaceBox runs nothing at all, and
  /// conflating "the radio link is up" with "the device session is ready" is
  /// what made the old client's hardcoded `ATZ/ATE0/ATL0/ATH0/ATSP0` sequence
  /// impossible to reuse.
  Future<void> connect();

  /// Closes the link, leaving the client reusable.
  Future<void> disconnect();

  /// Releases the client for good.
  Future<void> dispose();
}
