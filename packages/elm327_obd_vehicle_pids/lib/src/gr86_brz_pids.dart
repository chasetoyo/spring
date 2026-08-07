import 'package:elm327_obd/elm327_obd.dart';

/// Manufacturer-specific Mode $21 ("request manufacturer-specific data")
/// PIDs for the Toyota GR86 / Subaru BRZ (Gen 2, 2022+, FA24 engine). The
/// two cars are mechanically identical rebadges of the same platform, so
/// this one catalog is shared by both `toyota.dart` and `subaru.dart`.
///
/// **Provenance:** these are community-reverse-engineered via the Torque
/// app's custom-PID mechanism, not from an official Toyota/Subaru service
/// manual — see the individual PID doc comments for sourcing and
/// confidence level. Verify against your specific vehicle (send the raw
/// request via the demo app's terminal screen and check the response)
/// before relying on these beyond experimentation.
final gr86Brz2022PidSet = PidSet('Toyota GR86 / Subaru BRZ (Gen 2, 2022+)', [
  // Community source: ft86club.com "Oil temperature reading through OBD2"
  // thread (contributor "andreyiv"), corroborated independently by
  // gps-laptimer.de and racechrono.com forum threads and an OBDLink
  // custom-PID screenshot, all reporting the same request/header/formula.
  // **Confirmed on Gen 1 (2013-2020 FA20 86/BRZ/FR-S) only** — not yet
  // independently confirmed on Gen 2 (2022+ FA24), though Toyota/Subaru's
  // shared diagnostic architecture makes it a reasonable starting guess.
  // The response is unusually long (~31 bytes total per multiple
  // reports) for what standard OBD-II Mode 01 PIDs would return in 1-4
  // bytes — oil temperature is only the first byte of that block; the
  // rest is undecoded.
  CustomPid(
    name: 'Engine Oil Temperature',
    mode: 0x21,
    pidBytes: [0x01],
    unit: '°C',
    decode: (bytes) => bytes[0] - 40,
    targetHeader: '7E0',
  ),

  // Community source: ft86club.com "OFFICIAL Torque Android app
  // PID/Misc Thread". Formula derived from the fuel tank capacity
  // (13.2 US gal ≈ 50 L): raw byte already reads as a 0-100 percentage
  // (mirrors the standard Mode 01 PID 2F fuel-level formula, just under
  // a manufacturer-specific PID/header instead). Byte offset 10 (0xA)
  // per a separate, independent report of this PID's response layout —
  // **the offset's exact meaning (relative to the raw response vs. the
  // response with the mode/PID echo already stripped, as this library
  // does) isn't confirmed, so this is the least certain PID here.**
  // Same Gen 1 vs. Gen 2 caveat as engine oil temperature above.
  CustomPid(
    name: 'Fuel Level (manufacturer-specific)',
    mode: 0x21,
    pidBytes: [0x29],
    unit: '%',
    decode: (bytes) => bytes[10].toDouble(),
    targetHeader: '7C0',
  ),
]);
