import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/demo/demo_session.dart';
import 'package:gapura_ub/demo/dosen_data.dart';
import 'package:gapura_ub/ui/dosen/dosen_pendapa.dart';

void main() {
  DosenDemoData data([DemoScenario scenario = DemoScenario.populated]) =>
      DosenDemoData(
        DemoSession(
          role: DemoRole.lecturer,
          scenario: scenario,
          delay: Duration.zero,
        ),
      );

  Future<void> mount(WidgetTester tester, DosenDemoData source) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: DosenPendapaView(data: source)));
    await tester.pumpAndSettle();
  }

  Future<void> confirmForm(WidgetTester tester) async {
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Konfirmasi'));
    await tester.pumpAndSettle();
  }

  testWidgets('Pendapa shows the eight destinations in recovered order', (
    tester,
  ) async {
    await mount(tester, data());
    final labels = DosenPendapaView.destinations.map((e) => e.label).toList();
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(labels, [
      'Kalender',
      'Surat Tugas',
      'Surat Masuk',
      'Paraf Surat Keluar',
      'Tanda tangan',
      'Riwayat Surat Masuk',
      'Riwayat Surat Keluar',
      'Arsip',
    ]);
  });

  testWidgets('calendar event opens detail and outgoing history has two tabs', (
    tester,
  ) async {
    await mount(tester, data());
    await tester.tap(find.text('Kalender'));
    await tester.pumpAndSettle();
    expect(find.text('Kalender Anda'), findsOneWidget);
    for (final day in ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min']) {
      expect(find.text(day), findsOneWidget);
    }
    final now = DateTime.now();
    final monthDelta = (2026 - now.year) * 12 + (10 - now.month);
    final direction = monthDelta < 0 ? Icons.chevron_left : Icons.chevron_right;
    for (var i = 0; i < monthDelta.abs(); i++) {
      await tester.tap(find.byIcon(direction));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Surat demo untuk diproses'));
    await tester.pumpAndSettle();
    expect(find.text('Informasi Surat'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Riwayat Surat Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Riwayat TTE Anda'), findsOneWidget);
    expect(find.text('Paraf'), findsOneWidget);
    expect(find.text('Tanda tangan'), findsOneWidget);
    await tester.tap(find.text('Tanda tangan').last);
    await tester.pumpAndSettle();
    expect(find.text('Riwayat Tanda tangan'), findsOneWidget);
  });

  testWidgets('task rows open detail and batch archive guards empty selection', (
    tester,
  ) async {
    final source = data();
    await mount(tester, source);
    await tester.tap(find.text('Surat Tugas'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO-001/UB/2026'), findsOneWidget);
    await tester.tap(find.text('DEMO-001/UB/2026'));
    await tester.pumpAndSettle();
    expect(find.text('Informasi Surat'), findsOneWidget);
    expect(find.text('Judul Surat'), findsOneWidget);
    await tester.tap(find.text('Lampiran demo.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('Pratinjau Dokumen'), findsOneWidget);
    expect(
      find.text(
        'Pratinjau sintetis lokal. Tidak ada berkas yang diunduh atau dibuka.',
      ),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pratinjau dokumen'));
    await tester.pumpAndSettle();
    expect(find.text('Pratinjau Dokumen'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Timeline'));
    await tester.pumpAndSettle();
    expect(find.text('Timeline Surat'), findsOneWidget);
    expect(find.text('Diterima (demo)'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Surat Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arsipkan'));
    await tester.pump();
    expect(
      find.text('Pilih setidaknya satu surat terlebih dahulu.'),
      findsOneWidget,
    );
  });

  testWidgets('Paraf submission updates local queue and creates history', (
    tester,
  ) async {
    final source = data();
    await mount(tester, source);
    await tester.tap(find.text('Paraf Surat Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEMO-001/UB/2026'));
    await tester.pumpAndSettle();
    expect(find.text('Paraf / Verifikasi Surat'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(6), 'DEMO-NIK-SECRET');
    await tester.enterText(
      find.byType(TextFormField).at(7),
      'DEMO-PASSPHRASE-SECRET',
    );
    await confirmForm(tester);
    expect(
      (await source.read('pendapa_paraf')).single['processed_locally'],
      isTrue,
    );
    expect((await source.read('pendapa_paraf_history')).length, 2);
    expect(
      (await source.read('document_detail')).single['notugas'],
      'DEMO-001/UB/2026',
    );
    expect(
      (await source.read('pendapa_paraf')).single,
      isNot(contains('passphrase_demo')),
    );
    expect(
      (await source.read('pendapa_paraf')).single,
      isNot(contains('nik_tte_demo')),
    );
    expect(
      (await source.read('pendapa_paraf')).single.values,
      isNot(contains('DEMO-NIK-SECRET')),
    );
    expect(
      (await source.read('pendapa_paraf_history')).last.values,
      isNot(contains('DEMO-PASSPHRASE-SECRET')),
    );
    await tester.pumpAndSettle();
    expect(find.text('DEMO-001/UB/2026'), findsNothing);
  });

  testWidgets('incoming and TTE rows open their distinct single-record forms', (
    tester,
  ) async {
    await mount(tester, data());
    await tester.tap(find.text('Surat Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEMO-001/UB/2026'));
    await tester.pumpAndSettle();
    expect(find.text('Paraf / Verifikasi Surat'), findsOneWidget);
    expect(find.text('Disposisi'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tanda tangan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEMO-001/UB/2026'));
    await tester.pumpAndSettle();
    expect(find.text('Validasi dan TTE'), findsOneWidget);
    expect(find.text('NIK TTE'), findsOneWidget);
    expect(find.text('Passphrase'), findsOneWidget);
    expect(find.text('Buka pratinjau sintetis'), findsOneWidget);
  });

  testWidgets('single selected item still opens the batch Paraf form', (
    tester,
  ) async {
    await mount(tester, data());
    await tester.tap(find.text('Paraf Surat Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('Paraf multiple'));
    await tester.pumpAndSettle();
    expect(find.text('Paraf Surat Multiple'), findsOneWidget);
  });

  testWidgets('TTE batch confirmation appends history and refreshes queue', (
    tester,
  ) async {
    final source = data();
    await mount(tester, source);
    await tester.tap(find.text('Tanda tangan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('TTE multiple'));
    await tester.pumpAndSettle();
    expect(find.text('TTE Multiple Surat'), findsOneWidget);
    await confirmForm(tester);
    expect(
      (await source.read('pendapa_tte')).single['processed_locally'],
      isTrue,
    );
    expect((await source.read('pendapa_tte_history')).length, 2);
    await tester.pumpAndSettle();
    expect(find.text('DEMO-001/UB/2026'), findsNothing);
  });

  testWidgets('batch archive moves selected records into local archive', (
    tester,
  ) async {
    final source = data();
    await mount(tester, source);
    await tester.tap(find.text('Surat Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('Arsipkan'));
    await tester.pumpAndSettle();
    expect(find.text('Arsipkan Surat Multiple'), findsOneWidget);
    await confirmForm(tester);
    expect(
      (await source.read('pendapa_incoming')).single['processed_locally'],
      isTrue,
    );
    expect((await source.read('pendapa_archive')).length, 2);
    await tester.pumpAndSettle();
    expect(find.text('DEMO-001/UB/2026'), findsNothing);
  });
}
