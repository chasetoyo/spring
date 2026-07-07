import 'package:elm327_obd/elm327_obd.dart';

/// Subaru-specific Mode 22 PIDs.
///
/// These IDs and scaling formulas are commonly referenced in the
/// open-source Subaru tuning community (e.g. RomRaider's ECU
/// definition files) for MY05+ WRX/STI-generation ECUs using SSM-over-
/// OBD. Byte offsets and scaling can vary by model year and ECU
/// calibration — verify against your specific vehicle before relying
/// on these for anything beyond experimentation.
final subaruPids = PidSet('Subaru', [
  CustomPid(
    name: 'Manifold Relative Pressure',
    mode: 0x22,
    pidBytes: [0x11, 0x01],
    unit: 'psi',
    // Commonly published scaling: raw byte / 10 = psi relative to
    // atmospheric.
    decode: (bytes) => bytes[0] / 10,
    targetHeader: '7E0',
  ),
]);
