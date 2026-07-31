/// RaceBox Mini / Micro GNSS data logger client.
///
/// Built on `ble_core`, which it re-exports so a consumer needs one import.
/// The package owns only what is RaceBox-specific — the GATT profile, UBX
/// framing, and the data message — while scanning, permissions and connection
/// management stay shared with every other device family.
library;

export 'package:ble_core/ble_core.dart';

export 'src/racebox_client.dart';
export 'src/racebox_data.dart';
export 'src/racebox_profile.dart';
export 'src/ubx_frame.dart';
