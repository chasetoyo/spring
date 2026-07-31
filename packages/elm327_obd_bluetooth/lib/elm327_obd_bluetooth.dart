/// Bluetooth Low Energy (BLE) transport for the elm327_obd core library.
///
/// Scanning, permissions and connection management live in `ble_core`, which
/// this package re-exports so a consumer needs one import. No
/// `flutter_blue_plus` type is exported: swapping the BLE stack is a change
/// to one file in `ble_core`, not to every consumer that touched a scan.
library;

export 'package:ble_core/ble_core.dart';

export 'src/bluetooth_transport.dart';
