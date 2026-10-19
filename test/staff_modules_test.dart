import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/demo/demo_app.dart';
import 'package:gapura_ub/demo/demo_session.dart';
import 'package:gapura_ub/demo/staff_modules.dart';
import 'package:gapura_ub/demo/tax_document.dart';
import 'package:gapura_ub/model/records.dart';
import 'package:gapura_ub/service/demo_document_export.dart';
import 'package:gapura_ub/ui/employee/income_tax_screen.dart';

void main() {
  test(
    'staff fixtures enforce role/resource gates and selected periods',
    () async {
      final source = DemoStaffModules(
        DemoSession(
          role: DemoRole.staff,
          scenario: DemoScenario.populated,
          delay: Duration.zero,
        ),
      );
      await expectLater(source.read('personnel.sister'), throwsStateError);
      await expectLater(
        source.read('attendanceSubmit'),
        throwsUnsupportedError,
      );
      final rows = await source.read('income.reports', year: 2024, month: 2);
      expect((rows.single['fields'] as Map)['Periode'], '2024-02');
      final document = (await source.read(
        'income.documents',
        year: 2023,
      )).single;
      expect(document['year'], 2023);
      expect(document['synthetic'], true);
      expect(source.requests, ['income.reports', 'income.documents']);
      for (final role in [DemoRole.guest, DemoRole.student, DemoRole.parent]) {
        final other = DemoStaffModules(
          DemoSession(
            role: role,
            scenario: DemoScenario.populated,
            delay: Duration.zero,
          ),
        );
        await expectLater(
          other.read('personnel.profile'),
          throwsUnsupportedError,
        );
        expect(other.requests, isEmpty);
      }
    },
  );

  test('staff empty/error/loading scenarios remain distinct', () async {
    DemoStaffModules source(DemoScenario scenario) => DemoStaffModules(
      DemoSession(
        role: DemoRole.staff,
        scenario: scenario,
        delay: Duration.zero,
      ),
    );
    expect(await source(DemoScenario.empty).read('remuneration.tgp'), isEmpty);
    await expectLater(
      source(DemoScenario.error).read('remuneration.tgp'),
      throwsStateError,
    );
    var resolved = false;
    source(
      DemoScenario.loading,
    ).read('remuneration.tgp').then((_) => resolved = true);
    await Future<void>.delayed(Duration.zero);
    expect(resolved, false);
  });

  test(
    'synthetic PDF contains a valid cross-reference table and selected year',
    () {
      final doc = DemoTaxDocument({
        'id': 'DEMO-TAX-2024',
        'year': 2024,
        'synthetic': true,
      });
      final pdf = ascii.decode(doc.bytes);
      expect(pdf.startsWith('%PDF-1.4'), true);
      expect(pdf, contains('DEMO - DATA SINTETIS'));
      expect(pdf, contains('Tahun: 2024'));
      final start = RegExp(r'startxref\n(\d+)').firstMatch(pdf)!;
      final offset = int.parse(start.group(1)!);
      expect(pdf.substring(offset).startsWith('xref\n0 6\n'), true);
      final objectOffsets = RegExp(
        r'^(\d{10}) 00000 n',
        multiLine: true,
      ).allMatches(pdf).toList();
      expect(objectOffsets, hasLength(5));
      for (var i = 0; i < objectOffsets.length; i++) {
        expect(
          pdf
              .substring(int.parse(objectOffsets[i].group(1)!))
              .startsWith('${i + 1} 0 obj'),
          true,
        );
      }
      expect(
        () => DemoTaxDocument({'id': 'real-document', 'year': 2024}),
        throwsFormatException,
      );
    },
  );

  test('Android export passes bytes and reports cancellation', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('gapura_ub/demo_documents');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final doc = DemoTaxDocument({
      'id': 'DEMO-TAX-2024',
      'year': 2024,
      'synthetic': true,
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'savePdf');
      expect(call.arguments['filename'], doc.filename);
      expect(call.arguments['bytes'], doc.bytes);
      return false;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await expectLater(
      saveDemoDocument(doc.bytes, doc.filename),
      throwsStateError,
    );
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('Tendik Menu 2–5, details and demo label at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Future<void> pause() => tester.pumpAndSettle();
      Future<void> tap(String label) async {
        await tester.ensureVisible(find.text(label).last);
        await tester.tap(find.text(label).last);
        await tester.pump();
        await pause();
      }

      Future<void> back() async {
        await tester.pageBack();
        await pause();
      }

      await tester.pumpWidget(
        const GapuraDemoApp(initialRole: DemoRole.staff, delay: Duration.zero),
      );
      await pause();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text('Menu'),
        ),
      );
      await pause();
      await tap('Kepegawaian');
      expect(find.text('Demo Tendik'), findsOneWidget);
      await tap('SISTER');
      expect(find.text('Data tidak tersedia'), findsOneWidget);
      await tap('Riwayat');
      await tap('Keluarga');
      expect(find.text('Demo Keluarga'), findsOneWidget);
      expect(find.text('Demo lokal · data sintetis'), findsOneWidget);
      await back();
      await back();
      await tap('Remunerasi');
      expect(find.text('Rp 3.000.000 (sintetis)'), findsOneWidget);
      await tap('TGP');
      await tap('Potongan');
      expect(find.text('Contoh Faktor Kurang sintetis'), findsOneWidget);
      await back();
      await back();
      await tap('Pendapatan & PPh21');
      expect(find.text('Netto'), findsOneWidget);
      await tap('Bukti Potong');
      await tap('TINJAU');
      expect(find.text('Pratinjau dokumen sintetis'), findsOneWidget);
      expect(find.text('Demo lokal · data sintetis'), findsOneWidget);
      await back();
      await back();
      await tap('Layanan Perpustakaan');
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('E-Library UB (Android)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('changing year invalidates pending reads in hidden income tabs', (
    tester,
  ) async {
    final previous = Completer<List<Record>>();
    final now = DateTime.now().year;
    final calls = <(String, int?)>[];
    Future<List<Record>> read(
      String resource, {
      int? year,
      int? month,
      String? category,
      Record? item,
    }) {
      calls.add((resource, year));
      if (resource == 'income.reports' && year == now) return previous.future;
      return Future.value([
        {
          'id': 'doc-$year',
          'title': 'Data $year',
          'fields': {'Bruto': 'Rp 1'},
        },
      ]);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: IncomeTaxScreen(
          read: read,
          openDocument: (_, {required download}) async {},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Bukti Potong'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Tahun').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('${now - 1}').last);
    await tester.pump(const Duration(milliseconds: 500));
    previous.complete([
      {
        'title': 'Stale year',
        'fields': {'Bruto': 'Rp 999'},
      },
    ]);
    await tester.pump();
    await tester.tap(find.text('Pendapatan'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Stale year'), findsNothing);
    expect(find.text('Data ${now - 1}'), findsOneWidget);
    expect(
      calls.where((call) => call.$1 == 'income.documents' && call.$2 == now),
      hasLength(1),
    );
    expect(calls.last, ('income.reports', now - 1));
  });
}
