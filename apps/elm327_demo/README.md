# elm327_demo

Flutter demo/verification app for the `elm327_obd` library ecosystem. Its
job is to prove the whole stack works against real hardware, not to be a
polished production diagnostic app.

## Screens

- **Device picker** — scans for nearby BLE devices (via
  `elm327_obd_bluetooth`), connects on tap, surfaces connection errors. No
  OS-level pairing needed first for BLE serial-bridge adapters like this. If
  the default GATT profile doesn't match your adapter, the connection error
  itself reports every service/characteristic the device actually exposes
  (see `elm327_obd_bluetooth`'s README).
- **Vehicle select** — pick a make/model (from `elm327_obd_vehicle_pids`'s
  `VehicleProfile`s) to unlock its manufacturer-specific custom PIDs on the
  All PIDs screen, or skip for standard-PIDs-only.
- **Dashboard** — polls engine RPM, vehicle speed, coolant temp, and
  throttle position once per second; "Read DTCs" / "Clear DTCs" buttons
  (clearing prompts for confirmation, since Mode 04 also wipes freeze-frame
  and O2 test data, not just the check-engine light).
- **All PIDs** — a one-shot verification sweep, not a live dashboard: on
  demand, queries every `StandardPids` entry plus the selected vehicle's
  custom PIDs (if any), and lists what came back — a decoded value, or an
  error — for each. This is the "does the library actually work end to
  end" check.
- **Terminal** — a raw AT/OBD command box with a scrolling response log, for
  low-level debugging when the dashboard doesn't behave as expected.

## Running it

This project targets a Veepeak OBDCheck BLE/BLE+ adapter over Bluetooth Low
Energy. Validated on a real connected Android device — you need one of
those (plus the adapter) to actually exercise the Bluetooth path:

```bash
flutter pub get
flutter run -d <android-device-id>
```

`flutter test` and `flutter analyze` work without hardware, but they only
cover what doesn't require an actual Bluetooth connection (see
`elm327_obd`'s and `elm327_obd_bluetooth`'s own READMEs for what their test
suites do and don't cover). Pairing a real adapter and driving this app
against a real vehicle is the actual end-to-end proof the library works.
