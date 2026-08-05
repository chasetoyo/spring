import 'dart:typed_data';

/// Where each field sits inside the 80-byte RaceBox Data Message payload.
///
/// Checked field by field against *RaceBox BLE Protocol Documentation,
/// Revision 8*, and exercised end to end by the golden test built from that
/// document's own captured packet — so a mistake here fails a test rather
/// than producing plausible nonsense on a track day.
///
/// The message is u-blox `UBX-NAV-PVT` with fields removed and others added,
/// which is why the ordering and scaling conventions look familiar.
abstract final class RaceBoxDataOffsets {
  /// Total payload length. A packet of any other size is not this message.
  static const int payloadLength = 80;

  static const int iTow = 0; // U4, ms since GPS week start
  static const int year = 4; // U2
  static const int month = 6; // U1
  static const int day = 7; // U1
  static const int hour = 8; // U1
  static const int minute = 9; // U1
  static const int second = 10; // U1
  static const int validityFlags = 11; // U1 bitfield
  static const int timeAccuracy = 12; // U4, ns
  static const int nanoseconds = 16; // I4
  static const int fixStatus = 20; // U1
  static const int fixStatusFlags = 21; // U1 bitfield
  static const int dateTimeFlags = 22; // U1 bitfield
  static const int numberOfSvs = 23; // U1
  static const int longitude = 24; // I4, 1e-7 degrees
  static const int latitude = 28; // I4, 1e-7 degrees
  static const int wgsAltitude = 32; // I4, mm above the ellipsoid
  static const int mslAltitude = 36; // I4, mm above mean sea level
  static const int horizontalAccuracy = 40; // U4, mm
  static const int verticalAccuracy = 44; // U4, mm
  static const int speed = 48; // I4, mm/s
  static const int heading = 52; // I4, 1e-5 degrees
  static const int speedAccuracy = 56; // U4, mm/s
  static const int headingAccuracy = 60; // U4, 1e-5 degrees
  static const int pdop = 64; // U2, 0.01
  static const int latLonFlags = 66; // U1 bitfield
  static const int batteryStatus = 67; // U1: charging bit + level
  static const int gForceX = 68; // I2, milli-g
  static const int gForceY = 70; // I2
  static const int gForceZ = 72; // I2
  static const int rotationRateX = 74; // I2, centi-degrees/s
  static const int rotationRateY = 76; // I2
  static const int rotationRateZ = 78; // I2
}

/// The location solution status.
///
/// Only three values are documented — u-blox defines more, but RaceBox's
/// firmware reports these — so anything else maps to [unknown] rather than
/// being silently read as "no fix".
enum RaceBoxFixStatus {
  none,
  fix2d,
  fix3d,
  unknown;

  static RaceBoxFixStatus fromCode(int code) {
    return switch (code) {
      0 => RaceBoxFixStatus.none,
      2 => RaceBoxFixStatus.fix2d,
      3 => RaceBoxFixStatus.fix3d,
      _ => RaceBoxFixStatus.unknown,
    };
  }
}

/// Bit positions inside the flag bytes.
abstract final class RaceBoxFlags {
  /// Fix Status Flags bit 0 — the receiver considers the fix good.
  static const int fixOk = 0x01;

  /// Lat/Lon Flags bit 0 — **set means the coordinates are invalid.**
  ///
  /// Inverted relative to every other flag here, which is exactly the kind of
  /// thing that gets read backwards.
  static const int coordinatesInvalid = 0x01;

  /// Validity Flags bits 0–2.
  static const int validDate = 0x01;
  static const int validTime = 0x02;
  static const int fullyResolved = 0x04;
}

/// One reading from a RaceBox, in SI-ish units rather than wire units.
///
/// Everything is converted at the boundary — millimetres to metres, 1e-7
/// degrees to degrees — so nothing downstream has to remember a scale factor.
class RaceBoxData {
  const RaceBoxData({
    required this.iTowMs,
    required this.timestampUtc,
    required this.fixStatus,
    required this.fixStatusFlags,
    required this.validityFlags,
    required this.latLonFlags,
    required this.satellites,
    required this.latitude,
    required this.longitude,
    required this.wgsAltitudeM,
    required this.mslAltitudeM,
    required this.horizontalAccuracyM,
    required this.verticalAccuracyM,
    required this.speedMps,
    required this.headingDegrees,
    required this.speedAccuracyMps,
    required this.headingAccuracyDegrees,
    required this.pdop,
    required this.gForceX,
    required this.gForceY,
    required this.gForceZ,
    required this.rotationRateX,
    required this.rotationRateY,
    required this.rotationRateZ,
    required this.batteryByte,
  });

