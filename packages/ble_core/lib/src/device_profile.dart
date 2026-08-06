import 'ble_uuid.dart';

/// The GATT shape of one device family, as data.
///
/// Before this existed, "a Veepeak" was three default string constants on the
/// ELM327 transport and "a RaceBox" would have been a second code path. A
/// profile makes them two values of the same type: the scan filters on it, the
/// connect resolves characteristics through it, and adding a family adds a
/// constant rather than a branch.
class DeviceProfile {
  const DeviceProfile({
    required this.name,
    required this.serviceUuid,
    required this.writeCharacteristicUuid,
    required this.notifyCharacteristicUuid,
    this.namePattern,
  });

  /// Human-readable family name, for error messages and logs.
  final String name;

  /// The GATT service carrying the device's serial-style characteristics.
  final String serviceUuid;

  /// Characteristic written to, host to device.
  final String writeCharacteristicUuid;

  /// Characteristic subscribed to, device to host.
  final String notifyCharacteristicUuid;

  /// Optional advertised-name filter, applied on top of the service filter.
  ///
  /// Needed because the service UUID alone is not always discriminating —
  /// `fff0` is a generic HM-10 profile shared by a great many unrelated
  /// modules, so a scan filtered only by service still surfaces junk.
  final RegExp? namePattern;

  /// Whether [device] plausibly belongs to this family.
  ///
  /// Both checks are permissive on absence rather than strict: some stacks
  /// omit service UUIDs from the initial advertisement and only reveal them
  /// after a connect, so requiring them here would hide real devices. The
  /// authoritative check is characteristic resolution at connect time; this is
  /// only here to keep the picker list short.
  bool matches(BleDeviceLike device) {
    final RegExp? pattern = namePattern;
    if (pattern != null && !pattern.hasMatch(device.name)) return false;
    if (device.serviceUuids.isEmpty) return true;
    return device.serviceUuids.any(
      (String uuid) => bleUuidEquals(uuid, serviceUuid),
    );
  }
}

/// The slice of a device a [DeviceProfile] needs in order to judge it.
///
/// Keeps `DeviceProfile` usable from a test with a stub, and keeps
/// `ble_device.dart` and `device_profile.dart` from importing each other.
abstract interface class BleDeviceLike {
  String get name;
  List<String> get serviceUuids;
}
