import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/model/records.dart';
import 'package:gapura_ub/ui/employee/remuneration_screen.dart';

void main() {
  for (final detail in [
    (
      'TGP',
      'remuneration.tgp',
      'remuneration.deductions',
      'Potongan',
      'Faktor Kurang',
    ),
    (
      'Insentif Kinerja',
      'remuneration.incentive',
      'remuneration.activities',
      'Lihat Rincian',
      'Nilai CKP',
    ),
  ]) {
    testWidgets('empty ${detail.$3} can reload without leaving the detail', (
      tester,
    ) async {
      var reads = 0;
      Future<List<Record>> reader(
        String resource, {
        int? year,
        int? month,
        String? category,
        Record? item,
      }) async {
        if (resource == detail.$2) {
          return [
            {'title': 'Periode sintetis'},
          ];
        }
        if (resource == detail.$3 && ++reads > 1) {
          return [
            {
              'title': 'Rincian tersedia',
              'section': detail.$5,
              'fields': {'Keterangan': 'Hasil pemuatan ulang'},
            },
          ];
        }
        return [];
      }

      await tester.pumpWidget(
        MaterialApp(home: RemunerationScreen(read: reader)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(detail.$1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(detail.$4));
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(
        find.text('Mohon maaf data Remunerasi Anda masih belum ada.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Muat Ulang'));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('Rincian tersedia'), findsOneWidget);
      expect(find.text('Hasil pemuatan ulang'), findsOneWidget);
    });
  }

  testWidgets(
    'shows the five tabs and requests the selected year after filtering',
    (tester) async {
      final calls = <(String, int?)>[];
      Future<List<Record>> reader(
        String resource, {
        int? year,
        int? month,
        String? category,
        Record? item,
      }) async {
        calls.add((resource, year));
        if (resource == 'remuneration.profile') {
          return [
            {
              'title': 'Jabatan',
              'fields': {'Posisi': 'Staf'},
            },
          ];
        }
        if (resource == 'remuneration.tgp') {
          return [
            {
              'title': 'Periode TGP',
              'fields': {'Tahun': '$year'},
            },
          ];
        }
        return [];
      }

      await tester.pumpWidget(
        MaterialApp(home: RemunerationScreen(read: reader)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('TGP'), findsOneWidget);
      expect(find.text('Insentif Kinerja'), findsOneWidget);
      expect(find.text('Insentif Tambahan'), findsOneWidget);
      expect(find.text('Remunerasi 13'), findsOneWidget);
      final originalYear = DateTime.now().year;
      expect(
        calls.where((call) => call.$1 == 'remuneration.tgp').single.$2,
        originalYear,
      );

      await tester.tap(find.text('TGP'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pilih Tahun'));
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .onChanged!(originalYear - 1);
      await tester.pump();
      await tester.tap(find.text('Filter'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.$1 == 'remuneration.tgp').last.$2,
        originalYear - 1,
      );
      expect(find.text('Tahun'), findsOneWidget);
    },
  );

  testWidgets('opens TGP deduction detail with the selected record and year', (
    tester,
  ) async {
    String? detailResource;
    Record? detailItem;
    int? detailYear;
    Future<List<Record>> reader(
      String resource, {
      int? year,
      int? month,
      String? category,
      Record? item,
    }) async {
      if (resource == 'remuneration.tgp') {
        return [
          {
            'title': 'Periode Januari',
            'fields': {'Jumlah': 'Tertera pada data'},
          },
        ];
      }
      if (resource == 'remuneration.deductions') {
        detailResource = resource;
        detailItem = item;
        detailYear = year;
        return [
          {
            'title': 'Keterlambatan',
            'category': 'Faktor Kurang',
            'fields': {'Keterangan': 'Contoh'},
          },
        ];
      }
      return [];
    }

    await tester.pumpWidget(
      MaterialApp(home: RemunerationScreen(read: reader)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('TGP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Potongan'));
    await tester.pumpAndSettle();
    expect(detailResource, 'remuneration.deductions');
    expect(detailYear, DateTime.now().year);
    expect(detailItem?['title'], 'Periode Januari');
    expect(find.text('Faktor Kurang'), findsOneWidget);
    expect(find.text('Keterlambatan'), findsOneWidget);
  });
}
