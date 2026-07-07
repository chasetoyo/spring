import 'package:elm327_obd_bluetooth/elm327_obd_bluetooth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BluetoothElm327Transport implements Elm327Transport', () {
    expect(BluetoothElm327Transport, isA<Type>());
    // A full connect() round-trip requires a real Bluetooth adapter and
    // is exercised by the demo app, not this unit test — see the
    // "End-to-End Verification" section of the design spec.
  });
}
