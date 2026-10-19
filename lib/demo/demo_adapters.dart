import 'dart:convert';

import 'package:http/http.dart' as http;

import '../account_bridge.dart';
import '../model/general_announcement.dart';
import '../model/news_feed.dart';
import '../model/records.dart';
import '../model/student_attendance.dart';
import '../service/general_announcements.dart';
import '../service/survey_submission.dart';
import '../services.dart';
import 'demo_session.dart';

/// Implements the existing boundaries entirely in memory, with no live fallback.
class DemoAccount extends AccountBridge {
  DemoAccount(this.session);
  final DemoSession session;
  final requests = <String>[];
  String attendance = '';
  bool surveyComplete = true;

  Record wrapped(String key, List<Record> rows) => {
    key: {'data': rows},
  };

  @override
  Future<Record> request(String action, {Record parameters = const {}}) async {
    requests.add(action);
    if (session.role == DemoRole.guest) {
      throw StateError('Mode pengunjung tidak memiliki sesi akun.');
    }
    if (action == 'connection') {
      return {'connected': true, 'username': 'demo.${session.role.name}'};
    }
    if (action == 'identity') {
      return {
        'X-Ub-Nim': session.identity['nim'],
        'X-Ub-Email': session.identity['email'],
      };
    }
    if (!session.role.academic) {
      throw UnsupportedError(
        'Layanan ${session.role.label} belum direkonstruksi.',
      );
    }
    if (session.role == DemoRole.parent &&
        ['attendanceSubmit', 'surveySubmit'].contains(action)) {
      throw StateError('Demo orangtua hanya untuk melihat data.');
    }
    await session.read();
    final empty = session.scenario == DemoScenario.empty;
    if (action == 'surveyStatus') {
      return wrapped('output', [
        {'STAT_ISI': surveyComplete ? '1' : '0'},
      ]);
    }
    if (action == 'attendanceSubmit') {
      validateAttendanceChoice(parameters);
      attendance = parameters['status'] as String;
      return wrapped('mhs', [
        {'ERRSTATE': '00000'},
      ]);
    }
    if (action == 'surveySubmit') {
      validateSurveySubmission(parameters);
      surveyComplete = true;
      return {
        'status': 'true',
        'output': {
          'data': [
            {'MESSAGE': 'Jawaban demo disimpan di memori.'},
          ],
        },
      };
    }
    List<Record> rows(List<Record> data) => empty ? [] : data;
    return switch (action) {
      'profile' => wrapped('mhs', rows([session.profile])),
      'schedule' => wrapped(
        'jadwal',
        rows([
          for (var i = 0; i < 2; i++)
            {
              'KULIAH':
                  '${parameters['short'] == true ? 'Pendek' : 'Reguler'} Demo ${i + 1}',
              'K_MK': 'DEMO${i + 1}',
              'KELAS': i == 0 ? 'A' : 'B',
              'HARI_KE': '${i + 1}',
              'JAM_MULAI': '08:00',
              'JAM_SELESAI': '09:40',
              'JML_SKS': '2',
              'TAHUN': '2026',
              'IS_GANJIL': '1',
              'GEDUNG': 'Gedung Demo',
              'RUANG': 'D-01',
              'JUMLAH_DOS': '8',
              'JUMLAH_H': '6',
              'JUMLAH_I': '1',
              'JUMLAH_A': '0',
              'JUMLAH_S': '1',
              'PERSENTASE': '75',
            },
        ]),
      ),
      'krs' => wrapped(
        'krs',
        rows([
          {
            'NAMA_MK': 'Mata Kuliah Demo',
            'K_MK': 'DEMO1',
            'KELAS': 'A',
            'JML_SKS': '2',
          },
        ]),
      ),
      'grades' || 'transcript' => {
        ...wrapped(
          'khs',
          rows([
            {
              'NAMA': 'Mata Kuliah Demo',
              'K_MK': 'DEMO1',
              'JML_SKS': '2',
              'TAHUN': '2026',
              'K_NILAI': 'A',
              'NILAI_ANGKA': '4',
              'IS_PUBLISH_NILAI': '1',
            },
          ]),
        ),
        ...wrapped(
          'akadSum',
          rows([
            {
              'IP_LULUS': '4.00',
              'IP_BEBAN': '3.80',
              'IPK_LULUS': '3.75',
              'IPK_BEBAN': '3.70',
              'SKS_LULUS': '20',
              'SKS_BEBAN': '22',
              'SKSK_LULUS': '40',
              'SKSK_BEBAN': '44',
              'MK_BEBAN': '10',
            },
          ]),
        ),
      },
      'finance' => wrapped(
        'tagihan',
        rows([
          {
            'JENIS_BAYAR': 'UKT Demo',
            'SEMESTER': 'Ganjil 2026',
            'TGL_BAYAR': '2026-10-19',
            'JENIS_TRANSAKSI': 'Debit demo',
            'JML_AMBIL': '1000000',
            'JML_TAGIH': '1000000',
            'JML_SETOR': '0',
            'MATA_UANG': 'IDR',
          },
        ]),
      ),
      'attendanceMeetings' => wrapped(
        'output',
        rows([
          {
            'K_MATERI_AJAR': 'DEMO-MEETING',
            'K_ABSENSI': attendance,
            'MATA_KULIAH': 'Mata Kuliah Demo',
            'KELAS': 'A',
            'MATERI': 'Materi sintetis',
            'KETERANGAN': 'Pertemuan untuk pratinjau lokal.',
            'WAKTU_TUTUP': '2030-01-01 12:00:00',
            'IS_DARING': '0',
          },
        ]),
      ),
      'surveyQuestions' => {
        'status': 'true',
        ...wrapped(
          'output',
          rows([
            {
              'K_PERTANYAAN': 'DEMO-Q1',
              'PERTANYAAN': 'Pertanyaan demo (bukan laporan kesehatan)',
              'JAWABAN': {
                'JAWABAN_LIST': [
                  {
                    'K_JAWABAN': 'DEMO-A1',
                    'JAWABAN': 'Pilihan demo',
                    'IS_KETERANGAN': '0',
                    'REDIRECT_LINK': '',
                  },
                ],
              },
            },
          ]),
        ),
      },
      'announcements' => wrapped(
        'output',
        rows([
          {
            'NAMA_MK': 'Pengumuman Demo',
            'PENGUMUMAN': 'Data ini sintetis.',
            'TGL_AWAL': '2026-10-19',
            'TGL_AKHIR': '2026-10-20',
            'KELAS': 'A',
          },
        ]),
      ),
      'materials' || 'history' => wrapped(
        'output',
        rows([
          {
            'MATA_KULIAH': 'Mata Kuliah Demo',
            'TGL_ABSENSI': '2026-10-19',
            'JAM_MULAI': '08:00',
            'JAM_SELESAI': '09:40',
            'MATERI': 'Materi pertemuan demo',
            'KETERANGAN': 'Catatan sintetis',
            'K_ABSENSI': 'H',
          },
        ]),
      ),
      _ => throw UnsupportedError('Aksi demo belum tersedia: $action'),
    };
  }
}

