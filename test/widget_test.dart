import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/account_bridge.dart';
import 'package:gapura_ub/main.dart';
import 'package:gapura_ub/common/features.dart';
import 'package:gapura_ub/services.dart';
import 'package:gapura_ub/model/news_feed.dart';
import 'package:gapura_ub/ui/guest/student_profile.dart';
import 'package:gapura_ub/model/general_announcement.dart';
import 'package:gapura_ub/service/general_announcements.dart';

// Synthetic records are confined to tests; the application always reads UB.
class FixtureAccount extends AccountBridge {
  final List<({String action, Map<String, dynamic> parameters})> requests = [];
  @override
  Future<Map<String, dynamic>> request(
    String action, {
    Map<String, dynamic> parameters = const {},
  }) async {
    requests.add((action: action, parameters: Map.of(parameters)));
    return switch (action) {
      'identity' => {
        'X-Ub-Nim': 'QA-IDENTITY-NIM',
        'X-Ub-Email': 'synthetic@example.invalid',
      },
      'profile' => {
        'mhs': {
          'data': [
            {'NAMA': 'QA Student', 'NIM': 'QA-ONLY', 'PROGRAM': 'QA Program'},
          ],
        },
      },
      'schedule' => {
        'jadwal': {
          'data': [
            {
              'KULIAH': 'Monday Course',
              'K_MK': 'QA1',
              'KELAS': 'A',
              'HARI_KE': '1',
              'JAM_MULAI': '08:00',
              'JAM_SELESAI': '10:00',
              'JML_SKS': '2',
              'TAHUN': '2026',
              'IS_GANJIL': '1',
            },
            {
              'KULIAH': 'Tuesday Course',
              'K_MK': 'QA2',
              'KELAS': 'B',
              'HARI_KE': '2',
              'JAM_MULAI': '10:00',
              'JAM_SELESAI': '12:00',
              'JML_SKS': '2',
              'TAHUN': '2026',
              'IS_GANJIL': '1',
            },
          ],
        },
      },
      'grades' => {
        'khs': {
          'data': [
            {
              'NAMA': 'Published Course',
              'K_MK': 'QA1',
              'K_NILAI': 'A',
              'NILAI_ANGKA': '4',
              'IS_PUBLISH_NILAI': '1',
            },
            {
              'NAMA': 'Unpublished Course',
              'K_MK': 'QA2',
              'K_NILAI': 'SECRET_GRADE',
              'NILAI_ANGKA': 'SECRET_WEIGHT',
              'IS_PUBLISH_NILAI': '0',
            },
          ],
        },
      },
      _ => {
        'output': {'data': []},
      },
    };
  }
}

class DelayedScheduleAccount extends FixtureAccount {
  bool hold = false;
  final pending = <bool, Completer<Map<String, dynamic>>>{};

  @override
  Future<Map<String, dynamic>> request(
    String action, {
    Map<String, dynamic> parameters = const {},
  }) {
    if (action != 'schedule' || !hold) {
      return super.request(action, parameters: parameters);
    }
    requests.add((action: action, parameters: Map.of(parameters)));
    return (pending[parameters['short'] == true] = Completer()).future;
  }
}

class FixturePublic extends GapuraService {
  @override
  Future<List<Map<String, dynamic>>> news() async => [];
  @override
  Future<List<Map<String, dynamic>>> latestNews() async => [];
  @override
  Future<List<Map<String, dynamic>>> newsFeed(NewsFeed feed) async => [];
  @override
  Future<List<Map<String, dynamic>>> calendar() async => [];
}

class GuestAccount extends FixtureAccount {
  @override
  Future<Map<String, dynamic>> request(
    String action, {
    Map<String, dynamic> parameters = const {},
  }) async {
    requests.add((action: action, parameters: Map.of(parameters)));
    throw StateError('Akun belum terhubung.');
  }
}

class PendingNews extends FixturePublic {
  final pending = <NewsFeed, Completer<List<Map<String, dynamic>>>>{};
  final calls = <NewsFeed>[];

  @override
  Future<List<Map<String, dynamic>>> latestNews() async => [
    {'title': 'Latest fixture', 'date': 'QA date'},
  ];

  @override
  Future<List<Map<String, dynamic>>> newsFeed(NewsFeed feed) {
    calls.add(feed);
    if ([NewsFeed.rsub, NewsFeed.klinik, NewsFeed.rsgm].contains(feed)) {
      return Future.value([
        {'title': '${feed.label} home fixture'},
      ]);
    }
    return (pending[feed] = Completer()).future;
  }
}

