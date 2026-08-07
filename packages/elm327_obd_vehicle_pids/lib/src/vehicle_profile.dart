import 'package:elm327_obd/elm327_obd.dart';

/// A make/model/year range paired with the [PidSet] of custom PIDs known
/// to work for it. ECU firmware (and sometimes the PID map itself) can
/// change between model years even within the "same" model, so profiles
/// are scoped to a year range rather than just a model name.
class VehicleProfile {
  const VehicleProfile({
    required this.make,
    required this.model,
    required this.yearStart,
    this.yearEnd,
    required this.pidSet,
  });

  final String make;
  final String model;

  /// The first model year this profile applies to.
  final int yearStart;

  /// The last model year this profile applies to, or `null` if it's
  /// still current (applies to [yearStart] and every year after).
  final int? yearEnd;

  final PidSet pidSet;

  /// Whether this profile applies to the given [make]/[model]/[year],
  /// matching make/model case-insensitively.
  bool matches({
    required String make,
    required String model,
    required int year,
  }) {
    return make.toLowerCase() == this.make.toLowerCase() &&
        model.toLowerCase() == this.model.toLowerCase() &&
        year >= yearStart &&
        (yearEnd == null || year <= yearEnd!);
  }
}

/// Returns the first profile in [profiles] matching [make]/[model]/[year],
/// or `null` if none do. Typical usage combines catalogs from more than
/// one make/model entry point, e.g.:
///
/// ```dart
/// import 'package:elm327_obd_vehicle_pids/subaru.dart';
/// import 'package:elm327_obd_vehicle_pids/toyota.dart';
///
/// final profile = findVehicleProfile(
///   [...subaruProfiles, ...toyotaProfiles],
///   make: 'Toyota',
///   model: 'GR86',
///   year: 2023,
/// );
/// ```
VehicleProfile? findVehicleProfile(
  List<VehicleProfile> profiles, {
  required String make,
  required String model,
  required int year,
}) {
  for (final profile in profiles) {
    if (profile.matches(make: make, model: model, year: year)) {
      return profile;
    }
  }
  return null;
}
