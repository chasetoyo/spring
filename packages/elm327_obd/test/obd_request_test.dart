import 'package:elm327_obd/elm327_obd.dart';
import 'package:test/test.dart';

void main() {
  test('builds a mode 01 single-byte PID request', () {
    expect(buildObdRequest(0x01, [0x0C]), '010C');
  });

  test('builds a mode 09 VIN request', () {
    expect(buildObdRequest(0x09, [0x02]), '0902');
  });

  test('builds a mode-only request with no PID bytes', () {
    expect(buildObdRequest(0x03, const []), '03');
  });

  test('builds a mode 22 two-byte PID request', () {
    expect(buildObdRequest(0x22, [0x11, 0x01]), '221101');
  });

  test('appends the expected-response-count digit when provided', () {
    expect(buildObdRequest(0x01, [0x05], expectedResponseCount: 1), '01051');
  });
}
