import 'dart:async';

enum GuestDemoScenario {
  populated('Berisi'),
  loading('Memuat'),
  empty('Kosong'),
  error('Gagal');

  const GuestDemoScenario(this.label);
  final String label;
}

/// Synthetic, memory-only public data with cancellable loading requests.
class GuestDemoSession {
  GuestDemoSession(this.scenario);

  final GuestDemoScenario scenario;
  final Set<Completer<void>> _pending = {};
  bool _closed = false;

  Future<void> read() async {
    if (_closed) throw StateError('Pratinjau tamu telah direset.');
    if (scenario == GuestDemoScenario.loading) {
      final pending = Completer<void>();
      _pending.add(pending);
      try {
        await pending.future;
      } finally {
        _pending.remove(pending);
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }
    if (_closed) throw StateError('Pratinjau tamu telah direset.');
    if (scenario == GuestDemoScenario.error) {
      throw StateError('Simulasi gagal memuat data. Pilih Berisi untuk pulih.');
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final pending in _pending) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('Pratinjau tamu telah direset.'));
      }
    }
    _pending.clear();
  }
}
