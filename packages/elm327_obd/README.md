# elm327_obd

Transport-agnostic ELM327 AT-command and OBD-II protocol library, in pure
Dart (no Flutter, no Bluetooth dependency).

This package only knows how to build AT/OBD requests, parse responses, and
decode PIDs/DTCs. It talks to the adapter through the abstract
`Elm327Transport` interface, so any byte-in/byte-out channel — Bluetooth
Classic SPP (see `elm327_obd_bluetooth`), USB-serial, or a test fake — can
supply the actual bytes.

## Usage

```dart
import 'package:elm327_obd/elm327_obd.dart';

final client = Elm327Client(myTransport); // myTransport implements Elm327Transport
await client.connect(); // ATZ, ATE0, ATL0, ATH0, ATSP0

final rpm = await client.queryPid(StandardPids.engineRpm);
final codes = await client.readDtcs();
await client.clearDtcs();

// Manufacturer-specific PID (see elm327_obd_vehicle_pids for catalogs):
final value = await client.queryCustomPid(someCustomPid);
```

## What's in here

- `AtCommands` — builders for the AT commands this library uses (reset,
  echo, headers, protocol select, CAN header/filter tuning).
- `buildObdRequest` / `parseObdResponse` — OBD-II request construction and
  response parsing, including multiline/multi-ECU reassembly.
- `decodeDtc` / `decodeDtcFrame` — diagnostic trouble code decoding
  (`P0133`-style codes) per the SAE J1979 bit table.
- `StandardPids` — the scalar/numeric standard Mode 01 PIDs from SAE J1979
  (RPM, speed, temperatures, fuel trims, pressures, torque, etc. — see
  `StandardPids.all` and its doc comment for what's covered and what's
  deliberately excluded).
- `CustomPid` / `PidSet` — the generic mechanism manufacturer-specific PID
  catalogs (like `elm327_obd_vehicle_pids`) are built on, supporting
  physical addressing via a target header.
- `Elm327Exception` hierarchy — every documented ELM327 error string
  (`NO DATA`, `BUS ERROR`, `UNABLE TO CONNECT`, etc.) maps to a typed
  exception instead of a raw string.

## Testing

`dart test` runs the full suite against `FakeElm327Transport`
(`test/support/fake_transport.dart`), an in-memory transport scripted with
canned ELM327 responses — no hardware required. Run `dart analyze` for
static checks.
