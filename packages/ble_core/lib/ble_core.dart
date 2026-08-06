/// Vendor-neutral BLE plumbing shared by every device family in this
/// workspace.
///
/// Nothing here re-exports a `flutter_blue_plus` type. That is the whole
/// point: consumers name [BleDevice] and [BleConnection], so replacing the
/// BLE stack means writing one new [BleBackend] rather than editing every
/// picker and controller that touched a scan result.
library;

export 'src/ble_backend.dart';
export 'src/ble_connection.dart';
export 'src/ble_device.dart';
export 'src/ble_device_client.dart';
export 'src/ble_exception.dart';
export 'src/ble_uuid.dart';
export 'src/device_information.dart';
export 'src/device_profile.dart';
export 'src/flutter_blue_plus_backend.dart';
