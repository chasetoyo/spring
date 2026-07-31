import 'dart:typed_data';

/// Where each field sits inside the 80-byte RaceBox Data Message payload.
///
/// ## Unverified
///
/// RaceBox publishes this layout, but gates the document behind an email
/// request form, and it could not be reached when this was written. These
/// offsets follow the message's evident derivation from u-blox `UBX-NAV-PVT`
/// — same field order, same scaling conventions — and they account for
/// exactly 80 bytes, which is a real constraint satisfied rather than a
/// coincidence. **They are still an inference.**
///
/// Everything else in this package — framing, checksums, reassembly, the
/// client lifecycle — is independent of these numbers and verified by tests.
/// If a real device produces nonsense, the fault is almost certainly in this
/// one table and nowhere else, which is why it is a table.
///
/// To confirm: capture one packet from a device and check that latitude and
/// longitude land where you are, and that speed reads zero at rest.
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

/// How good the GNSS fix is.
enum RaceBoxFixStatus {
  none,
  deadReckoning,
  fix2d,
  fix3d,
  gnssPlusDeadReckoning,
  timeOnly;

  static RaceBoxFixStatus fromCode(int code) {
    return switch (code) {
      1 => RaceBoxFixStatus.deadReckoning,
      2 => RaceBoxFixStatus.fix2d,
      3 => RaceBoxFixStatus.fix3d,
      4 => RaceBoxFixStatus.gnssPlusDeadReckoning,
      5 => RaceBoxFixStatus.timeOnly,
      _ => RaceBoxFixStatus.none,
    };
  }

  /// Whether a position from this fix is worth recording.
  ///
  /// Only 2D and 3D qualify. Dead reckoning without GNSS drifts, and
  /// time-only carries no position at all.
  bool get hasPosition =>
      this == RaceBoxFixStatus.fix2d ||
      this == RaceBoxFixStatus.fix3d ||
      this == RaceBoxFixStatus.gnssPlusDeadReckoning;
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
    required this.gForceX,
    required this.gForceY,
    required this.gForceZ,
    required this.rotationRateX,
    required this.rotationRateY,
    required this.rotationRateZ,
    required this.batteryPercent,
    required this.isCharging,
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
      gForceX: view.getInt16(RaceBoxDataOffsets.gForceX, Endian.little) / 1000,
      gForceY: view.getInt16(RaceBoxDataOffsets.gForceY, Endian.little) / 1000,
      gForceZ: view.getInt16(RaceBoxDataOffsets.gForceZ, Endian.little) / 1000,
      rotationRateX:
          view.getInt16(RaceBoxDataOffsets.rotationRateX, Endian.little) / 100,
      rotationRateY:
          view.getInt16(RaceBoxDataOffsets.rotationRateY, Endian.little) / 100,
      rotationRateZ:
          view.getInt16(RaceBoxDataOffsets.rotationRateZ, Endian.little) / 100,
      // Low seven bits are the level; the top bit says it is charging.
      batteryPercent: view.getUint8(RaceBoxDataOffsets.batteryStatus) & 0x7F,
      isCharging: (view.getUint8(RaceBoxDataOffsets.batteryStatus) & 0x80) != 0,
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

  /// Measured acceleration in g, from the device's own IMU rather than
  /// differentiated from position.
  final double gForceX;
  final double gForceY;
  final double gForceZ;

  /// Degrees per second about each axis.
  final double rotationRateX;
  final double rotationRateY;
  final double rotationRateZ;

  final int batteryPercent;
  final bool isCharging;

  double get speedMph => speedMps * 2.236936292;

  double get speedKph => speedMps * 3.6;

  static DateTime? _readTimestamp(ByteData view) {
    final int year = view.getUint16(RaceBoxDataOffsets.year, Endian.little);
    // Before a fix the date fields read as zeroes or an epoch default, and a
    // timestamp from those is worse than none.
    if (year < 2000 || year > 2200) return null;
    return DateTime.utc(
      year,
      view.getUint8(RaceBoxDataOffsets.month),
      view.getUint8(RaceBoxDataOffsets.day),
      view.getUint8(RaceBoxDataOffsets.hour),
      view.getUint8(RaceBoxDataOffsets.minute),
      view.getUint8(RaceBoxDataOffsets.second),
    );
  }

  @override
  String toString() =>
      'RaceBoxData(${fixStatus.name}, $latitude, $longitude, '
      '${speedMph.toStringAsFixed(1)} mph)';
}
