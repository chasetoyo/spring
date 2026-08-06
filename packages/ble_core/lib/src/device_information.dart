import 'dart:convert';

import 'ble_connection.dart';

/// The standard GATT Device Information Service, `0x180a`.
///
/// Lives in `ble_core` rather than with a device family because it belongs to
/// no family: it is a Bluetooth SIG service, and a RaceBox, an ELM327 clone and
/// a heart-rate strap all publish it in the same shape. Putting it next to the
/// RaceBox profile would mean copying it for the next device that has one.
///
/// Every field is optional in the specification and genuinely absent in
/// practice — cheap serial-bridge modules routinely publish a manufacturer and
/// nothing else — so each is nullable and a missing one is not an error.
class DeviceInformation {
  const DeviceInformation({
    this.modelNumber,
    this.serialNumber,
    this.firmwareRevision,
    this.hardwareRevision,
    this.manufacturer,
  });

  /// `0x2a24` — the model, as the manufacturer names it.
  final String? modelNumber;

  /// `0x2a25` — the unit's serial number.
  final String? serialNumber;

  /// `0x2a26` — the firmware revision currently running.
  final String? firmwareRevision;

  /// `0x2a27` — the hardware revision of the unit itself.
  final String? hardwareRevision;

  /// `0x2a29` — the manufacturer's name.
  final String? manufacturer;

  /// Whether the device published anything at all.
  bool get isEmpty =>
      modelNumber == null &&
      serialNumber == null &&
      firmwareRevision == null &&
      hardwareRevision == null &&
      manufacturer == null;

  bool get isNotEmpty => !isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInformation &&
          other.modelNumber == modelNumber &&
          other.serialNumber == serialNumber &&
          other.firmwareRevision == firmwareRevision &&
          other.hardwareRevision == hardwareRevision &&
          other.manufacturer == manufacturer;

  @override
  int get hashCode => Object.hash(
    modelNumber,
    serialNumber,
    firmwareRevision,
    hardwareRevision,
    manufacturer,
  );

  @override
  String toString() =>
      'DeviceInformation(model: $modelNumber, serial: $serialNumber, '
      'firmware: $firmwareRevision, hardware: $hardwareRevision, '
      'manufacturer: $manufacturer)';
}

/// UUIDs for the Device Information Service and the characteristics read from
/// it, at their full 128-bit length.
///
/// Full form rather than `180a`, because that is how a device reports them and
/// how the vendor stacks print them; `bleUuidEquals` normalises either way, so
/// the choice costs nothing and makes these greppable against a BLE sniffer
/// log.
abstract final class DeviceInformationUuids {
  static const String service = '0000180a-0000-1000-8000-00805f9b34fb';
  static const String modelNumber = '00002a24-0000-1000-8000-00805f9b34fb';
  static const String serialNumber = '00002a25-0000-1000-8000-00805f9b34fb';
  static const String firmwareRevision = '00002a26-0000-1000-8000-00805f9b34fb';
  static const String hardwareRevision = '00002a27-0000-1000-8000-00805f9b34fb';
  static const String manufacturer = '00002a29-0000-1000-8000-00805f9b34fb';
}

/// Reads whatever [connection]'s device publishes about itself.
///
/// **Sequential, deliberately.** Android's GATT client runs one operation at a
/// time and reports a second concurrent read as an outright failure rather
/// than queueing it, so five reads in a `Future.wait` is five ways to get one
/// answer and four errors.
///
/// Throws `BleConnectionException` if the link is down, and lets a mid-read
/// drop propagate for the same reason: a caller told "this device has no
/// serial number" would cache that and stop asking, when the truth was that
/// the link died halfway through. A characteristic the device simply does not
/// carry comes back null and is skipped.
Future<DeviceInformation> readDeviceInformation(
  BleConnection connection,
) async {
  Future<String?> read(String characteristicUuid) async {
    final List<int>? bytes = await connection.readCharacteristic(
      serviceUuid: DeviceInformationUuids.service,
      characteristicUuid: characteristicUuid,
    );
    return bytes == null ? null : _toUtf8String(bytes);
  }

  return DeviceInformation(
    modelNumber: await read(DeviceInformationUuids.modelNumber),
    serialNumber: await read(DeviceInformationUuids.serialNumber),
    firmwareRevision: await read(DeviceInformationUuids.firmwareRevision),
    hardwareRevision: await read(DeviceInformationUuids.hardwareRevision),
    manufacturer: await read(DeviceInformationUuids.manufacturer),
  );
}

/// The specification calls these UTF-8 strings; the hardware does not always
/// agree.
///
/// Invalid sequences are replaced rather than thrown on: this is a label for a
/// settings screen, and one mangled byte in a firmware string should not fail
/// the whole read.
String? _toUtf8String(List<int> bytes) {
  final String decoded = const Utf8Decoder(allowMalformed: true)
      .convert(bytes)
      // A fixed-width field flushed as-is arrives NUL-padded, and padding is
      // not part of the value — nor is it whitespace that `trim` would take.
      .replaceAll('\u0000', '')
      .trim();
  // A device that answered without saying anything reads the same as one that
  // does not carry the characteristic at all.
  return decoded.isEmpty ? null : decoded;
}
