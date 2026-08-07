import 'package:elm327_obd/elm327_obd.dart';
import 'package:test/test.dart';

void main() {
  test(
    'engineRpm builds the right request and decodes per the datasheet example',
    () {
      expect(StandardPids.engineRpm.requestHex, '010C');
      // datasheet: 41 0C 1A F8 -> (0x1AF8) / 4 = 1726 rpm
      expect(StandardPids.engineRpm.decode([0x1A, 0xF8]), 1726);
    },
  );

  test('coolantTemp decodes per the datasheet example', () {
    expect(StandardPids.coolantTemp.requestHex, '0105');
    // datasheet: 41 05 7B -> 0x7B (123) - 40 = 83 degrees C
    expect(StandardPids.coolantTemp.decode([0x7B]), 83);
  });

  test('vehicleSpeed decodes a raw byte directly as km/h', () {
    expect(StandardPids.vehicleSpeed.requestHex, '010D');
    expect(StandardPids.vehicleSpeed.decode([0x50]), 80);
  });

  test('throttlePosition and engineLoad scale a byte to a percentage', () {
    expect(StandardPids.throttlePosition.decode([0xFF]), closeTo(100, 0.01));
    expect(StandardPids.engineLoad.decode([0x00]), 0);
  });

  test('engineOilTemp decodes using the standard temperature formula', () {
    expect(StandardPids.engineOilTemp.requestHex, '015C');
    expect(StandardPids.engineOilTemp.decode([0x5A]), 50);
  });

  test('all lists every standard PID exactly once, all under mode 01', () {
    expect(StandardPids.all, isNotEmpty);
    expect(
      StandardPids.all.map((p) => p.pid).toSet(),
      hasLength(StandardPids.all.length),
    );
    expect(StandardPids.all.every((p) => p.mode == 0x01), isTrue);
  });
}
