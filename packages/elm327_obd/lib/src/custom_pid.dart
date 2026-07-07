import 'obd_request.dart';
import 'pid.dart';

/// A manufacturer-specific PID, typically Mode 22, addressed either
/// functionally (no [targetHeader]) or physically to one ECU (with
/// [targetHeader] set to that ECU's header, e.g. `'7E0'`), per the
/// ELM327 datasheet's "Setting the Headers" section on physical vs.
/// functional addressing.
class CustomPid {
  const CustomPid({
    required this.name,
    required this.mode,
    required this.pidBytes,
    required this.unit,
    required this.decode,
    this.targetHeader,
  });

  final String name;
  final int mode;
  final List<int> pidBytes;
  final String unit;
  final PidDecoder decode;

  /// If set, [Elm327Client.queryCustomPid] sets `ATSH` to this value
  /// before sending the request, so it reaches this specific ECU rather
  /// than whatever functional address the current protocol defaults to.
  final String? targetHeader;

  String get requestHex => buildObdRequest(mode, pidBytes);
}

/// A named, groupable bundle of [CustomPid]s — one per manufacturer
/// catalog in `elm327_obd_vehicle_pids`.
class PidSet {
  const PidSet(this.name, this.pids);

  final String name;
  final List<CustomPid> pids;
}
