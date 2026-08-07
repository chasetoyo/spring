# elm327_obd_vehicle_pids

Manufacturer-specific OBD-II custom PID catalogs, built on the `CustomPid`/
`PidSet` mechanism from `elm327_obd`, organized by a make/model/year
`VehicleProfile` lookup.

This is one package covering every make, rather than a separate pub package
per manufacturer — each make gets its own importable entry point so
consumers only pull in the makes they actually use:

```dart
import 'package:elm327_obd_vehicle_pids/toyota.dart';
import 'package:elm327_obd_vehicle_pids/vehicle_profile.dart';

final profile = findVehicleProfile(
  toyotaProfiles,
  make: 'Toyota',
  model: 'GR86',
  year: 2023,
);
if (profile != null) {
  final oilTemp = profile.pidSet.pids.firstWhere((p) => p.name == 'Engine Oil Temperature');
  final value = await client.queryCustomPid(oilTemp);
}
```

## Vehicle profiles

`VehicleProfile` (in `vehicle_profile.dart`) pairs a make/model/year range
with the `PidSet` known to work for it — ECU firmware (and sometimes the
PID map itself) can change between model years even within the "same"
model, so profiles are scoped to a year range rather than just a model
name. `findVehicleProfile()` looks one up by make/model/year across
however many make-specific catalogs you combine.

## Available catalogs

- **Toyota GR86 / Subaru BRZ, Gen 2 (2022+, FA24 engine)** — `toyota.dart`
  (`toyotaProfiles`) and `subaru.dart` (`subaruProfiles`) both resolve to
  the same shared `PidSet` in `src/gr86_brz_pids.dart`, since the two cars
  are mechanically identical rebadges of one platform. Currently covers
  Mode $21 (manufacturer-specific data) engine oil temperature and fuel
  level — **community-reverse-engineered, not from an official service
  manual, and only independently confirmed on Gen 1 (2013-2020 FA20) cars
  so far** — see the doc comments in `src/gr86_brz_pids.dart` for sourcing,
  confidence level per PID, and how to verify against your specific Gen 2
  vehicle (e.g. via the demo app's terminal screen: send the raw request
  and inspect what comes back).
- `subaru.dart` also exports `subaruWrxStiPids` — a separate, older Mode 22
  starter catalog for MY05+ WRX/STI-generation ECUs (SSM-over-OBD), kept
  as-is; likewise flagged as needing verification against your specific
  model year.

## Adding a new make or model

1. Add a `PidSet` under `lib/src/` (share it across makes/models if the
   underlying platform is identical, like the GR86/BRZ catalog does).
2. Add or extend a make-specific entry point under `lib/` (e.g.
   `lib/ford.dart`) exporting a `List<VehicleProfile>` for that make, built
   from the shared `PidSet`.
3. Add a matching test under `test/`.

No new package scaffolding, pubspec, or pub.dev listing needed — that's
the point of keeping all makes in one package.

## Testing

`dart test` / `dart analyze` — no hardware required; these are just PID
definitions, pure decode functions, and profile-matching logic.