  /// Decodes a RaceBox Data Message payload, or returns null when [payload]
  /// is not one.
  ///
  /// Null rather than throwing: a short or unexpected payload is a device or
  /// firmware difference, not a programming error, and a 25 Hz stream is the
  /// wrong place to raise exceptions.
  static RaceBoxData? decode(Uint8List payload) {
    if (payload.length < RaceBoxDataOffsets.payloadLength) return null;

    final ByteData view = ByteData.sublistView(payload);

    return RaceBoxData(
      iTowMs: view.getUint32(RaceBoxDataOffsets.iTow, Endian.little),
      timestampUtc: _readTimestamp(view),
      fixStatus: RaceBoxFixStatus.fromCode(
        view.getUint8(RaceBoxDataOffsets.fixStatus),
      ),
      fixStatusFlags: view.getUint8(RaceBoxDataOffsets.fixStatusFlags),
      validityFlags: view.getUint8(RaceBoxDataOffsets.validityFlags),
      latLonFlags: view.getUint8(RaceBoxDataOffsets.latLonFlags),
      satellites: view.getUint8(RaceBoxDataOffsets.numberOfSvs),
      latitude:
          view.getInt32(RaceBoxDataOffsets.latitude, Endian.little) * 1e-7,
      longitude:
          view.getInt32(RaceBoxDataOffsets.longitude, Endian.little) * 1e-7,
      wgsAltitudeM:
          view.getInt32(RaceBoxDataOffsets.wgsAltitude, Endian.little) / 1000,
      mslAltitudeM:
          view.getInt32(RaceBoxDataOffsets.mslAltitude, Endian.little) / 1000,
      horizontalAccuracyM:
          view.getUint32(RaceBoxDataOffsets.horizontalAccuracy, Endian.little) /
          1000,
      verticalAccuracyM:
          view.getUint32(RaceBoxDataOffsets.verticalAccuracy, Endian.little) /
          1000,
      speedMps: view.getInt32(RaceBoxDataOffsets.speed, Endian.little) / 1000,
      headingDegrees:
          view.getInt32(RaceBoxDataOffsets.heading, Endian.little) * 1e-5,
      speedAccuracyMps:
          view.getUint32(RaceBoxDataOffsets.speedAccuracy, Endian.little) /
          1000,
      headingAccuracyDegrees:
          view.getUint32(RaceBoxDataOffsets.headingAccuracy, Endian.little) *
          1e-5,
      pdop: view.getUint16(RaceBoxDataOffsets.pdop, Endian.little) / 100,
      gForceX: view.getInt16(RaceBoxDataOffsets.gForceX, Endian.little) / 1000,
      gForceY: view.getInt16(RaceBoxDataOffsets.gForceY, Endian.little) / 1000,
      gForceZ: view.getInt16(RaceBoxDataOffsets.gForceZ, Endian.little) / 1000,
      rotationRateX:
          view.getInt16(RaceBoxDataOffsets.rotationRateX, Endian.little) / 100,
      rotationRateY:
          view.getInt16(RaceBoxDataOffsets.rotationRateY, Endian.little) / 100,
      rotationRateZ:
          view.getInt16(RaceBoxDataOffsets.rotationRateZ, Endian.little) / 100,
      batteryByte: view.getUint8(RaceBoxDataOffsets.batteryStatus),
    );
  }

  /// GPS time of week, in milliseconds.
  ///
  /// The device's own clock rather than the phone's, and the right thing to
  /// align samples on when merging with anything else.
  final int iTowMs;

  /// Wall-clock time from the device, or null when the date fields are not
  /// yet valid — which they are not until the receiver has a fix.
  final DateTime? timestampUtc;

  final RaceBoxFixStatus fixStatus;

  /// Raw Fix Status Flags. [hasValidFix] is the reading that matters.
  final int fixStatusFlags;

  /// Raw Validity Flags — date, time and fully-resolved bits.
  final int validityFlags;

  /// Raw Lat/Lon Flags. Bit 0 **set** means the coordinates are invalid.
  final int latLonFlags;

  final int satellites;

