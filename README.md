# ELM327 OBD-II

A Dart/Flutter library ecosystem for connecting to an ELM327 Bluetooth OBD-II
adapter and reading vehicle diagnostic data (RPM, speed, coolant temp, DTCs,
VIN, and manufacturer-specific PIDs), across the protocols an ELM327
supports: SAE J1850 PWM/VPW, ISO 9141-2, ISO 14230-4 (KWP2000), and
ISO 15765-4 (CAN).

This is a melos-managed monorepo. See `CLAUDE.md` for a fuller architecture
and status summary.

## Packages

| Package | Type | Purpose |
|---|---|---|
| [`packages/elm327_obd`](packages/elm327_obd) | Pure Dart | AT-command/OBD-II protocol core: no Flutter or Bluetooth dependency |
| [`packages/elm327_obd_vehicle_pids`](packages/elm327_obd_vehicle_pids) | Pure Dart | Manufacturer-specific custom PID catalogs (Subaru, with more to come) |
| [`packages/elm327_obd_bluetooth`](packages/elm327_obd_bluetooth) | Flutter | Bluetooth Classic SPP transport implementing the core's transport interface |
| [`apps/elm327_demo`](apps/elm327_demo) | Flutter app | Device picker, live dashboard, and raw AT/OBD terminal for end-to-end verification |

## Getting started

```bash
dart pub global activate melos
dart pub get          # resolves the whole workspace (Dart pub workspaces)
melos list            # confirm all four packages are recognized
```

Run tests/analysis per package:

```bash
cd packages/elm327_obd && dart test && dart analyze
cd packages/elm327_obd_vehicle_pids && dart test && dart analyze
cd packages/elm327_obd_bluetooth && flutter test && flutter analyze
cd apps/elm327_demo && flutter test && flutter analyze
```

To run the demo app, pair a real ELM327 Bluetooth adapter with an Android
device (Bluetooth Classic SPP isn't supported on desktop/web), then:

```bash
cd apps/elm327_demo
flutter run -d <android-device-id>
```

## Design references

The original design spec and implementation plan for this project were
written using the `docs/superpowers/` skill workflow. Per this repo's rule,
those working documents are **never committed** (see `.gitignore`) — they're
local-only scratch artifacts of the planning process, not maintained project
documentation. This README and `CLAUDE.md` are the durable record instead.
