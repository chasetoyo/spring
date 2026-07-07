import 'package:elm327_obd/elm327_obd.dart';
import 'package:test/test.dart';

void main() {
  test('parses a single-line response', () {
    final response = parseObdResponse('41 0C 1A F8');
    expect(response.frames, [
      [0x41, 0x0C, 0x1A, 0xF8],
    ]);
    expect(response.firstFrame, [0x41, 0x0C, 0x1A, 0xF8]);
  });

  test('ignores a leading SEARCHING... status line', () {
    final response = parseObdResponse('SEARCHING...\r41 00 BE 1F B8 10');
    expect(response.frames, [
      [0x41, 0x00, 0xBE, 0x1F, 0xB8, 0x10],
    ]);
  });

  test('returns one frame per line for a multi-ECU reply', () {
    final response = parseObdResponse(
      '41 00 BE 3E B8 11\r41 00 80 10 80 00',
    );
    expect(response.frames, [
      [0x41, 0x00, 0xBE, 0x3E, 0xB8, 0x11],
      [0x41, 0x00, 0x80, 0x10, 0x80, 0x00],
    ]);
  });

  test('reassembles a multiline CAN response by segment number', () {
    final raw =
        '014\r0: 49 02 01 31 44 34\r1: 47 50 30 30 52 35 35\r'
        '2: 42 31 32 33 34 35 36';
    final response = parseObdResponse(raw);
    expect(response.frames, [
      [
        0x49, 0x02, 0x01, 0x31, 0x44, 0x34, //
        0x47, 0x50, 0x30, 0x30, 0x52, 0x35, 0x35, //
        0x42, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36,
      ],
    ]);
  });

  test('returns no frames for an empty response', () {
    final response = parseObdResponse('   \r  ');
    expect(response.frames, isEmpty);
    expect(response.firstFrame, isEmpty);
  });
}
