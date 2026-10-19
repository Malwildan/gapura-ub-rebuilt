import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/demo/demo_session.dart';
import 'package:gapura_ub/demo/dosen_data.dart';
import 'package:gapura_ub/ui/dosen/dosen_attendance.dart';

void main() {
  DosenDemoData source([DemoScenario scenario = DemoScenario.populated]) =>
      DosenDemoData(
        DemoSession(
          role: DemoRole.lecturer,
          scenario: scenario,
          delay: Duration.zero,
        ),
      );
  Future<void> pump(WidgetTester tester, DosenDemoData data) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DosenAttendanceScreen(data: data)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yakin'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'staff survey presence gate saves local answers before attendance',
    (tester) async {
      final data = source();
      final survey = (await data.read('survey')).single;
      await data.save('survey', {...survey, 'has_result': false});
      await pump(tester, data);
      expect(find.text('Kirim Jawaban'), findsOneWidget);
      expect(find.text('Tugas'), findsNothing);
      await tester.tap(find.text('Kirim Jawaban'));
      await tester.pumpAndSettle();
      expect((await data.read('survey')).single['has_result'], false);
      await tester.tap(find.byType(RadioListTile<String>));
      await tester.pump();
      await tester.tap(find.text('Kirim Jawaban'));
      await tester.pumpAndSettle();
      expect((await data.read('survey')).single['has_result'], true);
      expect(find.text('Tugas'), findsOneWidget);
    },
  );

  testWidgets('task creation and confirmed deletion update the visible list', (
    tester,
  ) async {
    final data = source();
    await pump(tester, data);
    await tester.tap(find.text('Tugas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah Tugas'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Tugas lokal diuji');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Tugas lokal diuji'), findsOneWidget);
    final card = find.ancestor(
      of: find.text('Tugas lokal diuji'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: card, matching: find.byTooltip('Hapus tugas')),
    );
    await confirm(tester);
    expect(find.text('Tugas lokal diuji'), findsNothing);
    expect(
      (await data.read(
        'tasks',
      )).where((r) => r['TUGAS'] == 'Tugas lokal diuji'),
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('start and finish attendance remain in the synthetic session', (
    tester,
  ) async {
    final data = source();
    await pump(tester, data);
    await tester.ensureVisible(find.text('Mulai Kerja Sekarang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mulai Kerja Sekarang'));
    await confirm(tester);
    expect((await data.read('attendance')).single['demo_started'], true);
    await tester.ensureVisible(find.text('Akhiri Kerja Sekarang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akhiri Kerja Sekarang'));
    await confirm(tester);
    expect((await data.read('attendance')).single['demo_ended'], true);
    expect((await source().read('attendance')).single['demo_started'], isNull);
  });

  testWidgets('history month filtering changes records and can be cleared', (
    tester,
  ) async {
    await pump(tester, source());
    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('2026-10-01'), findsOneWidget);
    final month = find.byType(DropdownButtonFormField<int>).last;
    await tester.tap(month);
    await tester.pumpAndSettle();
    await tester.tap(find.text('9').last);
    await tester.pumpAndSettle();
    expect(find.text('2026-10-01'), findsNothing);
    expect(find.text('Tidak ada data.'), findsOneWidget);
    await tester.tap(month);
    await tester.pumpAndSettle();
    await tester.tap(find.text('10').last);
    await tester.pumpAndSettle();
    expect(find.text('2026-10-01'), findsOneWidget);
  });

  testWidgets('replacing a pending session recovers without old responses', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DosenAttendanceScreen(data: source(DemoScenario.loading)),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await pump(tester, source());
    expect(find.text('Tugas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
