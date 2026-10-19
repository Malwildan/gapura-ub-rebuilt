import 'dart:async';

enum DemoRole {
  guest('Pengunjung', null),
  student('Mahasiswa', '/mahasiswa'),
  parent('Orangtua', '/ortu'),
  staff('Tendik', '/tendik'),
  lecturer('Dosen', '/dosen');

  const DemoRole(this.label, this.originalRole);
  final String label;
  final String? originalRole;
  bool get employee => this == staff || this == lecturer;
  bool get academic => this == student || this == parent;
}

enum DemoScenario {
  populated('Berisi'),
  loading('Memuat'),
  empty('Kosong'),
  error('Gagal');

  const DemoScenario(this.label);
  final String label;
}

/// A deliberately synthetic, in-memory session. Never stored as a UB login.
class DemoSession {
  DemoSession({
    required this.role,
    required this.scenario,
    this.delay = const Duration(milliseconds: 180),
  });

  final DemoRole role;
  final DemoScenario scenario;
  final Duration delay;

  Future<void> read() async {
    if (scenario == DemoScenario.loading) return Completer<void>().future;
    if (delay != Duration.zero) await Future<void>.delayed(delay);
    if (scenario == DemoScenario.error) {
      throw StateError(
        'Simulasi gagal memuat data. Pilih mode Berisi untuk pulih.',
      );
    }
  }

  Map<String, dynamic> get profile => {
    'NAMA': 'Demo ${role.label}',
    'NIM': role.academic ? 'DEMO-MHS-001' : 'DEMO-${role.name.toUpperCase()}',
    'ANGKATAN': '2024',
    'STATUS': 'Aktif (sintetis)',
    'FAKULTAS': 'Fakultas Demo',
    'JURUSAN': 'Jurusan Demo',
    'JENJANG': 'S1',
    'PROGRAM': 'Program Studi Demo',
    'FILE_FOTO': '',
  };

  Map<String, dynamic> get identity => {
    'nim': profile['NIM'],
    'email': 'demo.${role.name}@example.invalid',
  };
}
