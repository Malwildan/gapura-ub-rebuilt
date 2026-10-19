import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/model/records.dart';
import 'package:gapura_ub/ui/employee/income_tax_screen.dart';

void main() {
  testWidgets('shows income fields and passes selected year and month', (
    tester,
  ) async {
    final calls = <({String resource, int? year, int? month})>[];
    Future<List<Record>> read(
      String resource, {
      int? year,
      int? month,
      String? category,
      Record? item,
    }) async {
      calls.add((resource: resource, year: year, month: month));
      return [
        {
          'title': 'Oktober',
          'fields': {
            'Bruto': 'Rp 10.000',
            'Pajak': 'Rp 1.000',
            'Tabungan Pajak': 'Rp 0',
            'Zakat': 'Rp 0',
            'Netto': 'Rp 9.000',
          },
        },
      ];
    }

    await tester.pumpWidget(
      MaterialApp(
        home: IncomeTaxScreen(
          read: read,
          openDocument: (_, {required download}) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rekap Pendapatan & PPh21'), findsOneWidget);
    expect(find.text('Bruto'), findsOneWidget);
    await tester.tap(find.text('Tahun - Bulan').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('${DateTime.now().year - 1}').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    expect(calls.last.resource, 'income.reports');
    expect(calls.last.year, DateTime.now().year - 1);
    expect(calls.last.month, DateTime.now().month);
  });

  testWidgets('shows loading, retryable error, and empty state', (
    tester,
  ) async {
    final pending = Completer<List<Record>>();
    var attempts = 0;
    Future<List<Record>> read(
      String resource, {
      int? year,
      int? month,
      String? category,
      Record? item,
    }) {
      attempts++;
      if (attempts == 1) return pending.future;
      if (attempts == 2) {
        return Future.error(StateError('Sumber belum tersedia'));
      }
      return Future.value([]);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: IncomeTaxScreen(
          read: read,
          openDocument: (_, {required download}) async {},
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('Sumber belum tersedia'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sumber belum tersedia'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sumber belum tersedia'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Data belum tersedia.'), findsOneWidget);
  });

  testWidgets(
    'document actions pass the selected row and preview/download intent',
    (tester) async {
      final calls = <({Record row, bool download})>[];
      Future<List<Record>> read(
        String resource, {
        int? year,
        int? month,
        String? category,
        Record? item,
      }) async => resource == 'income.documents'
          ? [
              {'id': 'doc-1', 'title': 'PPh21 2025', 'source': 'opaque'},
            ]
          : [];

      await tester.pumpWidget(
        MaterialApp(
          home: IncomeTaxScreen(
            read: read,
            openDocument: (row, {required download}) async =>
                calls.add((row: row, download: download)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Bukti Potong'));
      await tester.pumpAndSettle();
      expect(find.text('Dokumen PDF'), findsOneWidget);
      await tester.tap(find.text('TINJAU'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('UNDUH'));
      await tester.pumpAndSettle();
      expect(calls.map((call) => call.download), [false, true]);
      expect(calls.first.row['source'], 'opaque');
    },
  );

  testWidgets('ignores an older response after changing the income period', (
    tester,
  ) async {
    final first = Completer<List<Record>>();
    final received = <Completer<List<Record>>>[];
    var count = 0;
    Future<List<Record>> read(
      String resource, {
      int? year,
      int? month,
      String? category,
      Record? item,
    }) {
      if (resource != 'income.reports') return Future.value([]);
      count++;
      if (count == 1) return first.future;
      final next = Completer<List<Record>>();
      received.add(next);
      return next.future;
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
    await tester.tap(find.text('Tahun - Bulan').first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('${DateTime.now().year - 1}').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Filter'));
    await tester.pump(const Duration(milliseconds: 400));
    received.last.complete([
      {
        'title': 'Terbaru',
        'fields': {'Bruto': 'Rp 2'},
      },
    ]);
    await tester.pump(const Duration(milliseconds: 400));
    first.complete([
      {
        'title': 'Kedaluwarsa',
        'fields': {'Bruto': 'Rp 1'},
      },
    ]);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Terbaru'), findsOneWidget);
    expect(find.text('Kedaluwarsa'), findsNothing);
  });
}
