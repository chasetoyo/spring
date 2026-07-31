/// Base type for every error raised by the BLE link itself, as opposed to
/// whatever protocol a device speaks over it.
///
/// This lives here rather than in a device package on purpose. A transport
/// failure is not an OBD-II condition, and `elm327_obd` owning the transport
/// error type — as it did before `ble_core` existed — meant a second device
/// family had to either import an ELM327 namespace to catch a dropped
/// connection or invent a parallel hierarchy.
class BleException implements Exception {
  BleException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The adapter is off, unsupported, or the user withheld permission.
///
/// Distinct from [BleConnectionException] because it is not retryable by
/// trying again — something outside the app has to change first.
class BleUnavailableException extends BleException {
  BleUnavailableException(super.message);
}

/// Establishing or holding the link failed: the device refused, went out of
/// range, or dropped mid-session.
class BleConnectionException extends BleException {
  BleConnectionException(super.message);
}

/// The device connected but does not expose the GATT profile we asked for.
///
/// Usually a wrong [BleException]-adjacent assumption rather than a fault:
/// the UUIDs in a `DeviceProfile` were guessed, or the user picked a device
/// of the wrong family from an unfiltered scan.
class BleProfileException extends BleException {
  BleProfileException(super.message);
}

/// An operation did not complete within its deadline.
class BleTimeoutException extends BleException {
  BleTimeoutException(super.message);
}
