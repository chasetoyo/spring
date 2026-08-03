import 'custom_pid.dart';
import 'errors.dart';
import 'obd_request.dart';
import 'pid.dart';

/// A PID described entirely by data, so it can be stored, edited and shipped
/// across a process boundary.
///
/// [Pid] and [CustomPid] both carry a [PidDecoder] closure, which is fine for
/// a catalogue compiled into an app and impossible for one a user types in — a
/// function does not survive JSON. This describes the decode instead:
///
/// ```text
/// raw   = big-endian integer over the first [byteCount] data bytes
/// value = raw * scale + offset
/// ```
///
/// That shape covers essentially every PID published on a forum or in a
/// manufacturer table: engine RPM is `scale: 0.25`, coolant temperature is
/// `offset: -40`, a throttle percentage is `scale: 100 / 255`, and a boost PID
/// quoted as `(A*256+B)/8 - 48` is `byteCount: 2, scale: 0.125, offset: -48`.
///
/// It deliberately cannot express bitfields or piecewise formulas. Supporting
/// those means shipping an expression parser, and a parser turns a typo in a
/// settings field into a failure in the middle of a recorded session.
class PidDefinition {
  const PidDefinition({
    required this.name,
    required this.unit,
    required this.mode,
    required this.pidBytes,
    this.byteCount = 1,
    this.signed = false,
    this.scale = 1,
    this.offset = 0,
    this.header,
    this.minInterval = Duration.zero,
  });

