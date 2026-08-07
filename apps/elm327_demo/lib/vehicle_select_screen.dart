import 'package:elm327_obd_vehicle_pids/subaru.dart';
import 'package:elm327_obd_vehicle_pids/toyota.dart';
import 'package:elm327_obd_vehicle_pids/vehicle_profile.dart';
import 'package:flutter/material.dart';

/// Lets the user pick which vehicle profile to use (unlocking its
/// manufacturer-specific custom PIDs on the "All PIDs" screen), or skip
/// straight to standard-PIDs-only. Only lists the profiles currently
/// implemented in `elm327_obd_vehicle_pids` (Gen 2 GR86/BRZ) — see that
/// package's README for how to add more.
class VehicleSelectScreen extends StatelessWidget {
  const VehicleSelectScreen({required this.onSelected, super.key});

  final void Function(VehicleProfile? profile) onSelected;

  static final List<VehicleProfile> _profiles = [
    ...toyotaProfiles,
    ...subaruProfiles,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select your vehicle')),
      body: ListView(
        children: [
          for (final profile in _profiles)
            ListTile(
              title: Text('${profile.make} ${profile.model}'),
              subtitle: Text(
                profile.yearEnd == null
                    ? '${profile.yearStart}+'
                    : '${profile.yearStart}–${profile.yearEnd}',
              ),
              onTap: () => onSelected(profile),
            ),
          ListTile(
            title: const Text('Skip — standard PIDs only'),
            subtitle: const Text(
              'No manufacturer-specific PIDs on the All PIDs screen',
            ),
            onTap: () => onSelected(null),
          ),
        ],
      ),
    );
  }
}
