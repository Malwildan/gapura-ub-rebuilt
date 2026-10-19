import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/ui/employee/personnel_screen.dart';
import 'package:gapura_ub/model/records.dart';

void main() {
  testWidgets(
    'loads profile, keeps Tendik SISTER unavailable, and opens history',
    (tester) async {
      final calls = <String>[];
      Future<List<Record>> read(
        String resource, {
        int? year,
        int? month,
        String? category,
        Record? item,
      }) async {
        calls.add('$resource:$category');
        if (resource == 'personnel.profile') {
          return <Record>[
            {'label': 'Nama', 'value': 'Ayu'},
          ];
        }
        if (resource == 'personnel.history') {
          return <Record>[
            {
              'title': '2024',
              'fields': {'Keterangan': 'Aktif'},
            },
          ];
        }
        return [];
      }

      await tester.pumpWidget(MaterialApp(home: PersonnelScreen(read: read)));
      await tester.pumpAndSettle();
      expect(find.text('Ayu'), findsOneWidget);
      expect(calls, ['personnel.profile:null']);

      await tester.tap(find.text('SISTER'));
      await tester.pumpAndSettle();
      expect(find.text('Data tidak tersedia'), findsOneWidget);
      expect(calls, ['personnel.profile:null']);

      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('history-category-Keluarga')));
      await tester.pumpAndSettle();
      expect(find.text('2024'), findsOneWidget);
      expect(calls.last, 'personnel.history:Keluarga');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Karir'), findsOneWidget);
    },
  );

  testWidgets('shows retry after a read failure', (tester) async {
    var attempts = 0;
    Future<List<Record>> read(
      String resource, {
      int? year,
      int? month,
      String? category,
      Record? item,
    }) async {
      if (attempts++ == 0) throw StateError('offline');
      return <Record>[
        {'label': 'Nama', 'value': 'Bima'},
      ];
    }

    await tester.pumpWidget(MaterialApp(home: PersonnelScreen(read: read)));
    await tester.pumpAndSettle();
    expect(find.text('Data belum dapat dimuat.'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Bima'), findsOneWidget);
  });

  testWidgets('ignores a late result after the screen is removed', (
    tester,
  ) async {
    final pending = Completer<List<Record>>();
    Future<List<Record>> read(
      String resource, {
      int? year,
      int? month,
      String? category,
      Record? item,
    }) => pending.future;
    await tester.pumpWidget(MaterialApp(home: PersonnelScreen(read: read)));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(<Record>[
      {'label': 'Nama', 'value': 'Terlambat'},
    ]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
