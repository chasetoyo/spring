# elm327_demo

Flutter demo/verification app for the `elm327_obd` library ecosystem. Its
job is to prove the whole stack works against real hardware, not to be a
polished production diagnostic app.

## Screens

- **Device picker** — lists paired Bluetooth devices (via
  `elm327_obd_bluetooth`), connects on tap, surfaces connection errors.
- **Dashboard** — polls engine RPM, vehicle speed, coolant temp, and
  throttle position once per second; "Read DTCs" / "Clear DTCs" buttons
  (clearing prompts for confirmation, since Mode 04 also wipes freeze-frame
  and O2 test data, not just the check-engine light).
- **Terminal** — a raw AT/OBD command box with a scrolling response log, for
  low-level debugging when the dashboard doesn't behave as expected.

## Running it

ELM327 adapters are Bluetooth Classic (SPP), which isn't supported on
desktop or web — you need a real Android device and a paired ELM327
adapter:

```bash
flutter pub get
flutter run -d <android-device-id>
```

`flutter test` and `flutter analyze` work without hardware, but they only
cover what doesn't require an actual Bluetooth connection (see
`elm327_obd`'s and `elm327_obd_bluetooth`'s own READMEs for what their test
suites do and don't cover). Pairing a real adapter and driving this app
against a real vehicle is the actual end-to-end proof the library works.
