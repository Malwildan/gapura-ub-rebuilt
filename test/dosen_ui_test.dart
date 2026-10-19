import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/demo/demo_session.dart';
import 'package:gapura_ub/demo/dosen_data.dart';
import 'package:gapura_ub/ui/dosen/dosen_module.dart';

void main() {
  DosenDemoData data(DemoScenario scenario) => DosenDemoData(
    DemoSession(
      role: DemoRole.lecturer,
      scenario: scenario,
      delay: Duration.zero,
    ),
  );

  Future<void> pumpModule(
    WidgetTester tester,
    DosenDemoData source,
    String route,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DosenModuleScreen(data: source, route: route),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'schedule opens recovered teaching tabs and confirms local draft deletion',
    (tester) async {
      final source = data(DemoScenario.populated);
      await pumpModule(tester, source, 'jadwal_dosen');
      final course = find.textContaining('Mata Kuliah Demo').first;
      await scrollTo(tester, course);
      await tester.tap(course);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kuliah'));
      await tester.pumpAndSettle();

      expect(find.text('Sub Capaian Pembelajaran'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.text('Topik sintetis'), findsOneWidget);

      expect(await source.read('teaching_drafts'), hasLength(1));
      final delete = find.text('Hapus Draft');
      await scrollTo(tester, delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(find.text('Hapus Draft'), findsWidgets);
      await tester.tap(find.text('Konfirmasi'));
      await tester.pumpAndSettle();
      expect(await source.read('teaching_drafts'), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'advisee search filters by NIM and tapping the card stays on the list',
    (tester) async {
      await pumpModule(tester, data(DemoScenario.populated), 'student_pa');
      expect(find.textContaining('Daftar Mahasiswa Bimbingan'), findsOneWidget);
      expect(find.text('DEMO-MHS-001'), findsWidgets);
      await tester.enterText(find.byType(TextField).first, 'tidak-ada');
      await tester.pumpAndSettle();
      expect(find.text('DEMO-MHS-001'), findsNothing);
      expect(
        find.text('Mohon maaf tidak ada data untuk ditampilkan.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).first, 'DEMO-MHS-001');
      await tester.pumpAndSettle();
      final cardTitle = find.textContaining('Daftar Mahasiswa Bimbingan');
      expect(cardTitle, findsOneWidget);
      await scrollTo(tester, cardTitle);
      await tester.tap(cardTitle);
      await tester.pumpAndSettle();
      expect(find.text('DEMO-MHS-001'), findsWidgets);
      expect(find.text('Detail'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pendapa incoming row opens Paraf form and TTE row opens TTE form',
    (tester) async {
      final source = data(DemoScenario.populated);
      await tester.pumpWidget(
        MaterialApp(home: DosenPendapaView(data: source)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Surat Masuk'));
      await tester.pumpAndSettle();
      final incoming = find.text('DEMO-001/UB/2026');
      await scrollTo(tester, incoming);
      await tester.tap(incoming);
      await tester.pumpAndSettle();
      expect(find.text('Paraf / Verifikasi Surat'), findsOneWidget);
      expect(find.text('Informasi Surat'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tanda tangan'));
      await tester.pumpAndSettle();
      final tteRow = find.text('DEMO-001/UB/2026');
      await scrollTo(tester, tteRow);
      await tester.tap(tteRow);
      await tester.pumpAndSettle();
      expect(find.text('Validasi dan TTE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'daily task save and confirmed delete mutate only the in-memory session',
    (tester) async {
      final source = data(DemoScenario.populated);
      await pumpModule(tester, source, 'survey_employee');
      await tester.tap(find.text('Tugas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tambah Tugas'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Tugas widget demo');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(
        (await source.read(
          'tasks',
        )).any((r) => r['title'] == 'Tugas widget demo'),
        isTrue,
      );
      expect(find.text('Tugas widget demo'), findsOneWidget);

      await tester.tap(find.byTooltip('Hapus tugas').last);
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi'), findsOneWidget);
      await tester.tap(find.text('Yakin'));
      await tester.pumpAndSettle();
      expect(
        (await source.read(
          'tasks',
        )).any((r) => r['title'] == 'Tugas widget demo'),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a task written in one demo session does not appear in a replacement session',
    (tester) async {
      final oldSession = data(DemoScenario.populated);
      await pumpModule(tester, oldSession, 'survey_employee');
      await tester.tap(find.text('Tugas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tambah Tugas'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'Task isolated to old session',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(
        (await oldSession.read(
          'tasks',
        )).any((r) => r['title'] == 'Task isolated to old session'),
        isTrue,
      );

      await pumpModule(tester, data(DemoScenario.populated), 'survey_employee');
      await tester.tap(find.text('Tugas'));
      await tester.pumpAndSettle();
      expect(find.text('Task isolated to old session'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile shows recovered groups and synthetic values after scrolling',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DosenProfileView(data: data(DemoScenario.populated)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AKUN PEGAWAI UB'), findsOneWidget);
      expect(find.text('Demo Dosen'), findsWidgets);
      final address = find.text('Alamat sintetis untuk pratinjau');
      await scrollTo(tester, address);
      expect(address, findsOneWidget);
      for (final label in ['Alamat dan Kontak', 'Kependudukan', 'Lain-lain']) {
        final group = find.text(label);
        await scrollTo(tester, group);
        expect(group, findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty and error data states remain distinct, and error offers retry',
    (tester) async {
      await pumpModule(tester, data(DemoScenario.empty), 'jadwal_dosen');
      expect(
        find.text('Tidak ada Jadwal Mengajar untuk hari ini.'),
        findsOneWidget,
      );
      expect(find.text('Data gagal dimuat'), findsNothing);

      await pumpModule(tester, data(DemoScenario.error), 'student_pa');
      expect(find.textContaining('Data tidak dapat dimuat.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'loading profile remains pending and recovers with a new source',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DosenProfileView(
              key: const ValueKey('loading'),
              data: data(DemoScenario.loading),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DosenProfileView(
              key: const ValueKey('populated'),
              data: data(DemoScenario.populated),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Demo Dosen'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lecturer controls fit narrow and wide viewports without layout exceptions',
    (tester) async {
      final source = data(DemoScenario.populated);
      for (final size in [const Size(360, 800), const Size(1280, 900)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await pumpModule(tester, source, 'survey_employee');
        expect(find.text('Presensi'), findsWidgets);
        expect(tester.takeException(), isNull);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );
}
