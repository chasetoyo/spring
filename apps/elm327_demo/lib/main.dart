import 'package:flutter/material.dart';

import 'device_picker_screen.dart';
import 'terminal_screen.dart';

void main() {
  runApp(const Elm327DemoApp());
}

class Elm327DemoApp extends StatelessWidget {
  const Elm327DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ELM327 Demo',
      home: DevicePickerScreen(
        onConnected: (client, transport) {
          // Task 14 replaces this with the dashboard+terminal home; for
          // now, jump straight to the terminal so the connection can be
          // verified end-to-end as soon as this task lands.
          Navigator.of(_navigatorKey.currentContext!).push(
            MaterialPageRoute(
              builder: (_) => TerminalScreen(client: client),
            ),
          );
        },
      ),
      navigatorKey: _navigatorKey,
    );
  }
}

final _navigatorKey = GlobalKey<NavigatorState>();
