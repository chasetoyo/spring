import 'dart:async';

import 'package:elm327_obd/elm327_obd.dart';
import 'package:flutter/material.dart';

/// Polls a handful of core PIDs on a timer and shows current DTCs, with
/// a confirm-before-clear button (Mode 04 also wipes freeze frame and
/// O2 test data, not just the check-engine light).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({required this.client, super.key});

  final Elm327Client client;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _pollInterval = Duration(seconds: 1);
  static final _polledPids = [
    StandardPids.engineRpm,
    StandardPids.vehicleSpeed,
    StandardPids.coolantTemp,
    StandardPids.throttlePosition,
  ];

  Timer? _pollTimer;
  final Map<String, num> _values = {};
  List<String> _dtcs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOnce());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollOnce() async {
    for (final pid in _polledPids) {
      try {
        final value = await widget.client.queryPid(pid);
        if (!mounted) return;
        setState(() {
          _values[pid.name] = value;
          _error = null;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() => _error = 'Error reading ${pid.name}: $error');
      }
    }
  }

  Future<void> _readDtcs() async {
    try {
      final codes = await widget.client.readDtcs();
      if (!mounted) return;
      setState(() => _dtcs = codes);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Error reading DTCs: $error');
    }
  }

  Future<void> _confirmAndClearDtcs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear trouble codes?'),
        content: const Text(
          'This clears all current, pending, and freeze-frame data — '
          'not just the check-engine light. The vehicle may run poorly '
          'for a short time afterward while it recalibrates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client.clearDtcs();
      if (!mounted) return;
      setState(() => _dtcs = []);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Error clearing DTCs: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        for (final pid in _polledPids)
          Card(
            child: ListTile(
              title: Text(pid.name),
              trailing: Text(
                _values.containsKey(pid.name)
                    ? '${_values[pid.name]} ${pid.unit}'
                    : '--',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _readDtcs,
                child: const Text('Read DTCs'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _confirmAndClearDtcs,
                child: const Text('Clear DTCs'),
              ),
            ),
          ],
        ),
        for (final code in _dtcs)
          ListTile(leading: const Icon(Icons.warning), title: Text(code)),
      ],
    );
  }
}