class DemoService extends GapuraService {
  DemoService(this.session) : super(client: _NoDemoNetwork());
  final DemoSession session;

  Future<List<Record>> result(List<Record> rows) async {
    await session.read();
    return session.scenario == DemoScenario.empty
        ? []
        : (jsonDecode(jsonEncode(rows)) as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
  }

  @override
  Future<List<Record>> news() => newsFeed(NewsFeed.prasetya);
  @override
  Future<List<Record>> latestNews() => newsFeed(NewsFeed.latest);
  @override
  Future<List<Record>> newsFeed(NewsFeed feed) => result([
    {
      'title': 'Berita Demo · ${feed.label}',
      'date': '2026-10-19',
      'description': 'Artikel sintetis untuk melihat tata letak.',
      'link': '',
    },
  ]);
  @override
  Future<List<Record>> calendar() => result([
    for (final semester in ['Ganjil', 'Genap'])
      {
        'NAMA_KEGIATAN': 'Kegiatan Demo $semester',
        'THN_AKAD': '2026/2027',
        'SEMESTER': semester,
        '_group': semester.toUpperCase(),
        'TGL_MULAI': '19 Oktober 2026',
        'TGL_SELESAI': '20 Oktober 2026',
        'KETERANGAN': 'Contoh kegiatan sintetis.',
      },
  ]);
  @override
  Future<List<Record>> statistics() => result([
    for (final label in [
      'Fakultas',
      'Program Studi',
      'Mahasiswa Baru',
      'Guru Besar',
    ])
      {'ITEM': '$label (demo)', 'JML': '12', '_group': 'SEKILAS'},
  ]);
  @override
  Future<List<Record>> achievements() => result([
    for (var i = 1; i <= 2; i++)
      {
        'URL_FILE': 'demo:achievement-$i',
        'JENIS_GAMBAR': 'Penghargaan Demo $i',
        'LINK': '',
      },
  ]);
  @override
  Future<List<Record>> images() => result([]);
  @override
  Future<List<Record>> notifications(String username) => result([
    {
      'title': 'Notifikasi Demo',
      'body': 'Pesan sintetis untuk ${session.role.label}.',
      'sentdatetime': '2026-10-19 08:00',
    },
  ]);
}

// Keep future inherited HTTP readers from silently reaching a live service.
class _NoDemoNetwork extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw StateError('Jaringan layanan tidak tersedia dalam demo lokal.');
}

class DemoAnnouncements extends GeneralAnnouncementsSource {
  DemoAnnouncements(this.session);
  final DemoSession session;
  @override
  Future<void> initialize() async {}
  @override
  Future<List<GeneralAnnouncement>> fetch() async {
    try {
      await session.read();
    } catch (_) {
      throw const GeneralAnnouncementsException(
        GeneralAnnouncementsFailure.fetch,
      );
    }
    if (session.scenario == DemoScenario.empty) return [];
    final now = DateTime.now();
    // Deliberately reversed dates exercise the recovered inverted predicate.
    return [
      GeneralAnnouncement(
        id: 'demo',
        title: 'Pengumuman Demo',
        content: 'Contoh sintetis; tidak berasal dari Firebase UB.',
        startDate: now.add(const Duration(days: 1)),
        endDate: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}
