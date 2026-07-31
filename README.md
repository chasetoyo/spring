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
| [`packages/ble_core`](packages/ble_core) | Flutter | Vendor-neutral BLE plumbing: scanning, permissions, connections and device profiles, shared by every device family |
| [`packages/elm327_obd`](packages/elm327_obd) | Pure Dart | AT-command/OBD-II protocol core: no Flutter or Bluetooth dependency |
| [`packages/elm327_obd_vehicle_pids`](packages/elm327_obd_vehicle_pids) | Pure Dart | Manufacturer-specific custom PID catalogs (Subaru, with more to come) |
| [`packages/elm327_obd_bluetooth`](packages/elm327_obd_bluetooth) | Flutter | Binds the OBD-II core to a `ble_core` link, plus the ELM327 GATT profile |
| [`apps/elm327_demo`](apps/elm327_demo) | Flutter app | Device picker, live dashboard, and raw AT/OBD terminal for end-to-end verification |

`ble_core` is where a second device family plugs in. It owns no protocol: a
family supplies a `DeviceProfile` describing its GATT shape and a client that
interprets the bytes, and gets scanning, filtering, permissions, MTU
negotiation and connection-state tracking for free. `package:ble_core/testing.dart`
ships a `FakeBleBackend` so those clients can be tested without hardware.

## Getting started

```bash
dart pub global activate melos
flutter pub get   # resolves the whole workspace (Dart pub workspaces) - use
                  # flutter, not dart, since some member packages need the
                  # Flutter SDK constraint
melos list        # confirm all five packages are recognized
```

See **[`docs/commands.md`](docs/commands.md)** for the full command
reference: running tests, analyzing, running/building the demo app,
cleaning, and melos-specific commands (this repo is new to melos, so it's
written assuming no prior familiarity).

To run the demo app, pair a real ELM327 BLE adapter (this project targets a
Veepeak OBDCheck BLE/BLE+) with a connected Android device, then:

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