  factory PidDefinition.fromJson(Map<String, Object?> json) {
    return PidDefinition(
      name: json['name']! as String,
      unit: (json['unit'] as String?) ?? '',
      mode: (json['mode'] as num).toInt(),
      pidBytes: parsePidHex(json['pid']! as String),
      byteCount: (json['bytes'] as num?)?.toInt() ?? 1,
      signed: (json['signed'] as bool?) ?? false,
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      offset: (json['offset'] as num?)?.toDouble() ?? 0,
      header: json['header'] as String?,
      minInterval: Duration(
        milliseconds: (json['min_interval_ms'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  /// Doubles as the exported channel name, so it is written the way it should
  /// read in a column header rather than as an identifier.
  final String name;
  final String unit;
  final int mode;

  /// The PID itself, one byte for a standard Mode 01 request and typically two
  /// for a manufacturer-specific Mode 22 one.
  final List<int> pidBytes;

  /// How many response bytes make up the value.
  final int byteCount;

  /// Whether those bytes are two's-complement. Rare, but a handful of
  /// temperature and trim PIDs need it, and reading one unsigned turns a small
  /// negative into a very large positive rather than failing visibly.
  final bool signed;

  final double scale;
  final double offset;

  /// `ATSH` target for a physically-addressed PID, or null to leave the
  /// protocol's functional header alone.
  final String? header;

  /// The floor on this channel's polling period.
  ///
  /// An ELM327 answers one command at a time, so every channel in the rotation
  /// costs every other channel. Coolant temperature moves over minutes and
  /// does not deserve the same share of a slow link as throttle position.
  final Duration minInterval;

  /// The hex the adapter is actually sent, e.g. `'010C'`.
  String get requestHex => buildObdRequest(mode, pidBytes);

  /// Whether this has to go through [Elm327Client.queryCustomPid].
  ///
  /// A single-byte PID with no header override is better served by
  /// [Elm327Client.queryPid], which also checks the PID echo in the reply and
  /// so catches a response that belongs to a different request.
  bool get needsCustomQuery => pidBytes.length != 1 || header != null;

  /// Turns response bytes — mode and PID echo already stripped — into a value.
  num decodeBytes(List<int> bytes) {
    if (bytes.length < byteCount) {
      throw Elm327ProtocolException(
        '$name: expected $byteCount data byte(s), got ${bytes.length}',
      );
    }

    var raw = 0;
    for (var i = 0; i < byteCount; i++) {
      raw = (raw << 8) | (bytes[i] & 0xFF);
    }

    if (signed) {
      final signBit = 1 << (byteCount * 8 - 1);
      if ((raw & signBit) != 0) raw -= signBit << 1;
    }

    return raw * scale + offset;
  }

  Pid toPid() {
    if (pidBytes.length != 1) {
      throw ArgumentError('$name: toPid needs a single-byte PID');
    }
    return Pid(
      name: name,
      mode: mode,
      pid: pidBytes.single,
      unit: unit,
      decode: decodeBytes,
    );
  }

  CustomPid toCustomPid() => CustomPid(
    name: name,
    mode: mode,
    pidBytes: pidBytes,
    unit: unit,
    decode: decodeBytes,
    targetHeader: header,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'unit': unit,
    'mode': mode,
    'pid': formatPidHex(pidBytes),
    'bytes': byteCount,
    'signed': signed,
    'scale': scale,
    'offset': offset,
    if (header != null) 'header': header,
    'min_interval_ms': minInterval.inMilliseconds,
  };

  PidDefinition copyWith({String? name, Duration? minInterval}) {
    return PidDefinition(
      name: name ?? this.name,
      unit: unit,
      mode: mode,
      pidBytes: pidBytes,
      byteCount: byteCount,
      signed: signed,
      scale: scale,
      offset: offset,
      header: header,
      minInterval: minInterval ?? this.minInterval,
    );
  }

  @override
  String toString() => 'PidDefinition($name, $requestHex)';

  /// The Mode 01 channels a consumer app can assume any OBD-II vehicle has.
  ///
  /// The same set as [StandardPids], restated declaratively so a standard
  /// channel and a hand-entered one travel the same code path — there is no
  /// second decoder to keep in step.
  static const List<PidDefinition> standardCatalogue = <PidDefinition>[
    PidDefinition(
      name: 'Engine RPM',
      unit: 'rpm',
      mode: 0x01,
      pidBytes: <int>[0x0C],
      byteCount: 2,
      scale: 0.25,
    ),
    PidDefinition(
      name: 'Throttle (%)',
      unit: '%',
      mode: 0x01,
      pidBytes: <int>[0x11],
      scale: 100 / 255,
    ),
    PidDefinition(
      name: 'Engine Load (%)',
      unit: '%',
      mode: 0x01,
      pidBytes: <int>[0x04],
      scale: 100 / 255,
    ),
    PidDefinition(
      name: 'MAF (g/s)',
      unit: 'g/s',
      mode: 0x01,
      pidBytes: <int>[0x10],
      byteCount: 2,
      scale: 0.01,
    ),
    // Slow channels. These move over minutes, and every request one makes is a
    // request throttle position does not get.
    PidDefinition(
      name: 'Coolant Temp (C)',
      unit: 'C',
      mode: 0x01,
      pidBytes: <int>[0x05],
      offset: -40,
      minInterval: Duration(seconds: 5),
    ),
    PidDefinition(
      name: 'Intake Air Temp (C)',
      unit: 'C',
      mode: 0x01,
      pidBytes: <int>[0x0F],
      offset: -40,
      minInterval: Duration(seconds: 5),
    ),
    PidDefinition(
      name: 'Fuel Level (%)',
      unit: '%',
      mode: 0x01,
      pidBytes: <int>[0x2F],
      scale: 100 / 255,
      minInterval: Duration(seconds: 30),
    ),
    // Present so it can be enabled deliberately, absent from [defaultSelection]
    // because GPS measures road speed better than the drivetrain reports it.
    PidDefinition(
      name: 'Vehicle Speed (km/h)',
      unit: 'km/h',
      mode: 0x01,
      pidBytes: <int>[0x0D],
      minInterval: Duration(seconds: 1),
    ),
  ];

  /// What to poll when nobody has chosen.
  static List<PidDefinition> get defaultSelection => standardCatalogue
      .where((d) => d.name != 'Vehicle Speed (km/h)')
      .toList(growable: false);
}

/// Parses `'221E1C'` into `[0x22, 0x1E, 0x1C]`… minus the mode, which is
/// stored separately — so this takes only the PID digits, e.g. `'1E1C'`.
List<int> parsePidHex(String hex) {
  final cleaned = hex.replaceAll(RegExp(r'[\s:]'), '');
  if (cleaned.isEmpty || cleaned.length.isOdd) {
    throw FormatException('PID must be whole bytes of hex', hex);
  }
  final bytes = <int>[];
  for (var i = 0; i < cleaned.length; i += 2) {
    final byte = int.tryParse(cleaned.substring(i, i + 2), radix: 16);
    if (byte == null) throw FormatException('Not hex', hex, i);
    bytes.add(byte);
  }
  return bytes;
}

String formatPidHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
