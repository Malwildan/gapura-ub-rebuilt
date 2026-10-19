import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/demo/demo_session.dart';
import 'package:gapura_ub/demo/dosen_data.dart';
import 'package:gapura_ub/ui/dosen/dosen_academic.dart';

void main() {
  DosenDemoData source(DemoScenario scenario) => DosenDemoData(
    DemoSession(
      role: DemoRole.lecturer,
      scenario: scenario,
      delay: Duration.zero,
    ),
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    DosenDemoData data, {
    String route = 'jadwal_dosen',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DosenAcademicScreen(data: data, route: route),
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

  testWidgets('draft can be created, activated, rostered, and archived', (
    tester,
  ) async {
    final demo = source(DemoScenario.populated);
    await pumpScreen(tester, demo);
    final course = find.textContaining('Mata Kuliah Demo').first;
    await scrollTo(tester, course);
    await tester.tap(find.text('Kuliah'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    for (final (index, value) in [
      (0, 'Lifecycle integration topic'),
      (1, '2026-10-20'),
      (2, '10:00'),
      (3, '11:00'),
      (5, 'Synthetic lifecycle test'),
    ]) {
      await tester.enterText(fields.at(index), value);
    }
    await tester.tap(find.text('Simpan Sebagai Draft'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Lifecycle integration topic'));

    final courseRecord = (await demo.read('schedule')).single;
    var drafts = await demo.read('teaching_drafts', item: courseRecord);
    final created = drafts.singleWhere(
      (row) => row['MATERI'] == 'Lifecycle integration topic',
    );
    expect(created['parent_id'], courseRecord['id']);
    expect(created['class_id'], courseRecord['id']);
    expect(created['id'], isNotNull);

    final createdCard = find.ancestor(
      of: find.text('Lifecycle integration topic'),
      matching: find.byType(Card),
    );
    final activate = find.descendant(
      of: createdCard,
      matching: find.text('Mulai Presensi'),
    );
    await scrollTo(tester, activate);
    await tester.tap(activate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konfirmasi'));
    await tester.pumpAndSettle();
    var active = await demo.read('teaching_active', item: courseRecord);
    expect(active, hasLength(1));
    expect(active.single['id'], isNot(equals(created['id'])));
    expect(active.single['parent_id'], courseRecord['id']);
    expect(active.single['class_id'], courseRecord['id']);
    drafts = await demo.read('teaching_drafts', item: courseRecord);
    expect(drafts.any((row) => row['id'] == created['id']), isFalse);

    await tester.tap(find.text('Aktif'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daftar Mahasiswa'));
    await tester.pumpAndSettle();
    // This new meeting has no attendance records. Existing fixture attendance
    // belongs to a different meeting and must not leak into this roster.
    expect(find.text('Daftar Mahasiswa'), findsOneWidget);
    expect(
      find.text('Mohon maaf tidak ada data untuk ditampilkan.'),
      findsOneWidget,
    );
    expect(find.text('DEMO-MHS-001'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Akhiri Presensi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konfirmasi'));
    await tester.pumpAndSettle();
    expect(await demo.read('teaching_active', item: courseRecord), isEmpty);
    final history = await demo.read('teaching_history', item: courseRecord);
    expect(history, hasLength(2));
    expect(history.any((row) => row['id'] == active.single['id']), isFalse);
    final archived = history.singleWhere(
      (row) => row['MATERI'] == 'Lifecycle integration topic',
    );
    expect(archived['parent_id'], courseRecord['id']);
    expect(archived['class_id'], courseRecord['id']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('schedule filters and calendar selection stay local', (
    tester,
  ) async {
    final demo = source(DemoScenario.populated);
    await pumpScreen(tester, demo);
    expect(find.textContaining('Mata Kuliah Demo').first, findsOneWidget);
    await tester.tap(find.byTooltip('Filter Jadwal Mengajar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('S1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Mata Kuliah Demo').first, findsOneWidget);

    await tester.tap(find.text('Ingatkan'));
    await tester.pumpAndSettle();
    expect(find.text('Kalender Demo'), findsOneWidget);
    await tester.tap(find.text('Tambah Jadwal'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Jadwal demo dipilih secara lokal'),
      findsNothing,
    );
    await tester.tap(find.textContaining('Akun Kalender ke 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah Jadwal'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Jadwal demo dipilih secara lokal'),
      findsOneWidget,
    );
    expect(await demo.read('calendars'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed academic reads show a handled error state', (
    tester,
  ) async {
    final demo = source(DemoScenario.error);
    await pumpScreen(tester, demo);
    await tester.tap(find.byTooltip('Filter Jadwal Mengajar'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Data demo tidak dapat diproses'),
      findsOneWidget,
    );
    expect(find.text('Filter Jadwal Mengajar'), findsNothing);
    expect(find.textContaining('Data tidak dapat dimuat.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
