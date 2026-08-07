import 'package:elm327_obd/elm327_obd.dart';
import 'package:elm327_obd_vehicle_pids/vehicle_profile.dart';
import 'package:flutter/material.dart';

/// One row's result from an All PIDs sweep: either a decoded value or an
/// error message, never both.
class _PidResult {
  _PidResult.value(this.name, this.unit, num value)
    : valueText = value.toString(),
      error = null;

  _PidResult.error(this.name, this.unit, Object error)
    : valueText = null,
      error = error.toString();

  final String name;
  final String unit;
  final String? valueText;
  final String? error;
}

/// Sequentially queries every [StandardPids] entry, plus [vehicleProfile]'s
/// custom PIDs if one was selected, and shows what came back — a value or
/// an error — for each. This is a verification sweep, not a live
/// dashboard: it doesn't distinguish "vehicle doesn't support this PID"
/// from other errors, since the point is just to see everything the
/// library can ask for and how the vehicle responds.
class AllPidsScreen extends StatefulWidget {
  const AllPidsScreen({required this.client, this.vehicleProfile, super.key});

  final Elm327Client client;
  final VehicleProfile? vehicleProfile;

  @override
  State<AllPidsScreen> createState() => _AllPidsScreenState();
}

class _AllPidsScreenState extends State<AllPidsScreen> {
  final List<_PidResult> _results = [];
  bool _running = false;

  Future<void> _runSweep() async {
    setState(() {
      _running = true;
      _results.clear();
    });

    for (final pid in StandardPids.all) {
      await _queryOne(
        name: pid.name,
        unit: pid.unit,
        query: () => widget.client.queryPid(pid),
      );
    }

    final customPids = widget.vehicleProfile?.pidSet.pids ?? const [];
    for (final pid in customPids) {
      await _queryOne(
        name: pid.name,
        unit: pid.unit,
        query: () => widget.client.queryCustomPid(pid),
      );
    }

    if (!mounted) return;
    setState(() => _running = false);
  }

  Future<void> _queryOne({
    required String name,
    required String unit,
    required Future<num> Function() query,
  }) async {
    try {
      final value = await query();
      if (!mounted) return;
      setState(() => _results.add(_PidResult.value(name, unit, value)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _results.add(_PidResult.error(name, unit, error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.vehicleProfile == null
                        ? 'Standard PIDs only (no vehicle selected)'
                        : '${widget.vehicleProfile!.make} '
                              '${widget.vehicleProfile!.model} — '
                              '${StandardPids.all.length} standard + '
                              '${widget.vehicleProfile!.pidSet.pids.length} '
                              'custom PIDs',
                  ),
                ),
                ElevatedButton(
                  onPressed: _running ? null : _runSweep,
                  child: Text(_running ? 'Running…' : 'Run sweep'),
                ),
              ],
            ),
          ),
          if (_running) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                final isError = result.error != null;
                return ListTile(
                  dense: true,
                  title: Text(result.name),
                  trailing: Text(
                    isError ? 'error' : '${result.valueText} ${result.unit}',
                    style: TextStyle(color: isError ? Colors.red : null),
                  ),
                  subtitle: isError ? Text(result.error!) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
