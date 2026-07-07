# elm327_obd_vehicle_pids

Manufacturer-specific OBD-II custom PID catalogs, built on the `CustomPid`/
`PidSet` mechanism from `elm327_obd`.

This is one package covering every make, rather than a separate pub package
per manufacturer — each make gets its own importable entry point so
consumers only pull in the makes they actually use:

```dart
import 'package:elm327_obd_vehicle_pids/subaru.dart';

final value = await client.queryCustomPid(subaruPids.pids.first);
```

## Available catalogs

- `subaru.dart` — `subaruPids`, a starter set of commonly-referenced Subaru
  Mode 22 PIDs (e.g. manifold relative pressure). **Verify these against
  your specific model year/ECU calibration** before relying on them for
  anything beyond experimentation — see the doc comments in `lib/subaru.dart`
  for provenance.

## Adding a new make

Add a new file under `lib/` (e.g. `lib/ford.dart`) exporting a `PidSet` built
from `CustomPid` entries, and a matching test under `test/`. No new package
scaffolding, pubspec, or pub.dev listing needed — that's the point of
keeping all makes in one package.

## Testing

`dart test` / `dart analyze` — no hardware required; these are just PID
definitions and pure decode functions.
