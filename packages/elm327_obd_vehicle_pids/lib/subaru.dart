import 'package:elm327_obd/elm327_obd.dart';
import 'package:elm327_obd_vehicle_pids/vehicle_profile.dart';

import 'src/gr86_brz_pids.dart';

/// Subaru WRX/STI-specific Mode 22 PIDs.
///
/// These IDs and scaling formulas are commonly referenced in the
/// open-source Subaru tuning community (e.g. RomRaider's ECU
/// definition files) for MY05+ WRX/STI-generation ECUs using SSM-over-
/// OBD. Byte offsets and scaling can vary by model year and ECU
/// calibration — verify against your specific vehicle before relying
/// on these for anything beyond experimentation.
///
/// Declared as [PidDefinition]s rather than [CustomPid]s so an app can offer
/// them in a picker and store the choice: a [CustomPid] carries a decoder
/// closure, which does not survive being written to disk.
const List<PidDefinition> subaruWrxStiPidDefinitions = <PidDefinition>[
  PidDefinition(
    name: 'Manifold Relative Pressure',
    unit: 'psi',
    mode: 0x22,
    pidBytes: <int>[0x11, 0x01],
    // Commonly published scaling: raw byte / 10 = psi relative to
    // atmospheric.
    scale: 0.1,
    header: '7E0',
  ),
];

/// The same catalog in the form [Elm327Client.queryCustomPid] takes directly.
final subaruWrxStiPids = PidSet('Subaru WRX/STI', <CustomPid>[
  for (final definition in subaruWrxStiPidDefinitions) definition.toCustomPid(),
]);

/// Subaru vehicle profiles, looked up by make/model/year via
/// [findVehicleProfile]. Currently just the BRZ (2022+, Gen 2, shares
/// its FA24 platform with the Toyota GR86 — see `toyota.dart` and
/// `src/gr86_brz_pids.dart` for the shared PID catalog and its
/// provenance/confidence notes).
final subaruProfiles = [
  VehicleProfile(
    make: 'Subaru',
    model: 'BRZ',
    yearStart: 2022,
    pidSet: gr86Brz2022PidSet,
  ),
];
