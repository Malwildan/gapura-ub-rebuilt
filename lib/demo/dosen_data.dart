import 'dart:convert';

import '../model/records.dart';
import 'demo_session.dart';

/// Synthetic, session-scoped lecturer data. All writes remain in this instance.
/// Field names in uppercase mirror recovered model keys; lower-case display
/// aliases are local conveniences and do not claim to be API response keys.
class DosenDemoData {
  DosenDemoData(this.session) : _rows = _fixtures();

  final DemoSession session;
  final Map<String, List<Record>> _rows;
  int _nextId = 1;

  static const resources = <String>{
    'profile',
    'employee',
    'sister',
    'personnel_history',
    'survey',
    'survey_components',
    'attendance',
    'tasks',
    'attendance_history',
    'remuneration_profile',
    'tgp',
    'incentives',
    'additional_incentives',
    'remun13',
    'deductions',
    'remuneration_activities',
    'income',
    'tax_documents',
    'bonuses',
    'schedule',
    'teaching_drafts',
    'teaching_active',
    'teaching_history',
    'student_attendance',
    'attendance_recap',
    'class_announcements',
    'calendars',
    'advisees',
    'publication_overview',
    'publication_output',
    'publication_people',
    'publication_affiliations',
    'pendapa_calendar',
    'pendapa_tasks',
    'pendapa_incoming',
    'pendapa_paraf',
    'pendapa_tte',
    'pendapa_incoming_history',
    'pendapa_paraf_history',
    'pendapa_tte_history',
    'pendapa_archive',
    'document_detail',
    'document_timeline',
    'document_attachments',
  };

  Future<List<Record>> read(
    String resource, {
    Record? item,
    int? year,
    int? month,
    String? category,
  }) async {
    _requireResource(resource);
    _requireLecturer();
    if (month != null && (month < 1 || month > 12)) {
      throw const FormatException('Bulan tidak valid.');
    }
    await session.read();
    if (session.scenario == DemoScenario.empty) return [];
    var rows = _rows[resource]!;
    if (item != null) {
      final parent = (item['document_id'] ?? item['id'])?.toString();
      rows = rows
          .where(
            (r) =>
                (r['parent_id'] ?? r['class_id'] ?? r['document_id'])
                        ?.toString() ==
                    parent ||
                r['id']?.toString() == parent,
          )
          .toList();
    }
    if (category != null) {
      rows = rows
          .where(
            (r) =>
                r['category']?.toString() == category ||
                r['KATEGORI']?.toString() == category,
          )
          .toList();
    }
    if (year != null) {
      rows = rows.where((r) => _matchesPeriod(r, year: year)).toList();
    }
    if (month != null) {
      rows = rows.where((r) => _matchesPeriod(r, month: month)).toList();
    }
    return _copyRows(rows);
  }

  Future<Record> save(String resource, Record value) async {
    _requireResource(resource);
    _requireLecturer();
    await session.read();
    final row = _copy(value);
    final id = row['id']?.toString();
    final rows = _rows[resource]!;
    final index = id == null
        ? -1
        : rows.indexWhere((r) => r['id']?.toString() == id);
    if (index < 0) {
      row['id'] = 'DEMO-$resource-${_nextId++}';
      row.putIfAbsent(
        'title',
        () => 'Data demo ${resource.replaceAll('_', ' ')}',
      );
      rows.add(row);
    } else {
      row.putIfAbsent('title', () => rows[index]['title'] ?? 'Data demo');
      rows[index] = row;
    }
    return _copy(row);
  }

  Future<void> remove(String resource, String id) async {
    _requireResource(resource);
    _requireLecturer();
    await session.read();
    _rows[resource]!.removeWhere((r) => r['id']?.toString() == id);
    // Keep linked fixture state coherent for local document processing.
    if (resource.startsWith('pendapa_') || resource == 'document_detail') {
      for (final rows in _rows.values) {
        rows.removeWhere((r) => r['document_id']?.toString() == id);
      }
    }
  }

