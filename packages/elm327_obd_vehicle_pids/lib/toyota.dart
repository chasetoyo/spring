import 'package:elm327_obd_vehicle_pids/vehicle_profile.dart';

import 'src/gr86_brz_pids.dart';

/// Toyota vehicle profiles. Currently just the GR86 (2022+, Gen 2,
/// shares its FA24 platform with the Subaru BRZ — see `subaru.dart` and
/// `src/gr86_brz_pids.dart` for the shared PID catalog and its
/// provenance/confidence notes).
final toyotaProfiles = [
  VehicleProfile(
    make: 'Toyota',
    model: 'GR86',
    yearStart: 2022,
    pidSet: gr86Brz2022PidSet,
  ),
];
