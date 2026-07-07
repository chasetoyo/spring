import 'obd_request.dart';

/// Converts a PID's raw data bytes (with the mode-echo and PID-echo
/// bytes already stripped) into a physical value.
typedef PidDecoder = num Function(List<int> bytes);

/// One standard Mode 01 "current data" PID, per SAE J1979 / the ELM327
/// datasheet's "Talking to the Vehicle" examples.
class Pid {
  const Pid({
    required this.name,
    required this.mode,
    required this.pid,
    required this.unit,
    required this.decode,
  });

  final String name;
  final int mode;
  final int pid;
  final String unit;
  final PidDecoder decode;

  /// The hex request string to send, e.g. `'010C'` for engine RPM.
  String get requestHex => buildObdRequest(mode, [pid]);
}

/// The common Mode 01 PIDs most consumer diagnostic apps need. Decode
/// formulas are the standard SAE J1979 formulas used throughout the
/// ELM327 datasheet's worked examples.
class StandardPids {
  StandardPids._();

  static final engineRpm = Pid(
    name: 'Engine RPM',
    mode: 0x01,
    pid: 0x0C,
    unit: 'rpm',
    decode: (bytes) => ((bytes[0] * 256) + bytes[1]) / 4,
  );

  static final vehicleSpeed = Pid(
    name: 'Vehicle Speed',
    mode: 0x01,
    pid: 0x0D,
    unit: 'km/h',
    decode: (bytes) => bytes[0],
  );

  static final coolantTemp = Pid(
    name: 'Engine Coolant Temperature',
    mode: 0x01,
    pid: 0x05,
    unit: '°C',
    decode: (bytes) => bytes[0] - 40,
  );

  static final intakeAirTemp = Pid(
    name: 'Intake Air Temperature',
    mode: 0x01,
    pid: 0x0F,
    unit: '°C',
    decode: (bytes) => bytes[0] - 40,
  );

  static final throttlePosition = Pid(
    name: 'Throttle Position',
    mode: 0x01,
    pid: 0x11,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final engineLoad = Pid(
    name: 'Calculated Engine Load',
    mode: 0x01,
    pid: 0x04,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final mafRate = Pid(
    name: 'MAF Air Flow Rate',
    mode: 0x01,
    pid: 0x10,
    unit: 'g/s',
    decode: (bytes) => ((bytes[0] * 256) + bytes[1]) / 100,
  );

  static final fuelLevel = Pid(
    name: 'Fuel Level',
    mode: 0x01,
    pid: 0x2F,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final List<Pid> all = [
    engineRpm,
    vehicleSpeed,
    coolantTemp,
    intakeAirTemp,
    throttlePosition,
    engineLoad,
    mafRate,
    fuelLevel,
  ];
}
