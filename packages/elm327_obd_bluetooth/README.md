# elm327_obd_bluetooth

Bluetooth Low Energy (BLE) transport for `elm327_obd`, wrapping
`flutter_blue_plus`. Contains no AT/OBD knowledge — it only moves bytes,
proving the transport/core separation described in the project's design is
real.

Most ELM327 adapters are Bluetooth Classic (SPP), but some — including the
Veepeak OBDCheck BLE/BLE+ this project targets — use BLE instead, which is
why this package is built on `flutter_blue_plus` rather than a Classic-SPP
plugin.

## Usage

```dart
import 'package:elm327_obd/elm327_obd.dart';
import 'package:elm327_obd_bluetooth/elm327_obd_bluetooth.dart';

final result = await BleElm327Transport.scan().first; // first discovered device
final transport = await BleElm327Transport.connect(result.device);

final client = Elm327Client(transport);
await client.connect();

// ...later:
await transport.disconnect();
```

BLE serial-bridge adapters like this typically don't need OS-level pairing
first — a scan result is enough to connect, unlike Bluetooth Classic SPP.

## GATT UUIDs — verify against your adapter

`BleElm327Transport.connect()` defaults to the common "HM-10 style"
UART-over-BLE profile many budget BLE-serial OBD-II adapters use: service
`FFF0`, write characteristic `FFF1`, notify characteristic `FFF2`
(`BleElm327Transport.defaultServiceUuid` etc.). **This is commonly
referenced, not verified against a specific Veepeak firmware revision** — if
`connect()` throws an `Elm327TransportException` saying a service/
characteristic wasn't found, inspect your adapter's actual GATT profile
(e.g. with a generic BLE scanner app like nRF Connect) and pass the real
UUIDs as named parameters to `connect()`.

## Licensing note

`flutter_blue_plus` is dual-licensed; `BleElm327Transport.connect()` passes
`License.nonprofit`, appropriate for personal/hobby use. If this app is ever
used commercially, revisit that — see the `flutter_blue_plus` package's
`LICENSE` for terms.

## Permissions

`BleElm327Transport` requests the Android runtime permissions it needs
(`bluetoothScan`, `bluetoothConnect`, `locationWhenInUse`) internally before
scanning or connecting, via `permission_handler`. Consuming apps still need
to declare the corresponding `<uses-permission>`/`<uses-feature>` entries in
their own `AndroidManifest.xml` — see
`apps/elm327_demo/android/app/src/main/AndroidManifest.xml` for the exact
set (covers both pre-Android-12 and Android 12+ permission models).

## Testing

Unit tests (`flutter test`) cover what can be verified without hardware
(e.g. that the transport implements the core interface, and the default
UUID constants). A full `scan()`/`connect()` round trip requires a real BLE
adapter and is exercised through the `elm327_demo` app instead, not this
package's unit tests.
