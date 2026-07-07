import 'package:elm327_obd/elm327_obd.dart';
import 'package:flutter/material.dart';

/// A raw AT/OBD command terminal: type a command, see the raw response.
/// This is the low-level debugging fallback when the dashboard doesn't
/// behave as expected.
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({required this.client, super.key});

  final Elm327Client client;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _controller = TextEditingController();
  final _log = <String>[];

  Future<void> _send() async {
    final command = _controller.text.trim();
    if (command.isEmpty) return;
    _controller.clear();
    setState(() => _log.add('> $command'));
    try {
      final response = await widget.client.sendRawCommand(command);
      setState(() => _log.add(response.trim()));
    } catch (error) {
      setState(() => _log.add('ERROR: $error'));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _log.length,
            itemBuilder: (context, index) => Text(
              _log[index],
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'e.g. ATRV, 010C, 03',
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: _send),
            ],
          ),
        ),
      ],
    );
  }
}
