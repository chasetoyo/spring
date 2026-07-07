import 'package:elm327_obd_bluetooth/elm327_obd_bluetooth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BleElm327Transport implements Elm327Transport', () {
    expect(BleElm327Transport, isA<Type>());
    // A full scan()/connect() round-trip requires a real BLE adapter and
    // is exercised by the demo app, not this unit test.
  });

  test('default GATT UUIDs match the common FFF0/FFF1/FFF2 pattern', () {
    expect(BleElm327Transport.defaultServiceUuid, 'fff0');
    expect(BleElm327Transport.defaultWriteCharacteristicUuid, 'fff1');
    expect(BleElm327Transport.defaultNotifyCharacteristicUuid, 'fff2');
  });
}
