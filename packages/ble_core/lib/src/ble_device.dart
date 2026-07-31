import 'dart:typed_data';

import 'device_profile.dart';

/// A device seen in a scan, described in this package's own terms.
///
/// Deliberately not `flutter_blue_plus`'s `ScanResult`. Re-exporting the
/// vendor's type — which is what this workspace did before — puts it in the
/// signature of every picker widget and controller that touches a scan, so
/// swapping the BLE stack stops being a one-file change and becomes a
/// breaking change for consumer UI code.
class BleDevice implements BleDeviceLike {
  const BleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    this.manufacturerData = const <int, Uint8List>{},
    this.serviceUuids = const <String>[],
  });

  /// The platform's handle for this device, and the only thing that can be
  /// passed back to [BleBackend.connect].
  ///
  /// **Not a stable hardware identifier, and not a MAC address on every
  /// platform.** On Android this is the MAC. On iOS and macOS, Core Bluetooth
  /// substitutes a UUID of its own that is not derived from any intrinsic
  /// property of the peripheral. Anything that needs to identify the same
  /// physical device across platforms — or to show a user a MAC — has to get
  /// it from the device itself, via [manufacturerData], the GATT Device
  /// Information Service, or a device-specific protocol record. See
  /// `hardwareIdOrNull` on a device family's profile for how each one does it.
  final String id;

  /// The advertised name, empty when the device advertises none.
  @override
  final String name;

  /// Signal strength in dBm; closer to zero is stronger.
  final int rssi;

  /// Manufacturer-specific advertisement payload, keyed by company id.
  ///
  /// Worth keeping even though most consumers ignore it: it is one of the two
  /// places a device can publish a real hardware identifier that survives the
  /// iOS/Android [id] split.
  final Map<int, Uint8List> manufacturerData;

  /// Service UUIDs the device advertises, lowercased.
  @override
  final List<String> serviceUuids;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleDevice &&
          other.id == id &&
          other.name == name &&
          other.rssi == rssi;

  @override
  int get hashCode => Object.hash(id, name, rssi);

  @override
  String toString() => 'BleDevice($id, $name, ${rssi}dBm)';
}
