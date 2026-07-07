/// Builds the hex-digit string for an OBD-II request, per the ELM327
/// datasheet's "OBD Commands" and "Talking to the Vehicle" sections —
/// e.g. `buildObdRequest(0x01, [0x0C])` produces `'010C'` (mode 01,
/// PID 0x0C, engine RPM).
///
/// [expectedResponseCount], if provided, appends the single hex digit
/// documented in "Talking to the Vehicle" that tells the ELM327 how many
/// response lines to wait for, letting it skip its final timeout once
/// that many have arrived.
String buildObdRequest(
  int mode,
  List<int> pidBytes, {
  int? expectedResponseCount,
}) {
  final modeHex = mode.toRadixString(16).padLeft(2, '0').toUpperCase();
  final pidHex = pidBytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();
  final suffix = expectedResponseCount != null
      ? expectedResponseCount.toRadixString(16).toUpperCase()
      : '';
  return '$modeHex$pidHex$suffix';
}
