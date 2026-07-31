import 'package:ble_core/ble_core.dart';

/// The GATT profile a RaceBox exposes.
///
/// Nordic UART — the same generic serial-over-BLE service a great many
/// unrelated devices use — which is exactly why the name pattern is not
/// optional here. Filtering on the service alone would fill the picker with
/// everything from heart-rate straps to development boards.
/// Not `const`, unlike the ELM327 profile next door: a `RegExp` can never be
/// a constant, and the name filter is not optional for a device sitting on a
/// service this widely shared.
final DeviceProfile raceBoxProfile = DeviceProfile(
  name: 'RaceBox',
  serviceUuid: '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
  // Named from the device's point of view, as Nordic does: the host writes to
  // RX and subscribes to TX.
  writeCharacteristicUuid: '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
  notifyCharacteristicUuid: '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
  namePattern: raceBoxNamePattern,
);

/// Matches the advertised name, e.g. `RaceBox Mini 3241059358`.
///
/// The trailing digits are the unit's serial number, which makes the
/// advertised name the one identifier that is identical on Android and iOS —
/// iOS never exposes a MAC, so this is what lets the same physical device
/// resolve to the same account row from either platform.
final RegExp raceBoxNamePattern = RegExp(
  r'^RaceBox\s+(?:Mini\s+S|Mini|Micro)\s+(?<serial>\d{4,})$',
  caseSensitive: false,
);

/// The serial from an advertised name, or null when it does not match.
String? raceBoxSerialFrom(String advertisedName) {
  final RegExpMatch? match = raceBoxNamePattern.firstMatch(
    advertisedName.trim(),
  );
  final String? serial = match?.namedGroup('serial');
  return (serial == null || serial.isEmpty) ? null : serial;
}
