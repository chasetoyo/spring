/// A byte-in/byte-out channel to an ELM327 adapter.
///
/// Implementations only move bytes — they have no knowledge of AT
/// commands or OBD-II framing. Bluetooth Classic SPP, USB-serial, or an
/// in-memory fake for tests can all implement this.
abstract class Elm327Transport {
  /// Bytes received from the adapter, as they arrive.
  Stream<List<int>> get input;

  /// Sends raw bytes to the adapter.
  Future<void> write(List<int> bytes);
}