Future<void> openStudentMenu(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Menu'),
    ),
  );
  await tester.pumpAndSettle();
}

class FixtureAnnouncements extends GeneralAnnouncementsSource {
  int calls = 0;
  bool fail = false;
  @override
  Future<List<GeneralAnnouncement>> fetch() async {
    calls++;
    if (fail) {
      throw const GeneralAnnouncementsException(
        GeneralAnnouncementsFailure.fetch,
      );
    }
    final now = DateTime.now();
    return [
      GeneralAnnouncement(
        startDate: now.add(const Duration(days: 1)),
        endDate: now.subtract(const Duration(days: 1)),
        title: 'Synthetic general announcement',
        content: 'Synthetic body',
      ),
    ];
  }
}

void main() {
  testWidgets(
    'Home loads general announcements separately and keeps successful rows after failure',
    (tester) async {
      final api = FixturePublic();
      final announcements = FixtureAnnouncements();
      final account = FixtureAccount();
      addTearDown(api.close);
      await tester.pumpWidget(
        GapuraApp(service: api, account: account, announcements: announcements),
      );
      await tester.pumpAndSettle();
      expect(announcements.calls, 1);
      expect(find.text('1 pengumuman penting'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        account.requests.where((r) => r.action == 'announcements'),
        isEmpty,
      );
      await tester.ensureVisible(find.text('1 pengumuman penting'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 pengumuman penting'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic general announcement'), findsOneWidget);
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      announcements.fail = true;
      await tester.tap(find.byTooltip('Muat ulang'));
      await tester.pumpAndSettle();
      expect(announcements.calls, 2);
      expect(find.text('1 pengumuman penting'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Profil uses recovered identity and six detail rows', (
    tester,
  ) async {
    final api = FixturePublic();
    final account = FixtureAccount();
    addTearDown(api.close);
    await tester.pumpWidget(GapuraApp(service: api, account: account));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Profil'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StudentProfileView), findsOneWidget);
    expect(find.text('QA-IDENTITY-NIM'), findsOneWidget);
    expect(find.text('synthetic@example.invalid'), findsOneWidget);
    expect(find.text('Angkatan:'), findsOneWidget);
    expect(find.text('Jurusan'), findsOneWidget);
    expect(find.text('Jenjang dan Program Studi'), findsOneWidget);
    expect(find.text('Kelola Akun UB'), findsNothing);
    expect(find.text('Putuskan koneksi aplikasi'), findsNothing);
    expect(account.requests.where((r) => r.action == 'identity'), hasLength(1));
    expect(tester.takeException(), isNull);
  });
  for (final connected in [false, true]) {
    testWidgets(
      'Home has recovered public eight in two columns, connected=$connected',
      (tester) async {
        final api = FixturePublic();
        final account = connected ? FixtureAccount() : GuestAccount();
        addTearDown(api.close);
        await tester.pumpWidget(GapuraApp(service: api, account: account));
        await tester.pumpAndSettle();
        expect(
          find.text(connected ? 'Halo, QA Student' : 'Halo, Pengunjung\n'),
          findsOneWidget,
        );
        const labels = [
          'Visi Misi',
          'Fakultas',
          'Pimpinan',
          'Fasilitas',
          'Kalender Akademik',
          'Statistik',
          'Sejarah',
          'Lambang',
        ];
        const assets = [
          'ub_visi-misi.png',
          'ub_fakultas.png',
          'ub_pimpinan.png',
          'ub_fasilitas.png',
          'ub_kalendar-akademik.png',
          'ub_statistik.png',
          'ub_sejarah.png',
          'ub_lambang.png',
        ];
        expect(publicFeatures.map((f) => f.label), labels);
        expect(
          publicFeatures.map((f) => f.asset),
          assets.map((a) => 'icon/$a'),
        );
        final grid = tester.widget<GridView>(find.byType(GridView));
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, 2);
        expect(grid.padding, EdgeInsets.zero);
        for (var i = 0; i < labels.length; i++) {
          expect(find.text(labels[i]), findsOneWidget);
          if (i.isOdd) {
            expect(
              tester.getTopLeft(find.text(labels[i])).dy,
              tester.getTopLeft(find.text(labels[i - 1])).dy,
            );
          } else if (i > 0) {
            expect(
              tester.getTopLeft(find.text(labels[i])).dy,
              greaterThan(tester.getTopLeft(find.text(labels[i - 1])).dy),
            );
          }
        }
        expect(find.text('Layanan Mahasiswa'), findsNothing);
        expect(find.text('Kartu Hasil Studi'), findsNothing);
        final logo = tester
            .widgetList<Image>(find.byType(Image))
            .firstWhere(
              (image) =>
                  image.image is AssetImage &&
                  (image.image as AssetImage).assetName ==
                      'assets/img/gapura-logo-white.png',
            );
        expect(logo.height, 20);
        if (!connected) {
          await tester.tap(find.text('masuk'));
          await tester.pumpAndSettle();
          expect(
            account.requests.where((r) => r.action == 'login'),
            hasLength(1),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Home keeps typed feed sections ordered and reuses RSUB cache in News',
    (tester) async {
      final api = PendingNews();
      addTearDown(api.close);
      await tester.pumpWidget(
        GapuraApp(service: api, account: FixtureAccount()),
      );
      await tester.pumpAndSettle();
      const titles = [
        'Berita Terkini',
        'Info Rumah Sakit UB',
        'Info Klinik UB',
        'Info RSGM UB',
      ];
      for (var i = 1; i < titles.length; i++) {
        expect(
          tester.getTopLeft(find.text(titles[i])).dy,
          greaterThan(tester.getTopLeft(find.text(titles[i - 1])).dy),
        );
      }
      expect(api.calls, [NewsFeed.rsub, NewsFeed.klinik, NewsFeed.rsgm]);
      await tester.scrollUntilVisible(
        find.text('Info Rumah Sakit UB'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Info Rumah Sakit UB'));
      await tester.pumpAndSettle();
      expect(find.text('RSUB home fixture'), findsOneWidget);
      expect(find.text('Klinik home fixture'), findsNothing);
      expect(find.text('Latest fixture'), findsNothing);
      expect(api.calls.where((f) => f == NewsFeed.rsub), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Guest navigation exposes home and news without student tabs', (
    tester,
  ) async {
    final api = FixturePublic();
    addTearDown(api.close);
    await tester.pumpWidget(GapuraApp(service: api, account: GuestAccount()));
    await tester.pumpAndSettle();
    final bar = find.byType(BottomNavigationBar);
    expect(
      find.descendant(of: bar, matching: find.text('Beranda')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bar, matching: find.text('Berita')),
      findsOneWidget,
    );
    expect(find.descendant(of: bar, matching: find.text('Menu')), findsNothing);
    expect(
      find.descendant(of: bar, matching: find.text('Profil')),
      findsNothing,
    );
    await tester.tap(find.descendant(of: bar, matching: find.text('Berita')));
    await tester.pumpAndSettle();
    expect(find.byType(Tab), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Public destinations do not enter the academic history reader', (
    tester,
  ) async {
    final api = FixturePublic();
    final account = FixtureAccount();
    addTearDown(api.close);
    await tester.pumpWidget(GapuraApp(service: api, account: account));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visi Misi'));
    await tester.pumpAndSettle();
    expect(find.text('Visi dan Misi UB'), findsOneWidget);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sejarah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sejarah'));
    await tester.pumpAndSettle();
    expect(find.text('Sejarah UB'), findsOneWidget);
    expect(find.text('Sejarah Singkat UB'), findsOneWidget);
    expect(account.requests.where((r) => r.action == 'history'), isEmpty);
    expect(publicFeatures[6].originalRoute, 'history');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Final Menu buttons dispatch their academic readers', (
    tester,
  ) async {
    final api = FixturePublic();
    final account = FixtureAccount();
    addTearDown(api.close);
    await tester.pumpWidget(GapuraApp(service: api, account: account));
    await tester.pumpAndSettle();
    await openStudentMenu(tester);
    for (final entry in [
      ('Biaya Kuliah', 'finance'),
      ('Hasil Studi', 'transcript'),
      ('Kartu Hasil Studi', 'grades'),
      ('Kartu Rencana Studi', 'krs'),
      ('Jadwal & Presensi Kuliah', 'schedule'),
    ]) {
      await tester.ensureVisible(find.text(entry.$1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.$1));
      await tester.pumpAndSettle();
      expect(account.requests.where((r) => r.action == entry.$2), isNotEmpty);
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Aplikasi Saya'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Student menu has the seven final authenticated entries in a list',
    (tester) async {
      final api = FixturePublic();
      addTearDown(api.close);
      await tester.pumpWidget(
        GapuraApp(service: api, account: FixtureAccount()),
      );
      await tester.pumpAndSettle();
      final bar = find.byType(BottomNavigationBar);
      for (final label in ['Beranda', 'Menu', 'Berita', 'Profil']) {
        expect(
          find.descendant(of: bar, matching: find.text(label)),
          findsOneWidget,
        );
      }
      await tester.tap(find.descendant(of: bar, matching: find.text('Menu')));
      await tester.pumpAndSettle();
      expect(find.text('Aplikasi Saya'), findsOneWidget);
      expect(find.text('Biaya Kuliah'), findsOneWidget);
      expect(find.text('Kartu Hasil Studi'), findsOneWidget);
      expect(find.text('Kartu Rencana Studi'), findsOneWidget);
      expect(find.text('Jadwal & Presensi Kuliah'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Kartu Hasil Studi')).dy,
        greaterThan(tester.getTopLeft(find.text('Biaya Kuliah')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Kartu Rencana Studi')).dy,
        greaterThan(tester.getTopLeft(find.text('Kartu Hasil Studi')).dy),
      );
      expect(find.text('Hasil Studi'), findsOneWidget);
      expect(find.text('Presensi Kelas'), findsOneWidget);
      expect(find.text('Layanan Perpustakaan'), findsOneWidget);
      await tester.tap(find.text('Kartu Hasil Studi'));
      await tester.pumpAndSettle();
      expect(find.text('Kartu Hasil Studi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'News tabs isolate late responses and retain the separate home feed',
    (tester) async {
      final api = PendingNews();
      addTearDown(api.close);
      await tester.pumpWidget(
        GapuraApp(service: api, account: FixtureAccount()),
      );
      await tester.pumpAndSettle();
      final bar = find.byType(BottomNavigationBar);
      await tester.tap(find.descendant(of: bar, matching: find.text('Berita')));
      await tester.pump();
      api.pending[NewsFeed.official]!.complete([
        {'title': 'Official fixture'},
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Official fixture'), findsOneWidget);
      await tester.tap(find.text('Prasetya'));
      await tester.pump();
      await tester.ensureVisible(find.text('SELMA'));
      await tester.tap(find.text('SELMA'));
      await tester.pump();
      api.pending[NewsFeed.selma]!.complete([
        {'title': 'SELMA fixture'},
      ]);
      await tester.pumpAndSettle();
      api.pending[NewsFeed.prasetya]!.complete([
        {'title': 'Prasetya fixture'},
      ]);
      await tester.pumpAndSettle();
      expect(find.text('SELMA fixture'), findsOneWidget);
      expect(find.text('Prasetya fixture'), findsNothing);
      await tester.tap(find.text('Prasetya'));
      await tester.pumpAndSettle();
      expect(find.text('Prasetya fixture'), findsOneWidget);
      expect(
        api.calls.where((feed) => feed == NewsFeed.prasetya),
        hasLength(1),
      );
      await tester.fling(find.byType(TabBarView), const Offset(-600, 0), 1200);
      await tester.pumpAndSettle();
      expect(find.text('SELMA fixture'), findsOneWidget);
      await tester.tap(
        find.descendant(of: bar, matching: find.text('Beranda')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Latest fixture'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Latest fixture'), findsOneWidget);
      expect(find.text('Prasetya fixture'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('Only published grades can be displayed', () {
    expect(
      publishedGrade({'IS_PUBLISH_NILAI': '0', 'K_NILAI': 'SECRET'}),
      'Belum diterbitkan',
    );
    expect(publishedGrade({'IS_PUBLISH_NILAI': '1', 'K_NILAI': 'A'}), 'A');
    expect(() => records({'mhs': 'bad'}, 'mhs'), throwsFormatException);
  });
  testWidgets(
    'Academic period controls send selected values and validate years',
    (tester) async {
      final api = FixturePublic();
      final account = FixtureAccount();
      addTearDown(api.close);
      await tester.pumpWidget(GapuraApp(service: api, account: account));
      await tester.pumpAndSettle();
      await openStudentMenu(tester);
      expect(find.text('Hasil Studi'), findsOneWidget);
      expect(find.text('Presensi Kelas'), findsOneWidget);
      expect(find.text('Layanan Perpustakaan'), findsOneWidget);
      await tester.tap(find.text('Kartu Hasil Studi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('period-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilih tahun dan semester').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('period-year')), '202');
      await tester.ensureVisible(find.byKey(const ValueKey('period-apply')));
      final before = account.requests.where((r) => r.action == 'grades').length;
      await tester.tap(find.byKey(const ValueKey('period-apply')));
      await tester.pumpAndSettle();
      expect(
        find.text('Masukkan tahun akademik dengan empat angka.'),
        findsOneWidget,
      );
      expect(
        account.requests.where((r) => r.action == 'grades').length,
        before,
      );
      await tester.enterText(find.byKey(const ValueKey('period-year')), '2025');
      await tester.ensureVisible(find.byKey(const ValueKey('period-odd')));
      await tester.tap(find.byKey(const ValueKey('period-odd')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semester Genap').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('period-short')));
      await tester.tap(find.byKey(const ValueKey('period-short')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pendek').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('period-apply')));
      await tester.tap(find.byKey(const ValueKey('period-apply')));
      await tester.pumpAndSettle();
      expect(account.requests.last.action, 'grades');
      expect(account.requests.last.parameters, {
        'year': '2025',
        'odd': false,
        'short': true,
      });
      expect(find.text('2025 · Genap · Pendek'), findsOneWidget);
      expect(find.textContaining('SECRET_GRADE'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A late short-schedule response cannot replace a newer selection',
    (tester) async {
      final api = FixturePublic();
      final account = DelayedScheduleAccount();
      addTearDown(api.close);
      await tester.pumpWidget(GapuraApp(service: api, account: account));
      await tester.pumpAndSettle();
      await openStudentMenu(tester);
      await tester.ensureVisible(find.text('Jadwal & Presensi Kuliah'));
      await tester.tap(find.text('Jadwal & Presensi Kuliah'));
      await tester.pumpAndSettle();
      account.hold = true;
      await tester.tap(find.byKey(const ValueKey('schedule-semester-false')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pendek').last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(account.pending.containsKey(true), isTrue);
      await tester.tap(find.byKey(const ValueKey('schedule-semester-true')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Reguler').last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(account.pending.containsKey(false), isTrue);
      Map<String, dynamic> response(String name) => {
        'jadwal': {
          'data': [
            {
              'KULIAH': name,
              'K_MK': 'QA1',
              'KELAS': 'A',
              'HARI_KE': '1',
              'TAHUN': '2026',
              'IS_GANJIL': '1',
            },
          ],
        },
      };
      account.pending[false]!.complete(response('Regular updated'));
      await tester.pumpAndSettle();
      expect(find.text('Regular updated'), findsOneWidget);
      account.pending[true]!.complete(response('Short stale'));
      await tester.pumpAndSettle();
      expect(find.text('Regular updated'), findsOneWidget);
      expect(find.text('Short stale'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [360.0, 1280.0]) {
    testWidgets('Real-account navigation and filters at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FixturePublic();
      addTearDown(api.close);
      await tester.pumpWidget(
        GapuraApp(service: api, account: FixtureAccount()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Halo, QA Student'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await openStudentMenu(tester);
      await tester.ensureVisible(find.text('Jadwal & Presensi Kuliah'));
      await tester.tap(find.text('Jadwal & Presensi Kuliah'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'schedule initial layout');
      expect(find.text('Monday Course'), findsOneWidget);
      await tester.tap(find.text('Sel'));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'filtered schedule layout',
      );
      expect(find.text('Monday Course'), findsNothing);
      expect(find.text('Tuesday Course'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('schedule-search')),
        'no-match',
      );
      await tester.pumpAndSettle();
      expect(find.text('Mata kuliah tidak ditemukan.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      await openStudentMenu(tester);
      expect(find.text('Hasil Studi'), findsOneWidget);
      expect(find.text('Presensi Kelas'), findsOneWidget);
      expect(find.text('Layanan Perpustakaan'), findsOneWidget);
      await tester.tap(find.text('Kartu Hasil Studi'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Unpublished Course'), 200);
      expect(find.text('Belum diterbitkan'), findsOneWidget);
      expect(find.textContaining('SECRET_GRADE'), findsNothing);
      expect(find.textContaining('SECRET_WEIGHT'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