  final double latitude;
  final double longitude;

  /// Height above the WGS84 ellipsoid. Not the same datum as [mslAltitudeM],
  /// and the two can differ by tens of metres.
  final double wgsAltitudeM;

  /// Height above mean sea level — the figure that matches a map.
  final double mslAltitudeM;

  final double horizontalAccuracyM;
  final double verticalAccuracyM;

  final double speedMps;
  final double headingDegrees;
  final double speedAccuracyMps;
  final double headingAccuracyDegrees;

  /// Position dilution of precision. Lower is better; usually tracks the
  /// satellite count.
  final double pdop;

  /// Measured acceleration in g, from the device's own IMU rather than
  /// differentiated from position.
  final double gForceX;
  final double gForceY;
  final double gForceZ;

  /// Degrees per second about each axis.
  final double rotationRateX;
  final double rotationRateY;
  final double rotationRateZ;

  /// The raw battery byte, because it means two different things.
  ///
  /// On a Mini or Mini S it is a charging bit plus a percentage; on a Micro,
  /// which has no battery, it is the input voltage times ten. Decoding it
  /// here would require knowing the model, which a data packet does not carry
  /// — so the raw byte is exposed and [batteryPercent], [isCharging] and
  /// [inputVoltage] each interpret it one way.
  final int batteryByte;

  /// Battery level 0–100, on a Mini or Mini S.
  int get batteryPercent => batteryByte & 0x7F;

  /// Whether the device is charging, on a Mini or Mini S.
  bool get isCharging => (batteryByte & 0x80) != 0;

  /// Supply voltage, on a Micro. `0x79` is 12.1 V.
  double get inputVoltage => batteryByte / 10;

  /// Whether the receiver reports a good location solution.
  ///
  /// The spec's own recommendation, and stricter than reading [fixStatus]
  /// alone: a 3D fix **and** the fix-OK bit. A 2D fix has no usable altitude
  /// and is not what a lap timer should trust.
  bool get hasValidFix =>
      fixStatus == RaceBoxFixStatus.fix3d &&
      (fixStatusFlags & RaceBoxFlags.fixOk) != 0;

  /// Whether the coordinates in this packet may be used.
  ///
  /// Separate from [hasValidFix] because the receiver can invalidate the
  /// coordinates on their own flag while still claiming a fix.
  bool get hasValidPosition =>
      hasValidFix && (latLonFlags & RaceBoxFlags.coordinatesInvalid) == 0;

  double get speedMph => speedMps * 2.236936292;

  double get speedKph => speedMps * 3.6;

  static DateTime? _readTimestamp(ByteData view) {
    final int year = view.getUint16(RaceBoxDataOffsets.year, Endian.little);
    // Before a fix the date fields read as zeroes or an epoch default, and a
    // timestamp from those is worse than none.
    if (year < 2000 || year > 2200) return null;

    final DateTime whole = DateTime.utc(
      year,
      view.getUint8(RaceBoxDataOffsets.month),
      view.getUint8(RaceBoxDataOffsets.day),
      view.getUint8(RaceBoxDataOffsets.hour),
      view.getUint8(RaceBoxDataOffsets.minute),
      view.getUint8(RaceBoxDataOffsets.second),
    );

    // **The second fields alone are not a timestamp for a 25 Hz stream.** They
    // name the second the fix belongs to; `nano` says where inside it, and
    // without that every packet in a second decodes to the same instant. A
    // consumer timing laps then cannot tell twenty-five distinct positions
    // apart, and one that rejects non-advancing timestamps as duplicates
    // throws twenty-four of them away.
    //
    // Signed, and genuinely negative in practice: the receiver rounds the
    // second to nearest, so a fix just before a tick is reported as the next
    // second minus a fraction.
    final int nanos = view.getInt32(
      RaceBoxDataOffsets.nanoseconds,
      Endian.little,
    );
    // Documented range is ±1e9. Anything outside it is an unresolved clock
    // rather than a fraction, and shifting the whole second by it would be
    // worse than ignoring it.
    if (nanos <= -1000000000 || nanos >= 1000000000) return whole;

    return whole.add(Duration(microseconds: (nanos / 1000).round()));
  }

  @override
  String toString() =>
      'RaceBoxData(${fixStatus.name}, $latitude, $longitude, '
      '${speedMph.toStringAsFixed(1)} mph)';
}