  void _requireResource(String resource) {
    if (!resources.contains(resource)) {
      throw ArgumentError.value(resource, 'resource', 'Unknown demo resource');
    }
  }

  void _requireLecturer() {
    if (session.role != DemoRole.lecturer) {
      throw UnsupportedError('Data Dosen hanya tersedia pada peran Dosen.');
    }
  }

  static Record _copy(Record r) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(r)) as Map);
  static List<Record> _copyRows(Iterable<Record> rows) =>
      rows.map(_copy).toList();

  static bool _matchesPeriod(Record row, {int? year, int? month}) {
    final yearValues = <int>[];
    final monthValues = <int>[];
    for (final key in const ['year', 'TAHUN', 'THN_MK', 'PERIODE']) {
      final parsed = int.tryParse(row[key]?.toString() ?? '');
      if (parsed != null) yearValues.add(parsed);
    }
    for (final key in const ['month', 'BULAN']) {
      final parsed = int.tryParse(row[key]?.toString() ?? '');
      if (parsed != null) monthValues.add(parsed);
    }
    for (final key in const [
      'TANGGAL',
      'TGL_ABSENSI',
      'TGL_SURAT',
      'tglsurat',
      'tanggal',
      'tanggal_mulai',
      'tanggal_selesai',
      'TGL_MULAI',
      'TGL_AKHIR',
      'TANGGAL_MULAI',
      'TANGGAL_SELESAI',
      'date',
      'created_at',
      'updated_at',
    ]) {
      final raw = row[key]?.toString();
      if (raw == null) continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        yearValues.add(parsed.year);
        monthValues.add(parsed.month);
      }
    }
    final yearMatches = year == null || yearValues.contains(year);
    final monthMatches = month == null || monthValues.contains(month);
    return yearMatches && monthMatches;
  }

  static Map<String, List<Record>> _fixtures() {
    Record row(
      String id,
      String title,
      Map<String, dynamic> fields, {
      String? parent,
    }) => {
      'id': id,
      'title': title,
      ...fields,
      ...?parent == null ? null : {'parent_id': parent},
    };
    const classId = 'DEMO-CLASS-01';
    const docId = 'DEMO-DOC-01';
    final profile = {
      'pegawai': 'Demo Dosen',
      'nomor_identitas': 'DEMO-DOSEN-001',
      'nomor_karpeg': 'DEMO-KARPEG-001',
      'jenjang_pendidikan': 'S2 Demo',
      'tempat_lahir': 'Kota Demo',
      'tanggal_lahir': '01 Januari 1990',
      'alamat': 'Alamat sintetis untuk pratinjau',
      'nomor_telp': '000-0000',
      'nomor_hp': '0000000000',
      'nomor_ktp': 'DEMO-NIK-000',
      'agama': 'Demo',
      'negara': 'Indonesia (demo)',
      'status_nikah': 'Demo',
      'nomor_npwp': 'DEMO-NPWP',
      'nama_wajib_pajak': 'Demo Dosen',
      'NAMA': 'Demo Dosen',
      'NIM': 'DEMO-DOSEN-001',
      'STATUS': 'Aktif (sintetis)',
      'FAKULTAS': 'Fakultas Demo',
      'JURUSAN': 'Jurusan Demo',
      'PROGRAM': 'Program Studi Demo',
      'FILE_FOTO': '',
    };
    final demoClass = row(classId, 'Mata Kuliah Demo · Kelas A', {
      'HARI_KE': '1',
      'K_MK': 'DEMO101',
      'THN_MK': '2026',
      'NAMA': 'Mata Kuliah Demo',
      'KELAS': 'A',
      'JENJANG': 'S1',
      'JAM_MULAI': '08:00',
      'JAM_SELESAI': '09:40',
      'PROG_STUDI': 'Program Studi Demo',
      'K_GEDUNG_KULIAH': 'DEMO',
      'RUANG_KULIAH': 'D-01',
      'TAHUN': '2026',
      'IS_GANJIL': '1',
      'FAKULTAS': 'Fakultas Demo',
      'LINK_BRONE': '',
      'course': 'Mata Kuliah Demo',
      'class': 'A',
      'day': 'Senin',
      'room': 'D-01',
      'year': 2026,
    });
    final teaching = row('DEMO-MATERI-01', 'Materi pertemuan demo', {
      'K_MATERI_AJAR': 'DEMO-MATERI-01',
      'MATA_KULIAH': 'Mata Kuliah Demo',
      'KELAS': 'A',
      'MATERI': 'Topik sintetis',
      'KETERANGAN': 'Catatan demonstrasi lokal',
      'TANGGAL': '2026-10-19',
      'TGL_ABSENSI': '2026-10-19',
      'JAM_MULAI': '08:00',
      'JAM_SELESAI': '09:40',
      'Batas presensi': '15',
      'class_id': classId,
      'status': 'Draft',
      'class': 'A',
      'year': 2026,
    }, parent: classId);
    final document = row(docId, 'Surat demo untuk diproses', {
      'notugas': 'DEMO-001/UB/2026',
      'tugas': 'Surat demo untuk diproses',
      'tglsurat': '2026-10-19',
      'unit': 'Unit Demo',
      'deskripsi': 'Isi surat sepenuhnya sintetis untuk pratinjau.',
      'idjenissurat': 'DEMO',
      'idtujuan': 'DEMO',
      'status': 'Menunggu proses',
      'nama_pengirim': 'Pengirim Demo',
      'tanggal': '2026-10-19',
      'ringkasan': 'Konten sintetis',
      'checked': false,
      'category': 'Surat Masuk',
    });
    final rows = <String, List<Record>>{};
    void put(String key, List<Record> values) => rows[key] = values;
    put('profile', [row('DEMO-PROFILE', 'Profil Dosen', profile)]);
    put('employee', [row('DEMO-EMPLOYEE', 'Data Diri', profile)]);
    put('sister', [
      row('DEMO-SISTER', 'Biodata SISTER', {
        ...profile,
        'unit': 'Unit Demo',
        'nama': 'Demo Dosen',
        'gelar_depan': '',
        'gelar_belakang': '',
        'tag_identitas': 'Identitas Demo',
        'rt': '001',
        'rw': '002',
        'kelurahan': 'Kelurahan Demo',
        'kecamatan': 'Kecamatan Demo',
        'kota': 'Kota Demo',
        'kodepos': '00000',
      }),
    ]);
    const historyCategories = [
      'Keaktifan',
      'Keluarga',
      'Penghargaan',
      'Kepangkatan',
      'Perubahan Gaji',
      'Jab. Fungsional',
      'Jab. Struktural',
      'Jab. NonStruktural',
      'Homebase',
      'Serdos',
      'Pendidikan',
      'Diklat',
      'Sertifikat',
    ];
    put('personnel_history', [
      for (var i = 0; i < historyCategories.length; i++)
        row('DEMO-HISTORY-${i + 1}', historyCategories[i], {
          'KETERANGAN': 'Catatan sintetis: ${historyCategories[i]}',
          'TANGGAL': '2024-01-${(i + 1).toString().padLeft(2, '0')}',
          'category': historyCategories[i],
          'KATEGORI': historyCategories[i],
          'year': 2024,
        }),
    ]);
    put('survey', [
      row('DEMO-SURVEY', 'Survei Pegawai', {
        'id_survey': 'DEMO-SURVEY',
        'judul_survey': 'Survei Pegawai Demo',
        'repeat_by_day': '1',
        'has_result': true, // Synthetic SurveyHasil-presence scenario flag.
      }),
    ]);
    put('survey_components', [
      row('DEMO-SURVEY-Q1', 'Pertanyaan demo', {
        'id_survey': 'DEMO-SURVEY',
        'id_komponen_survey': 'DEMO-SURVEY-Q1',
        'komponen_survey': 'Seberapa jelas informasi demo?',
        'tag': 'radio',
        'is_required': '1',
        'label': 'Baik',
        'value': 'DEMO-BAIK',
      }),
    ]);
    put('attendance', [
      row('DEMO-ATTENDANCE', 'Presensi demo', {
        'STATUS': 'Belum direkam',
        'WAKTU': '08:00',
        'KETERANGAN': 'Pratinjau lokal',
      }),
    ]);
    put('tasks', [
      row('DEMO-TASK-01', 'Tugas harian demo', {
        'TUGAS': 'Siapkan materi demo',
        'TANGGAL': '2026-10-19',
      }),
    ]);
    put('attendance_history', [
      row('DEMO-ATT-HIST', 'Riwayat presensi demo', {
        'TANGGAL': '2026-10-01',
        'STATUS': 'Hadir (demo)',
        'BULAN': 10,
        'TAHUN': '2026',
        'year': 2026,
      }),
    ]);
    for (final r in [
      'remuneration_profile',
      'tgp',
      'incentives',
      'additional_incentives',
      'remun13',
      'deductions',
      'remuneration_activities',
      'income',
      'tax_documents',
      'bonuses',
    ]) {
      put(r, [
        row('DEMO-$r-01', r.replaceAll('_', ' '), {
          'PERIODE': '2026',
          'TAHUN': '2026',
          'year': 2026,
          'NILAI': 'Nilai sintetis',
          'KETERANGAN': 'Contoh tampilan; bukan hak finansial',
        }),
      ]);
    }
    put('schedule', [demoClass]);
    put('teaching_drafts', [teaching]);
    put('teaching_active', []);
    put('teaching_history', [
      row('DEMO-MATERI-HIST', 'Materi selesai demo', {
        'MATA_KULIAH': 'Mata Kuliah Demo',
        'KELAS': 'A',
        'TGL_ABSENSI': '2026-10-01',
        'JAM_MULAI': '08:00',
        'JAM_SELESAI': '09:40',
        'MATERI': 'Materi sintetis',
        'KETERANGAN': 'Catatan demo',
        'K_ABSENSI': 'H',
        'year': 2026,
      }, parent: classId),
    ]);
    put('student_attendance', [
      row('DEMO-MHS-ATT', 'Mahasiswa Demo · Hadir', {
        'NAMA': 'Mahasiswa Demo',
        'NIM': 'DEMO-MHS-001',
        'K_ABSENSI': 'H',
        'STATUS': 'Hadir',
        'class_id': classId,
      }, parent: 'DEMO-MATERI-01'),
    ]);
    put('attendance_recap', [
      row('DEMO-RECAP', 'Rekap kelas demo', {
        'PERTEMUAN': '1',
        'HADIR': '1',
        'IJIN': '0',
        'ALPHA': '0',
        'SAKIT': '0',
        'REKAP': '1',
      }, parent: classId),
    ]);
    put('class_announcements', [
      row('DEMO-ANN-01', 'Pengumuman Demo', {
        'PENGUMUMAN': 'Informasi sintetis untuk pratinjau.',
        'TGL_AWAL': '2026-10-19',
        'TGL_AKHIR': '2026-10-26',
        'MATA_KULIAH': 'Mata Kuliah Demo',
        'KELAS': 'A',
      }, parent: classId),
    ]);
    put('calendars', [
      row('DEMO-CALENDAR-ACCOUNT', 'Kalender Demo', {
        'calendar_id': 'DEMO-CALENDAR-ACCOUNT',
        'name': 'Kalender Demo',
        'account_name': 'Akun lokal demo',
        'read_only': false,
        'synthetic': true,
      }),
    ]);
    put('advisees', [
      row('DEMO-ADVISEE', 'Mahasiswa Bimbingan Demo', {
        'NAMA': 'Mahasiswa Demo',
        'NIM': 'DEMO-MHS-001',
        'JENJANG': 'S1',
        'FAKULTAS': 'Fakultas Demo',
        'PRODI': 'Program Studi Demo',
        'STATUS': 'Aktif (demo)',
        'SEMESTER': '3',
        'IPK': '3.50',
      }),
    ]);
    put('publication_overview', [
      row('DEMO-PUB-OVERVIEW', 'Statistik Publikasi Demo', {
        'name': 'Peneliti Demo',
        'sinta_id': 'DEMO-SINTA-001',
        'sinta_score': '120',
        'sinta_score_3yr': '45',
        'sinta_national_rank': '12000',
        'sinta_affiliation_rank': '250',
      }),
    ]);
    put('publication_output', [
      row('DEMO-PUB-OUTPUT', 'Metrik Publikasi Demo', {
        'tahun': [2022, 2023, 2024],
        'status_value': [2, 3, 4],
        'scopus_doc': '3',
        'scopus_citation': '12',
        'scopus_h_index': '2',
        'scopus_i_index': '1',
        'scopus_g_index': '3',
        'wos_doc': '1',
        'wos_citation': '4',
        'wos_h_index': '1',
        'wos_i_index': '1',
        'wos_g_index': '1',
        'google_doc': '5',
        'google_cited_doc': '4',
        'google_h_index': '3',
        'google_i_index': '2',
        'google_g_index': '4',
        'garuda_doc': '2',
        'garuda_citation': '5',
        'garuda_h_index': '1',
        'garuda_i_index': '1',
        'garuda_g_index': '2',
        'sinta_books': '1',
      }),
    ]);
    put('publication_people', [
      row('DEMO-PUB-PERSON', 'Peringkat Peneliti Demo', {
        'NAMA': 'Peneliti Demo',
        'NIDN': 'DEMO-NIDN-001',
        'Overall Score V2': '120',
        'Score': '120',
      }),
    ]);
    put('publication_affiliations', [
      row('DEMO-PUB-AFFILIATION', 'Peringkat Afiliasi Demo', {
        'Code': 'DEMO-UB',
        'All Year Score V2': '120',
        'All Year Score': '45',
      }),
    ]);
    put('pendapa_calendar', [
      row('DEMO-PEND-CAL', 'Agenda surat demo', {
        'tanggal': '2026-10-19',
        'keterangan': 'Agenda sintetis',
        'notugas': 'DEMO-001/UB/2026',
        'tugas': 'Surat demo untuk diproses',
        'tglsurat': '2026-10-19',
        'unit': 'Unit Demo',
        'deskripsi': 'Agenda surat sintetis',
        'document_id': docId,
      }),
    ]);
    put('pendapa_tasks', [
      row('DEMO-PEND-TASK', 'Tugas Pendapa demo', {
        'title': 'Tinjau surat demo',
        'status': 'Menunggu',
        'notugas': 'DEMO-001/UB/2026',
        'tugas': 'Surat demo untuk diproses',
        'tglsurat': '2026-10-19',
        'unit': 'Unit Demo',
        'deskripsi': 'Tugas surat sintetis',
        'document_id': docId,
      }),
    ]);
    for (final r in [
      'pendapa_incoming',
      'pendapa_paraf',
      'pendapa_tte',
      'pendapa_incoming_history',
      'pendapa_paraf_history',
      'pendapa_tte_history',
      'pendapa_archive',
    ]) {
      put(r, [
        _copy(document)
          ..['category'] = r
          ..['document_id'] = docId,
      ]);
    }
    put('document_detail', [row(docId, 'Surat demo untuk diproses', document)]);
    put('document_timeline', [
      row('DEMO-TIMELINE-01', 'Surat diterima (demo)', {
        'status': 'Diterima (demo)',
        'tanggal': '2026-10-19',
        'document_id': docId,
      }, parent: docId),
    ]);
    put('document_attachments', [
      row('DEMO-ATTACH-01', 'Lampiran demo.pdf', {
        'filename': 'Lampiran demo.pdf',
        'mime': 'application/pdf',
        'synthetic': true,
        'document_id': docId,
      }, parent: docId),
    ]);
    return rows;
  }
}
