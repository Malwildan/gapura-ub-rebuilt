import 'package:http/http.dart' as http;

import '../model/general_announcement.dart';
import '../model/news_feed.dart';
import '../service/general_announcements.dart';
import '../services.dart';
import 'guest_demo_session.dart';

/// Existing public service boundary backed only by local synthetic fixtures.
class GuestDemoService extends GapuraService {
  GuestDemoService(this.session) : super(client: _NoGuestDemoNetwork());

  final GuestDemoSession session;

  Future<List<Map<String, dynamic>>> _result(
    List<Map<String, dynamic>> rows,
  ) async {
    await session.read();
    return session.scenario == GuestDemoScenario.empty ? [] : rows;
  }

  @override
  Future<List<Map<String, dynamic>>> news() => newsFeed(NewsFeed.prasetya);

  @override
  Future<List<Map<String, dynamic>>> newsFeed(NewsFeed feed) => _result([
    {
      'title': 'Berita Demo · ${feed.label}',
      'date': '2026-10-19',
      'description': 'Artikel sintetis untuk melihat tata letak.',
      'link': '',
    },
  ]);

  @override
  Future<List<Map<String, dynamic>>> latestNews() => _result([
    {
      'title': 'Berita Terkini Demo',
      'date': '2026-10-19',
      'description': 'Contoh berita sintetis untuk pratinjau lokal.',
      'link': '',
    },
  ]);

  @override
  Future<List<Map<String, dynamic>>> calendar() => _result([
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
  Future<List<Map<String, dynamic>>> statistics() => _result([
    for (final label in ['Fakultas', 'Program Studi', 'Mahasiswa Baru'])
      {'ITEM': '$label (demo)', 'JML': '12', '_group': 'SEKILAS'},
  ]);

  @override
  Future<List<Map<String, dynamic>>> achievements() => _result([
    for (var i = 1; i <= 2; i++)
      {
        'URL_FILE': 'demo:achievement-$i',
        'JENIS_GAMBAR': 'Penghargaan Demo $i',
        'LINK': '',
      },
  ]);

  @override
  Future<List<Map<String, dynamic>>> images() => _result([
    {'URL_FILE': 'demo:gallery-1', 'JENIS_GAMBAR': 'Galeri Demo', 'LINK': ''},
  ]);

  @override
  void close() {
    session.close();
    super.close();
  }
}

class GuestDemoAnnouncements extends GeneralAnnouncementsSource {
  GuestDemoAnnouncements(this.session);
  final GuestDemoSession session;

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
    if (session.scenario == GuestDemoScenario.empty) return [];
    final now = DateTime.now();
    // The recovered visibility predicate is inverted: start >= now and end <= now.
    return [
      GeneralAnnouncement(
        id: 'guest-demo',
        title: 'Pengumuman Demo',
        content: 'Contoh sintetis untuk pratinjau lokal.',
        startDate: now.add(const Duration(days: 1)),
        endDate: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}

class _NoGuestDemoNetwork extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw StateError('Jaringan layanan tidak tersedia dalam demo lokal.');
}
