/// Test doubles for `ble_core`.
///
/// Shipped from `lib/` rather than `test/` on purpose: every package that
/// depends on `ble_core` — the device families and the apps above them —
/// needs the same fake, and a double under `test/` is reachable only from
/// its own package. This is the `package:http/testing.dart` arrangement.
library;

export 'src/testing/fake_ble_backend.dart';
