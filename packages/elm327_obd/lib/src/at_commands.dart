/// Builders for the ELM327 'AT' commands this library uses, per the
/// ELM327 datasheet's "AT Command Summary" (no leading 'AT' needed on
/// the argument — each builder returns the full command string).
class AtCommands {
  AtCommands._();

  /// `ATZ` — full reset.
  static const reset = 'ATZ';

  /// `ATWS` — warm start (faster reset, skips the LED test).
  static const warmStart = 'ATWS';

  /// `ATDP` — describe the currently selected/detected protocol by name.
  static const describeProtocol = 'ATDP';

  /// `ATDPN` — describe the currently selected/detected protocol by
  /// number (prefixed with `A` if automatic searching is enabled).
  static const describeProtocolNumber = 'ATDPN';

  /// `ATCRA` with no argument — clears any CAN receive-address filter
  /// back to automatic.
  static const resetReceiveAddress = 'ATCRA';

  /// `ATE0`/`ATE1` — character echo off/on.
  static String echo(bool on) => 'ATE${on ? 1 : 0}';

  /// `ATL0`/`ATL1` — linefeeds off/on.
  static String linefeeds(bool on) => 'ATL${on ? 1 : 0}';

  /// `ATH0`/`ATH1` — display of header bytes off/on.
  static String headers(bool on) => 'ATH${on ? 1 : 0}';

  /// `ATSP h` — set the protocol to `h` (0-9, A, B, or C) and save it as
  /// the default. `null` means protocol 0 (automatic search).
  static String setProtocol(int? protocol) =>
      'ATSP${(protocol ?? 0).toRadixString(16).toUpperCase()}';

  /// `ATTP h` — try protocol `h` without persisting it as the default.
  static String tryProtocol(int protocol) =>
      'ATTP${protocol.toRadixString(16).toUpperCase()}';

  /// `ATSH value` — set the header bytes used for outgoing requests, for
  /// example `'7E0'` (11-bit CAN physical address) or
  /// `'18DB33F1'` (29-bit CAN functional address).
  static String setHeader(String value) => 'ATSH$value';
}
