/// Honda/Acura enhanced (Mode 22) PIDs, for the 2013 Acura TSX.
///
/// **Read this before trusting a number these produce.**
///
/// Honda does not publish its enhanced PID map. Everything here is Mode 22
/// against the ECM at header `7E0`, which is the right shape for the family —
/// but only the first two PIDs came from a source outside this file
/// (`16 00` and `16 02`, reported as the cylinder 1 and 2 misfire counters).
/// The rest continue that pattern by arithmetic: two bytes per counter,
/// stepping the PID by two per cylinder. **That extrapolation is unverified.**
///
/// Confirming it takes about a minute with the demo app's Terminal tab:
///
/// ```
/// ATSH7E0        → OK
/// 221600         → 62 16 00 xx xx      (a counter, echoing the PID back)
///                → NO DATA / 7F 22 31  (this PID is not supported)
/// ```
///
/// A `62 16 00` prefix means the ECM understood; anything else means the PID
/// is wrong and the extrapolation should be corrected here rather than worked
/// around at the call site.
///
/// Getting it wrong is safe but useless: an unsupported PID answers `NO DATA`,
/// [PidPoller] retires the channel after a few consecutive failures, and the
/// screen shows nothing for that cylinder. Nothing is written to the ECU —
/// Mode 22 is a read.
///
/// A note on what "misfire count" means on a Honda: these are the rolling
/// counters the ECM keeps per cylinder, not the SAE Mode 06 misfire test
/// results. They move while the engine runs and reset with the monitors, so
/// they are useful for *watching* a misfire develop on a drive — which is what
/// the demo app does with them — and are not a substitute for reading DTCs.
///
/// Every counter below shares the same shape, and the reasons are the same for
/// all of them:
///
/// * **Two bytes, unsigned.** A counter that rolls past 255 on a bad plug is
///   ordinary, and reading two bytes as one turns 256 into 1.
/// * **No scaling.** A count is a count; a scale factor here would invent
///   precision the ECM never reported.
/// * **Polled twice a second at most.** A misfire counter that moves at all is
///   already telling you what you need, and an ELM327 answers one command at a
///   time — six cylinders at 10 Hz would starve everything else in the
///   rotation.
library;

import 'package:elm327_obd/elm327_obd.dart';

/// Cylinder misfire counters for the 2.4 L K24 four.
///
/// The base TSX and every Sport Wagon. Cylinders are numbered as Honda numbers
/// them, 1 at the timing-belt end.
const List<PidDefinition> acuraTsx2013MisfireI4 = <PidDefinition>[
  PidDefinition(
    name: 'Misfire Cylinder 1',
    unit: 'count',
    mode: 0x22,
    pidBytes: <int>[0x16, 0x00],
    byteCount: 2,
    header: '7E0',
    minInterval: Duration(milliseconds: 500),
  ),
  PidDefinition(
    name: 'Misfire Cylinder 2',
    unit: 'count',
    mode: 0x22,
    pidBytes: <int>[0x16, 0x02],
    byteCount: 2,
    header: '7E0',
    minInterval: Duration(milliseconds: 500),
  ),
  PidDefinition(
    name: 'Misfire Cylinder 3',
    unit: 'count',
    mode: 0x22,
    pidBytes: <int>[0x16, 0x04],
    byteCount: 2,
    header: '7E0',
    minInterval: Duration(milliseconds: 500),
  ),
  PidDefinition(
    name: 'Misfire Cylinder 4',
    unit: 'count',
    mode: 0x22,
    pidBytes: <int>[0x16, 0x06],
    byteCount: 2,
    header: '7E0',
    minInterval: Duration(milliseconds: 500),
  ),
];

/// The same for the 3.5 L J35 six, which the TSX V6 sedan carries.
///
/// Two more counters on the same stride. If the four-cylinder map above turns
/// out to be wrong, this is wrong in the same way and by the same amount.
const List<PidDefinition> acuraTsx2013MisfireV6 = <PidDefinition>[
  ...acuraTsx2013MisfireI4,
  PidDefinition(
    name: 'Misfire Cylinder 5',
    unit: 'count',
    mode: 0x22,
    pidBytes: <int>[0x16, 0x08],
    byteCount: 2,
    header: '7E0',
    minInterval: Duration(milliseconds: 500),
  ),
  PidDefinition(
    name: 'Misfire Cylinder 6',
    unit: 'count',
    mode: 0x22,
    pidBytes: <int>[0x16, 0x0A],
    byteCount: 2,
    header: '7E0',
    minInterval: Duration(milliseconds: 500),
  ),
];

/// The four-cylinder counters in the form [Elm327Client.queryCustomPid] takes.
final PidSet acuraTsx2013MisfirePids =
    PidSet('Acura TSX 2013 misfire', <CustomPid>[
      for (final PidDefinition definition in acuraTsx2013MisfireI4)
        definition.toCustomPid(),
    ]);
