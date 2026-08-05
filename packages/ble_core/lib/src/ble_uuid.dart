/// Comparing GATT UUIDs written at different lengths.
///
/// BLE lets a 16- or 32-bit UUID stand in for the full 128-bit form built on
/// the Bluetooth base UUID, and the two spellings mean the same thing. A
/// device advertising `0000fff0-0000-1000-8000-00805f9b34fb` and a profile
/// declaring `fff0` must compare equal, or every short-form profile silently
/// filters out every device it describes.
///
/// One copy, because there were two: the profile matcher and the
/// `flutter_blue_plus` backend each carried their own, and a rule that decides
/// whether a characteristic exists is not one to have two versions of.
library;

/// Whether [a] and [b] name the same GATT attribute, at either length.
bool bleUuidEquals(String a, String b) =>
    normalizeBleUuid(a) == normalizeBleUuid(b);

/// [raw] reduced to the form [bleUuidEquals] compares.
///
/// Lower-cased, dashes dropped, and — for a UUID sitting on the Bluetooth
/// base — narrowed to its distinguishing head with leading zeros trimmed, so
/// `0000fff0-0000-1000-8000-00805f9b34fb` and `fff0` reduce alike.
String normalizeBleUuid(String raw) {
  final String lower = raw.toLowerCase().replaceAll('-', '');
  if (lower.length == 32 && lower.endsWith('00001000800000805f9b34fb')) {
    return lower.substring(0, 8).replaceFirst(RegExp(r'^0+'), '');
  }
  return lower.replaceFirst(RegExp(r'^0+'), '');
}
