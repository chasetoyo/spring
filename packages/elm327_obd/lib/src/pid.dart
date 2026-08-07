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

/// The standard Mode 01 "current data" PIDs, per SAE J1979 / ISO 15031-5.
/// Decode formulas are the standard SAE formulas (the same ones used
/// throughout the ELM327 datasheet's worked examples). Covers the
/// scalar/numeric PIDs from `docs/superpowers/specs/obdii-pids.json`;
/// PIDs that report bitmasks, enums, or multi-value structured blocks
/// (e.g. `00`/`20`/`40`/`60`/`80` "supported PIDs" bitmaps, `01` monitor
/// status, `13`/`1D` O2 sensor presence bitmasks, `4F`/`50`/`64`/`66`
/// multi-field blocks) aren't included, since they don't reduce to one
/// meaningful physical number the way [Pid.decode] expects.
///
/// Not every vehicle supports every PID here — query `StandardPids.all`
/// PID 00 first (`PIDs supported [01-20]`) if you need to know which are
/// actually implemented before requesting them, or just try each and
/// handle `Elm327TimeoutException`/`NO DATA`.
class StandardPids {
  StandardPids._();

  static final engineLoad = Pid(
    name: 'Calculated Engine Load',
    mode: 0x01,
    pid: 0x04,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final coolantTemp = Pid(
    name: 'Engine Coolant Temperature',
    mode: 0x01,
    pid: 0x05,
    unit: '°C',
    decode: (bytes) => bytes[0] - 40,
  );

  static final shortTermFuelTrimBank1 = Pid(
    name: 'Short Term Fuel Trim — Bank 1',
    mode: 0x01,
    pid: 0x06,
    unit: '%',
    decode: (bytes) => (bytes[0] - 128) * 100 / 128,
  );

  static final longTermFuelTrimBank1 = Pid(
    name: 'Long Term Fuel Trim — Bank 1',
    mode: 0x01,
    pid: 0x07,
    unit: '%',
    decode: (bytes) => (bytes[0] - 128) * 100 / 128,
  );

  static final shortTermFuelTrimBank2 = Pid(
    name: 'Short Term Fuel Trim — Bank 2',
    mode: 0x01,
    pid: 0x08,
    unit: '%',
    decode: (bytes) => (bytes[0] - 128) * 100 / 128,
  );

  static final longTermFuelTrimBank2 = Pid(
    name: 'Long Term Fuel Trim — Bank 2',
    mode: 0x01,
    pid: 0x09,
    unit: '%',
    decode: (bytes) => (bytes[0] - 128) * 100 / 128,
  );

  static final fuelPressure = Pid(
    name: 'Fuel Pressure',
    mode: 0x01,
    pid: 0x0A,
    unit: 'kPa',
    decode: (bytes) => bytes[0] * 3,
  );

  static final intakeManifoldPressure = Pid(
    name: 'Intake Manifold Absolute Pressure',
    mode: 0x01,
    pid: 0x0B,
    unit: 'kPa',
    decode: (bytes) => bytes[0],
  );

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

  static final timingAdvance = Pid(
    name: 'Timing Advance',
    mode: 0x01,
    pid: 0x0E,
    unit: '° before TDC',
    decode: (bytes) => bytes[0] / 2 - 64,
  );

  static final intakeAirTemp = Pid(
    name: 'Intake Air Temperature',
    mode: 0x01,
    pid: 0x0F,
    unit: '°C',
    decode: (bytes) => bytes[0] - 40,
  );

  static final mafRate = Pid(
    name: 'MAF Air Flow Rate',
    mode: 0x01,
    pid: 0x10,
    unit: 'g/s',
    decode: (bytes) => ((bytes[0] * 256) + bytes[1]) / 100,
  );

  static final throttlePosition = Pid(
    name: 'Throttle Position',
    mode: 0x01,
    pid: 0x11,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final runTimeSinceEngineStart = Pid(
    name: 'Run Time Since Engine Start',
    mode: 0x01,
    pid: 0x1F,
    unit: 's',
    decode: (bytes) => (bytes[0] * 256) + bytes[1],
  );

  static final distanceWithMilOn = Pid(
    name: 'Distance Traveled with MIL On',
    mode: 0x01,
    pid: 0x21,
    unit: 'km',
    decode: (bytes) => (bytes[0] * 256) + bytes[1],
  );

  static final fuelRailPressureVacuum = Pid(
    name: 'Fuel Rail Pressure (relative to manifold vacuum)',
    mode: 0x01,
    pid: 0x22,
    unit: 'kPa',
    decode: (bytes) => ((bytes[0] * 256) + bytes[1]) * 0.079,
  );

  static final fuelRailGaugePressure = Pid(
    name: 'Fuel Rail Gauge Pressure (diesel / gasoline direct inject)',
    mode: 0x01,
    pid: 0x23,
    unit: 'kPa',
    decode: (bytes) => ((bytes[0] * 256) + bytes[1]) * 10,
  );

  static final commandedEgr = Pid(
    name: 'Commanded EGR',
    mode: 0x01,
    pid: 0x2C,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final egrError = Pid(
    name: 'EGR Error',
    mode: 0x01,
    pid: 0x2D,
    unit: '%',
    decode: (bytes) => (bytes[0] - 128) * 100 / 128,
  );

  static final commandedEvapPurge = Pid(
    name: 'Commanded Evaporative Purge',
    mode: 0x01,
    pid: 0x2E,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final fuelLevel = Pid(
    name: 'Fuel Level',
    mode: 0x01,
    pid: 0x2F,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final warmUpsSinceCodesCleared = Pid(
    name: 'Number of Warm-ups Since Codes Cleared',
    mode: 0x01,
    pid: 0x30,
    unit: 'count',
    decode: (bytes) => bytes[0],
  );

  static final distanceSinceCodesCleared = Pid(
    name: 'Distance Traveled Since Codes Cleared',
    mode: 0x01,
    pid: 0x31,
    unit: 'km',
    decode: (bytes) => (bytes[0] * 256) + bytes[1],
  );

  static final barometricPressure = Pid(
    name: 'Barometric Pressure',
    mode: 0x01,
    pid: 0x33,
    unit: 'kPa',
    decode: (bytes) => bytes[0],
  );

  static final catalystTempBank1Sensor1 = Pid(
    name: 'Catalyst Temperature — Bank 1, Sensor 1',
    mode: 0x01,
    pid: 0x3C,
    unit: '°C',
    decode: (bytes) => ((bytes[0] * 256) + bytes[1]) / 10 - 40,
  );

  static final catalystTempBank2Sensor1 = Pid(
    name: 'Catalyst Temperature — Bank 2, Sensor 1',
    mode: 0x01,
    pid: 0x3D,
    unit: '°C',
    decode: (bytes) => ((bytes[0] * 256) + bytes[1]) / 10 - 40,
  );

  static final catalystTempBank1Sensor2 = Pid(
    name: 'Catalyst Temperature — Bank 1, Sensor 2',
    mode: 0x01,
    pid: 0x3E,
    unit: '°C',
    decode: (bytes) => ((bytes[0] * 256) + bytes[1]) / 10 - 40,
  );

  static final catalystTempBank2Sensor2 = Pid(
    name: 'Catalyst Temperature — Bank 2, Sensor 2',
    mode: 0x01,
    pid: 0x3F,
    unit: '°C',
    decode: (bytes) => ((bytes[0] * 256) + bytes[1]) / 10 - 40,
  );

  static final controlModuleVoltage = Pid(
    name: 'Control Module Voltage',
    mode: 0x01,
    pid: 0x42,
    unit: 'V',
    decode: (bytes) => ((bytes[0] * 256) + bytes[1]) / 1000,
  );

  static final absoluteLoadValue = Pid(
    name: 'Absolute Load Value',
    mode: 0x01,
    pid: 0x43,
    unit: '%',
    decode: (bytes) => ((bytes[0] * 256) + bytes[1]) * 100 / 255,
  );

  static final commandedEquivalenceRatio = Pid(
    name: 'Commanded Fuel/Air Equivalence Ratio',
    mode: 0x01,
    pid: 0x44,
    unit: 'ratio',
    decode: (bytes) => ((bytes[0] * 256) + bytes[1]) / 32768,
  );

  static final relativeThrottlePosition = Pid(
    name: 'Relative Throttle Position',
    mode: 0x01,
    pid: 0x45,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final ambientAirTemp = Pid(
    name: 'Ambient Air Temperature',
    mode: 0x01,
    pid: 0x46,
    unit: '°C',
    decode: (bytes) => bytes[0] - 40,
  );

  static final throttlePositionB = Pid(
    name: 'Absolute Throttle Position B',
    mode: 0x01,
    pid: 0x47,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final throttlePositionC = Pid(
    name: 'Absolute Throttle Position C',
    mode: 0x01,
    pid: 0x48,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final acceleratorPedalPositionD = Pid(
    name: 'Accelerator Pedal Position D',
    mode: 0x01,
    pid: 0x49,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final acceleratorPedalPositionE = Pid(
    name: 'Accelerator Pedal Position E',
    mode: 0x01,
    pid: 0x4A,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final acceleratorPedalPositionF = Pid(
    name: 'Accelerator Pedal Position F',
    mode: 0x01,
    pid: 0x4B,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final commandedThrottleActuator = Pid(
    name: 'Commanded Throttle Actuator',
    mode: 0x01,
    pid: 0x4C,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final timeRunWithMilOn = Pid(
    name: 'Time Run with MIL On',
    mode: 0x01,
    pid: 0x4D,
    unit: 'min',
    decode: (bytes) => (bytes[0] * 256) + bytes[1],
  );

  static final timeSinceCodesCleared = Pid(
    name: 'Time Since Trouble Codes Cleared',
    mode: 0x01,
    pid: 0x4E,
    unit: 'min',
    decode: (bytes) => (bytes[0] * 256) + bytes[1],
  );

  static final ethanolFuelPercent = Pid(
    name: 'Ethanol Fuel %',
    mode: 0x01,
    pid: 0x52,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final absoluteEvapVaporPressure = Pid(
    name: 'Absolute Evap System Vapor Pressure',
    mode: 0x01,
    pid: 0x53,
    unit: 'kPa',
    decode: (bytes) => ((bytes[0] * 256) + bytes[1]) / 200,
  );

  static final fuelRailPressureAbsolute = Pid(
    name: 'Fuel Rail Pressure (absolute)',
    mode: 0x01,
    pid: 0x59,
    unit: 'kPa',
    decode: (bytes) => ((bytes[0] * 256) + bytes[1]) * 10,
  );

  static final relativeAcceleratorPedalPosition = Pid(
    name: 'Relative Accelerator Pedal Position',
    mode: 0x01,
    pid: 0x5A,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final hybridBatteryPackLife = Pid(
    name: 'Hybrid Battery Pack Remaining Life',
    mode: 0x01,
    pid: 0x5B,
    unit: '%',
    decode: (bytes) => bytes[0] * 100 / 255,
  );

  static final engineOilTemp = Pid(
    name: 'Engine Oil Temperature',
    mode: 0x01,
    pid: 0x5C,
    unit: '°C',
    decode: (bytes) => bytes[0] - 40,
  );

  static final fuelInjectionTiming = Pid(
    name: 'Fuel Injection Timing',
    mode: 0x01,
    pid: 0x5D,
    unit: '°',
    decode: (bytes) => (((bytes[0] * 256) + bytes[1]) - 26880) / 128,
  );

  static final engineFuelRate = Pid(
    name: 'Engine Fuel Rate',
    mode: 0x01,
    pid: 0x5E,
    unit: 'L/h',
    decode: (bytes) => ((bytes[0] * 256) + bytes[1]) * 0.05,
  );

  static final driverDemandEnginePercentTorque = Pid(
    name: "Driver's Demand Engine — Percent Torque",
    mode: 0x01,
    pid: 0x61,
    unit: '%',
    decode: (bytes) => bytes[0] - 125,
  );

  static final actualEnginePercentTorque = Pid(
    name: 'Actual Engine — Percent Torque',
    mode: 0x01,
    pid: 0x62,
    unit: '%',
    decode: (bytes) => bytes[0] - 125,
  );

  static final engineReferenceTorque = Pid(
    name: 'Engine Reference Torque',
    mode: 0x01,
    pid: 0x63,
    unit: 'Nm',
    decode: (bytes) => (bytes[0] * 256) + bytes[1],
  );

  static final List<Pid> all = [
    engineLoad,
    coolantTemp,
    shortTermFuelTrimBank1,
    longTermFuelTrimBank1,
    shortTermFuelTrimBank2,
    longTermFuelTrimBank2,
    fuelPressure,
    intakeManifoldPressure,
    engineRpm,
    vehicleSpeed,
    timingAdvance,
    intakeAirTemp,
    mafRate,
    throttlePosition,
    runTimeSinceEngineStart,
    distanceWithMilOn,
    fuelRailPressureVacuum,
    fuelRailGaugePressure,
    commandedEgr,
    egrError,
    commandedEvapPurge,
    fuelLevel,
    warmUpsSinceCodesCleared,
    distanceSinceCodesCleared,
    barometricPressure,
    catalystTempBank1Sensor1,
    catalystTempBank2Sensor1,
    catalystTempBank1Sensor2,
    catalystTempBank2Sensor2,
    controlModuleVoltage,
    absoluteLoadValue,
    commandedEquivalenceRatio,
    relativeThrottlePosition,
    ambientAirTemp,
    throttlePositionB,
    throttlePositionC,
    acceleratorPedalPositionD,
    acceleratorPedalPositionE,
    acceleratorPedalPositionF,
    commandedThrottleActuator,
    timeRunWithMilOn,
    timeSinceCodesCleared,
    ethanolFuelPercent,
    absoluteEvapVaporPressure,
    fuelRailPressureAbsolute,
    relativeAcceleratorPedalPosition,
    hybridBatteryPackLife,
    engineOilTemp,
    fuelInjectionTiming,
    engineFuelRate,
    driverDemandEnginePercentTorque,
    actualEnginePercentTorque,
    engineReferenceTorque,
  ];
}
