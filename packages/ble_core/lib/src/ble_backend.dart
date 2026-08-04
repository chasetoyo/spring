import 'dart:async';

import 'ble_connection.dart';
import 'ble_device.dart';
import 'device_profile.dart';

/// Whether the host's Bluetooth radio can be used, and if not, why.
///
/// Shaped like a permission result rather than a boolean because the
/// distinctions drive different UI: [denied] is worth asking about again,
/// [deniedForever] needs a trip to system settings, and [adapterOff] is the
/// radio being switched off, which no per-app permission screen can fix.
enum BleAvailability {
  ready,
  denied,
  deniedForever,
  adapterOff,
  unsupported;

  bool get isReady => this == BleAvailability.ready;

  /// True when prompting again could plausibly change the answer.
  bool get isRequestable => this == BleAvailability.denied;
}

/// The whole vendor surface, behind one interface.
///
/// Exists so `flutter_blue_plus` can be confined to a single implementation
/// file and, just as importantly, so it can be replaced by a fake in tests.
/// The previous transport called `FlutterBluePlus` statics directly from a
/// class with a private constructor, which made the BLE layer structurally
/// untestable — its entire test suite asserted that the transport class was
/// a type, which passes for any class literal and asserts nothing.
abstract interface class BleBackend {
  /// The current radio and permission state, without prompting.
  Future<BleAvailability> availability();

  /// Prompts for whatever the platform requires, and reports the result.
  ///
  /// Unlike the helper this replaces, the permission results are inspected
  /// rather than discarded — a denial used to surface only as an opaque
  /// failure from whichever BLE call happened next.
  Future<BleAvailability> requestPermissions();

  /// Opens this app's entry in system settings.
  ///
  /// The only way out of [BleAvailability.deniedForever], since neither
  /// platform will show a permission prompt again once it has been refused
  /// for good. Also where a user has to go to clear a bond on iOS.
  Future<void> openAppSettings();

  /// Devices matching [profile], streamed as they are discovered.
  ///
  /// Filtering is part of the contract, not an optional extra: an unfiltered
  /// scan returns every BLE device in range, which is unusable in a picker
  /// once more than one device family is supported.
  ///
  /// **Ends when the scan window closes.** A caller may treat the done event
  /// as "discovery is over" and say so, and may cancel the subscription at any
  /// point to stop early — including after the window has closed, where the
  /// cancellation must still complete promptly rather than waiting on an
  /// advertisement that is no longer coming.
  Stream<BleDevice> scan({
    DeviceProfile? profile,
    Duration timeout = const Duration(seconds: 10),
  });

  /// Stops an in-progress [scan].
  Future<void> stopScan();

  /// Opens a link to [deviceId] and resolves [profile]'s characteristics.
  ///
  /// Throws [BleConnectionException] if the link cannot be established and
  /// [BleProfileException] if it can but the device does not carry the
  /// profile — the distinction matters, because the first is worth retrying
  /// and the second means the user picked the wrong device.
  Future<BleConnection> connect(
    String deviceId,
    DeviceProfile profile, {
    Duration timeout = const Duration(seconds: 15),
  });

  /// Removes the OS-level bond with [deviceId], where the platform allows it.
  ///
  /// **Android only.** iOS has no public API for this; a bond there can only
  /// be cleared by the user in system settings. Returns whether a bond was
  /// actually removed, so callers can decide whether to tell the user to
  /// finish the job themselves rather than guessing.
  ///
  /// Rarely fires for serial-bridge hardware, which is typically Just Works
  /// and never bonds — but it is cheap and correct when there is a bond.
  Future<bool> removeBond(String deviceId);

  /// Releases any resources the backend holds.
  Future<void> dispose();
}
