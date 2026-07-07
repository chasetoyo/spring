# elm327_obd_bluetooth

Bluetooth Classic SPP transport for `elm327_obd`, wrapping
`flutter_bluetooth_serial`. Contains no AT/OBD knowledge — it only moves
bytes, proving the transport/core separation described in the project's
design is real.

ELM327 adapters are almost universally Bluetooth Classic (SPP), not BLE, so
this package targets Android/iOS via `flutter_bluetooth_serial` rather than
a BLE plugin.

## Usage

```dart
import 'package:elm327_obd/elm327_obd.dart';
import 'package:elm327_obd_bluetooth/elm327_obd_bluetooth.dart';

final devices = await BluetoothElm327Transport.getBondedDevices();
final transport = await BluetoothElm327Transport.connect(devices.first.address);

final client = Elm327Client(transport);
await client.connect();

// ...later:
await transport.disconnect();
```

## Permissions

`BluetoothElm327Transport` requests the Android runtime permissions it needs
(`bluetoothScan`, `bluetoothConnect`, `locationWhenInUse`) internally before
scanning or connecting, via `permission_handler`. Consuming apps still need
to declare the corresponding `<uses-permission>` entries in their own
`AndroidManifest.xml` — see `apps/elm327_demo/android/app/src/main/AndroidManifest.xml`
for the exact set (covers both pre-Android-12 and Android 12+ permission
models).

## Testing

Unit tests (`flutter test`) cover what can be verified without hardware
(e.g. that the transport implements the core interface). A full
`connect()`-to-adapter round trip requires a real Bluetooth adapter and is
exercised through the `elm327_demo` app instead, not this package's unit
tests.
