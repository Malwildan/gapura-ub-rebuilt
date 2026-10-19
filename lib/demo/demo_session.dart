import 'dart:async';

import '../model/records.dart';

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
    this.localAccount = false,
  });

  final DemoRole role;
  final DemoScenario scenario;
  final Duration delay;
  final bool localAccount;

  String presentText(String value) {
    if (!localAccount) return value;
    final replacements = <String, String>{
      'Demo Dosen': 'Dr. Raka Pradipta',
      'Demo Tendik': 'Nadia Kusumawardani',
      'Demo Orangtua': 'Budi Santoso',
      'Demo Mahasiswa': 'Alya Putri Santoso',
      'Mahasiswa Demo': 'Alya Putri Santoso',
      'Mata Kuliah Demo': 'Pengantar Sistem Informasi',
      'Berita Demo': 'Kabar Universitas',
      'Artikel sintetis untuk melihat tata letak.':
          'Universitas Brawijaya memperkuat kolaborasi riset dan pembelajaran digital.',
      'Contoh sintetis; tidak berasal dari Firebase UB.':
          'Agenda akademik semester berjalan.',
      'Materi pertemuan demo': 'Pemodelan proses bisnis',
      'Materi selesai demo': 'Analisis kebutuhan sistem',
      'Lampiran demo.pdf': 'Berita-acara-rapat.pdf',
      'Pertanyaan demo': 'Seberapa bermanfaat materi perkuliahan minggu ini?',
      'Pilihan demo': 'Sangat bermanfaat',
      'Survei Pegawai Demo': 'Survei layanan dan lingkungan kerja',
      'Mahasiswa Bimbingan Demo': 'Alya Putri Santoso',
      'Statistik Publikasi Demo': 'Statistik Publikasi',
      'Metrik Publikasi Demo': 'Metrik Publikasi',
      'Peringkat Peneliti Demo': 'Peringkat Peneliti',
      'Peringkat Afiliasi Demo': 'Peringkat Afiliasi',
      'Fakultas Demo': 'Fakultas Ilmu Komputer',
      'Jurusan Demo': 'Sistem Informasi',
      'Program Studi Demo': 'Sistem Informasi',
      'Unit Demo': 'Direktorat Akademik',
      'Kota Demo': 'Bandung',
      'Pengirim Demo': 'Sekretariat Fakultas Ilmu Komputer',
      'Peneliti Demo': 'Dr. Raka Pradipta',
      'Kegiatan Demo': 'Kegiatan Akademik',
      'Reguler Demo': 'Reguler Sistem Informasi',
      'Pendek Demo': 'Pendek Sistem Informasi',
      'Pengumuman Demo': 'Informasi Akademik',
      'Jawaban demo disimpan di memori.': 'Jawaban tersimpan pada sesi ini.',
      'Surat demo untuk diproses': 'Permohonan pemutakhiran data akademik',
      'Tugas harian demo': 'Pemeriksaan berkas akademik',
      'Siapkan materi demo': 'Menyiapkan bahan perkuliahan',
      'Agenda surat demo': 'Agenda layanan akademik',
      'Tugas Pendapa demo': 'Tugas tindak lanjut surat',
      'Tinjau surat demo': 'Tugas tindak lanjut surat',
      'Akun lokal demo': 'Raka Pradipta',
      '01 Januari 1990': role == DemoRole.staff
          ? '15 April 1987'
          : '12 Maret 1982',
      'Pangkat Demo / III-a': 'Penata / III-c',
      'Jabatan Demo': role == DemoRole.lecturer
          ? 'Lektor Kepala'
          : 'Analis Akademik',
      'S1 Demo': 'S1 Administrasi Pendidikan',
      'S2 Demo': 'S3 Sistem Informasi',
      '2 tahun (sintetis)': '12 tahun',
      '1 tahun (sintetis)': '8 tahun',
      'Rp 3.000.000 (sintetis)': 'Rp 12.450.000',
      'Rp 2.000.000 (sintetis)': 'Rp 7.500.000',
      'Rp 1.000.000 (sintetis)': 'Rp 4.950.000',
      'Rp 2.000.000': 'Rp 7.500.000',
      'Rp 100.000': 'Rp 150.000',
      'Rp 750.000': 'Rp 1.250.000',
      'Rp 250.000': 'Rp 450.000',
      'Rp 5.000.000': 'Rp 18.750.000',
      'Rp 50.000': 'Rp 250.000',
      'Rp 4.750.000': 'Rp 17.900.000',
      'Rp 500.000': 'Rp 1.000.000',
      'Nilai sintetis': 'Rp 7.500.000',
      'Contoh tampilan; bukan hak finansial':
          'Rincian remunerasi periode berjalan',
      'Profil Dosen': 'Profil Dosen',
      'Data demo': 'Data akademik',
      'DEMO - DATA SINTETIS': 'Contoh dokumen lokal',
      'DEMO-DOSEN-001': 'PGW-19820312-014',
      'DEMO-NIK-000': '3273011203820014',
      'DEMO-NPWP': '12.345.678.9-012.000',
      'DEMO-KARPEG-001': 'KP-1982-0314',
      'DEMO-MHS-001': 'MHS-2024-0187',
      'DEMO-SINTA-001': '9999999',
      'DEMO-NIDN-001': '0003128201',
      'DEMO-UB': '001001',
      'UKT Demo': 'UKT Semester Ganjil',
      'Debit demo': 'Pembayaran melalui virtual account',
      'Gedung Demo': 'Gedung F',
      'D-01': 'F-204',
      'Materi sintetis': 'Pemodelan proses bisnis',
      'Topik sintetis': 'Analisis kebutuhan sistem',
      'Catatan sintetis': 'Pembahasan materi dan studi kasus',
      'Catatan demonstrasi lokal': 'Persiapan bahan perkuliahan',
      'Catatan demo': 'Pembahasan pertemuan dan tugas',
      'Isi surat sepenuhnya sintetis untuk pratinjau.':
          'Permohonan pembaruan data layanan akademik untuk semester berjalan.',
      'Konten sintetis': 'Permohonan pembaruan data layanan akademik',
      'Agenda sintetis': 'Peninjauan dokumen layanan akademik',
      'Tugas surat sintetis': 'Verifikasi kelengkapan dokumen akademik',
      'Pratinjau lokal': 'Hadir',
      'Belum direkam': 'Hadir',
      'Demo': 'Contoh',
      'sintetis': 'contoh',
      'DEMO': 'lokal',
      ' (demo)': '',
      'Sintetis': 'Contoh',
    };
    var result = value;
    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result
        .replaceAll(' demo', '')
        .replaceAll(' Demo', '')
        .replaceAll('demo', 'lokal');
  }

  Record presentRecord(Record record) {
    if (!localAccount) return record;
    const technicalKeys = {
      'id',
      'parent_id',
      'document_id',
      'class_id',
      'calendar_id',
      'K_MK',
      'K_MATERI_AJAR',
      'id_survey',
      'id_komponen_survey',
      'notugas',
      'idjenissurat',
      'idtujuan',
    };
    dynamic present(String key, dynamic value) {
      if (value is Map) {
        return value.map((k, v) => MapEntry(k, present(k.toString(), v)));
      }
      if (value is List) return value.map((v) => present(key, v)).toList();
      if (value is String &&
          !technicalKeys.contains(key) &&
          !key.startsWith('K_') &&
          !(key == 'value' && value.startsWith('DEMO-'))) {
        return presentText(value);
      }
      return value;
    }

    return Map<String, dynamic>.from(
      record.map((key, value) => MapEntry(key, present(key, value))),
    );
  }

  List<Record> presentRows(List<Record> rows) =>
      localAccount ? rows.map(presentRecord).toList() : rows;

  Future<void> read() async {
    if (scenario == DemoScenario.loading) return Completer<void>().future;
    if (delay != Duration.zero) await Future<void>.delayed(delay);
    if (scenario == DemoScenario.error) {
      throw StateError(
        'Simulasi gagal memuat data. Pilih mode Berisi untuk pulih.',
      );
    }
  }

  Map<String, dynamic> get profile => localAccount
      ? _localProfile
      : {
          'NAMA': 'Demo ${role.label}',
          'NIM': role.academic
              ? 'DEMO-MHS-001'
              : 'DEMO-${role.name.toUpperCase()}',
          'ANGKATAN': '2024',
          'STATUS': 'Aktif (sintetis)',
          'FAKULTAS': 'Fakultas Demo',
          'JURUSAN': 'Jurusan Demo',
          'JENJANG': 'S1',
          'PROGRAM': 'Program Studi Demo',
          'FILE_FOTO': '',
        };

  Map<String, dynamic> get _localProfile => switch (role) {
    DemoRole.parent => {
      'NAMA': 'Budi Santoso',
      'NIM': 'MHS-2024-0187',
      'ANGKATAN': '2024',
      'STATUS': 'Aktif',
      'FAKULTAS': 'Fakultas Ilmu Komputer',
      'JURUSAN': 'Sistem Informasi',
      'JENJANG': 'S1',
      'PROGRAM': 'Sistem Informasi',
      'FILE_FOTO': '',
      'NAMA_ANAK': 'Alya Putri Santoso',
      'NIM_ANAK': 'MHS-2024-0187',
      'FAKULTAS_ANAK': 'Fakultas Ilmu Komputer',
      'PROGRAM_ANAK': 'Sistem Informasi',
      'ANGKATAN_ANAK': '2024',
    },
    DemoRole.student => {
      'NAMA': 'Alya Putri Santoso',
      'NIM': 'MHS-2024-0187',
      'ANGKATAN': '2024',
      'STATUS': 'Aktif',
      'FAKULTAS': 'Fakultas Ilmu Komputer',
      'JURUSAN': 'Sistem Informasi',
      'JENJANG': 'S1',
      'PROGRAM': 'Sistem Informasi',
      'FILE_FOTO': '',
    },
    DemoRole.staff => {
      'NAMA': 'Nadia Kusumawardani',
      'NIM': 'PGW-19870415-026',
      'ANGKATAN': '2012',
      'STATUS': 'Aktif',
      'FAKULTAS': 'Direktorat Akademik',
      'JURUSAN': 'Layanan Akademik',
      'JENJANG': 'S1',
      'PROGRAM': 'Administrasi Pendidikan',
      'FILE_FOTO': '',
    },
    DemoRole.lecturer => {
      'NAMA': 'Dr. Raka Pradipta',
      'NIM': 'PGW-19820312-014',
      'ANGKATAN': '2008',
      'STATUS': 'Aktif',
      'FAKULTAS': 'Fakultas Ilmu Komputer',
      'JURUSAN': 'Sistem Informasi',
      'JENJANG': 'S3',
      'PROGRAM': 'Sistem Informasi',
      'FILE_FOTO': '',
    },
    DemoRole.guest => {
      'NAMA': 'Pengunjung',
      'NIM': '',
      'ANGKATAN': '',
      'STATUS': 'Umum',
      'FAKULTAS': 'Universitas',
      'JURUSAN': '',
      'JENJANG': '',
      'PROGRAM': '',
      'FILE_FOTO': '',
    },
  };

  Map<String, dynamic> get identity => {
    'nim': profile['NIM'],
    'email': localAccount
        ? '${role.name}@example.com'
        : 'demo.${role.name}@example.invalid',
  };
}
