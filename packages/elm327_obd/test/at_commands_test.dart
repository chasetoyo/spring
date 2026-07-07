import 'package:elm327_obd/elm327_obd.dart';
import 'package:test/test.dart';

void main() {
  test('static commands', () {
    expect(AtCommands.reset, 'ATZ');
    expect(AtCommands.warmStart, 'ATWS');
    expect(AtCommands.describeProtocol, 'ATDP');
    expect(AtCommands.describeProtocolNumber, 'ATDPN');
    expect(AtCommands.resetReceiveAddress, 'ATCRA');
  });

  test('toggle commands', () {
    expect(AtCommands.echo(true), 'ATE1');
    expect(AtCommands.echo(false), 'ATE0');
    expect(AtCommands.linefeeds(false), 'ATL0');
    expect(AtCommands.headers(false), 'ATH0');
  });

  test('protocol commands', () {
    expect(AtCommands.setProtocol(null), 'ATSP0');
    expect(AtCommands.setProtocol(2), 'ATSP2');
    expect(AtCommands.setProtocol(10), 'ATSPA');
    expect(AtCommands.tryProtocol(6), 'ATTP6');
  });

  test('setHeader passes the value through', () {
    expect(AtCommands.setHeader('7E0'), 'ATSH7E0');
    expect(AtCommands.setHeader('18DB33F1'), 'ATSH18DB33F1');
  });
}
