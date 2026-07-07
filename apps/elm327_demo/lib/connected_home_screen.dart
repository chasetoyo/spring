import 'package:elm327_obd/elm327_obd.dart';
import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'terminal_screen.dart';

/// The post-connection home: a tab bar switching between the live
/// [DashboardScreen] and the raw [TerminalScreen].
class ConnectedHomeScreen extends StatelessWidget {
  const ConnectedHomeScreen({required this.client, super.key});

  final Elm327Client client;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Connected — ${client.currentProtocol ?? '...'}'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Terminal'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DashboardScreen(client: client),
            TerminalScreen(client: client),
          ],
        ),
      ),
    );
  }
}
