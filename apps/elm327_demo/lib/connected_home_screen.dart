import 'package:elm327_obd/elm327_obd.dart';
import 'package:elm327_obd_vehicle_pids/vehicle_profile.dart';
import 'package:flutter/material.dart';

import 'all_pids_screen.dart';
import 'dashboard_screen.dart';
import 'terminal_screen.dart';

/// The post-connection home: a tab bar switching between the live
/// [DashboardScreen], the exhaustive-verification [AllPidsScreen], and
/// the raw [TerminalScreen].
class ConnectedHomeScreen extends StatelessWidget {
  const ConnectedHomeScreen({
    required this.client,
    this.vehicleProfile,
    super.key,
  });

  final Elm327Client client;
  final VehicleProfile? vehicleProfile;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Connected — ${client.currentProtocol ?? '...'}'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'All PIDs'),
              Tab(text: 'Terminal'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DashboardScreen(client: client),
            AllPidsScreen(client: client, vehicleProfile: vehicleProfile),
            TerminalScreen(client: client),
          ],
        ),
      ),
    );
  }
}
