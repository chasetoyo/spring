import 'package:elm327_obd/elm327_obd.dart';
import 'package:test/test.dart';

void main() {
  group('isErrorResponse', () {
    test('detects the standard error markers', () {
      expect(isErrorResponse('?'), isTrue);
      expect(isErrorResponse('NO DATA'), isTrue);
      expect(isErrorResponse('UNABLE TO CONNECT'), isTrue);
      expect(isErrorResponse('BUS BUSY'), isTrue);
      expect(isErrorResponse('BUS ERROR'), isTrue);
      expect(isErrorResponse('CAN ERROR'), isTrue);
      expect(isErrorResponse('<DATA ERROR'), isTrue);
      expect(isErrorResponse('<RX ERROR'), isTrue);
      expect(isErrorResponse('STOPPED'), isTrue);
      expect(isErrorResponse('BUFFER FULL'), isTrue);
      expect(isErrorResponse('ERR94'), isTrue);
    });

    test('does not flag normal responses', () {
      expect(isErrorResponse('OK'), isFalse);
      expect(isErrorResponse('41 0C 1A F8'), isFalse);
      expect(isErrorResponse('SEARCHING...\r41 00 BE 1F B8 10'), isFalse);
    });
  });

  group('mapErrorResponse', () {
    test('maps NO DATA to a timeout exception', () {
      expect(mapErrorResponse('NO DATA'), isA<Elm327TimeoutException>());
    });

    test('maps UNABLE TO CONNECT to a protocol exception', () {
      expect(
        mapErrorResponse('UNABLE TO CONNECT'),
        isA<Elm327ProtocolException>(),
      );
    });

    test('maps ? to a command exception', () {
      expect(mapErrorResponse('?'), isA<Elm327CommandException>());
    });

    test('maps BUFFER FULL to a transport exception', () {
      expect(mapErrorResponse('BUFFER FULL'), isA<Elm327TransportException>());
    });

    test('falls back to the base exception for unknown text', () {
      expect(mapErrorResponse('SOMETHING WEIRD'), isA<Elm327Exception>());
    });
  });
}
