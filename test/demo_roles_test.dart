import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/common/features.dart';
import 'package:gapura_ub/demo/demo_adapters.dart';
import 'package:gapura_ub/demo/demo_app.dart';
import 'package:gapura_ub/demo/demo_session.dart';
import 'package:gapura_ub/model/records.dart';
import 'package:gapura_ub/model/news_feed.dart';

Future<void> tab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> choose(WidgetTester tester, String key, String label) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text(label).last);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  test('public role menu fixture matches labels, routes and artwork', () {
    final fixture = jsonDecode(
      File('test/fixtures/demo_role_menus.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final menus = fixture['menus'] as Map<String, dynamic>;
    for (final entry in {
      'mahasiswa': studentMenuFeatures,
      'ortu': studentMenuFeatures.where((item) => item.id != 'attendance'),
      'tendik': employeeMenuFeatures,
      'dosen': lecturerMenuFeatures,
    }.entries) {
      final expected = (menus[entry.key]['items'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final actual = entry.value
          .map((item) => {
                'label': item.label,
                'route': item.originalRoute ?? item.id,
                'asset': 'assets/${item.asset}',
              })
          .toList();
      expect(actual, expected, reason: entry.key);
    }
  });

  test(
    'Synthetic boundaries reject unsupported access and isolate writes',
    () async {
      DemoSession session(
        DemoRole role, [
        DemoScenario mode = DemoScenario.populated,
      ]) => DemoSession(role: role, scenario: mode, delay: Duration.zero);
      final parent = DemoAccount(session(DemoRole.parent));
      await expectLater(parent.request('attendanceSubmit'), throwsStateError);
      await expectLater(parent.request('surveySubmit'), throwsStateError);
      await expectLater(parent.request('unknown'), throwsUnsupportedError);
      await expectLater(
        DemoAccount(session(DemoRole.staff)).request('schedule'),
        throwsUnsupportedError,
      );
      await expectLater(
        DemoAccount(session(DemoRole.guest)).request('profile'),
        throwsStateError,
      );
      final student = DemoAccount(session(DemoRole.student));
      await student.request(
        'attendanceSubmit',
        parameters: {
          'confirmed': true,
          'meeting': 'DEMO-MEETING',
          'status': 'H',
          'mode': '0',
        },
      );
      expect(student.attendance, 'H');
      expect(DemoAccount(session(DemoRole.student)).attendance, isEmpty);
      expect(parent.attendance, isEmpty);
      expect(
        records(
          await DemoAccount(
            session(DemoRole.parent, DemoScenario.empty),
          ).request('finance'),
          'tagihan',
        ),
        isEmpty,
      );
      await expectLater(
        DemoAccount(
          session(DemoRole.parent, DemoScenario.error),
        ).request('schedule'),
        throwsStateError,
      );
      final service = DemoService(session(DemoRole.parent));
      addTearDown(service.close);
      for (final feed in NewsFeed.tabs) {
        final rows = await service.newsFeed(feed);
        expect(rows.single['title'], contains('Demo'));
        expect(rows.single['link'], isEmpty);
      }
      expect(
        (await service.notifications('demo.parent')).single['body'],
        contains('Orangtua'),
      );
    },
  );

  for (final role in DemoRole.values) {
    for (final mode in DemoScenario.values) {
      testWidgets(
        '${role.name}/${mode.name}: role tabs and state remain usable',
        (tester) async {
          tester.view.physicalSize = const Size(360, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            GapuraDemoApp(
              initialRole: role,
              initialScenario: mode,
              delay: Duration.zero,
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Demo lokal · data sintetis'), findsOneWidget);
          final bar = tester.widget<BottomNavigationBar>(
            find.byType(BottomNavigationBar),
          );
          expect(
            bar.items.map((item) => item.label).toList(),
            role == DemoRole.guest
                ? ['Beranda', 'Berita']
                : role.employee
                ? ['Beranda', 'Pendapa', 'Menu', 'Berita', 'Profil']
                : ['Beranda', 'Menu', 'Berita', 'Profil'],
          );
          if (role != DemoRole.guest) {
            await tab(tester, 'Menu');
            expect(
              find.text('Presensi Kelas'),
              role == DemoRole.student ? findsOneWidget : findsNothing,
            );
            if (role.academic) {
              await tester.tap(find.text('Biaya Kuliah'));
              await tester.pump(const Duration(milliseconds: 400));
              switch (mode) {
                case DemoScenario.populated:
                  expect(find.text('UKT Demo'), findsOneWidget);
                case DemoScenario.empty:
                  expect(
                    find.text('Belum ada data biaya kuliah.'),
                    findsOneWidget,
                  );
                case DemoScenario.error:
                  expect(
                    find.textContaining('Simulasi gagal memuat data'),
                    findsOneWidget,
                  );
                case DemoScenario.loading:
                  expect(
                    find.byType(CircularProgressIndicator),
                    findsOneWidget,
                  );
              }
            } else {
              await tester.tap(find.text('Kepegawaian'));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
              expect(find.text('Data Diri'), findsOneWidget);
              expect(find.text('SISTER'), findsOneWidget);
              expect(find.text('Riwayat'), findsOneWidget);
              expect(find.text('Demo lokal · data sintetis'), findsOneWidget);
            }
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final width in [360.0, 1280.0]) {
    testWidgets('Ortu six destinations and shared tabs at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const GapuraDemoApp(initialRole: DemoRole.parent, delay: Duration.zero),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tab(tester, 'Menu');
      for (final feature in studentMenuFeatures.where(
        (f) => f.id != 'attendance',
      )) {
        await tester.ensureVisible(find.text(feature.label));
        await tester.tap(find.text(feature.label));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byTooltip('Kembali'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: feature.id);
        await tester.tap(find.byTooltip('Kembali'));
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tab(tester, 'Berita');
      expect(find.byType(Tab), findsNWidgets(6));
      await tab(tester, 'Profil');
      expect(
        find.textContaining('Tampilan ini belum direkonstruksi.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Notifikasi'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Notifikasi Demo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Role/state switches discard navigation and pending readers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const GapuraDemoApp(
        initialRole: DemoRole.parent,
        initialScenario: DemoScenario.loading,
        delay: Duration.zero,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tab(tester, 'Menu');
    await tester.tap(find.text('Biaya Kuliah'));
    await tester.pump(const Duration(milliseconds: 400));
    await choose(tester, 'demo-role-parent', 'Tendik');
    expect(find.byTooltip('Kembali'), findsNothing);
    await tab(tester, 'Menu');
    expect(find.text('Biaya Kuliah'), findsNothing);
    expect(find.text('Kepegawaian'), findsOneWidget);
    await choose(tester, 'demo-role-staff', 'Orangtua');
    await choose(tester, 'demo-scenario-loading', 'Berisi');
    await tab(tester, 'Menu');
    await tester.tap(find.text('Biaya Kuliah'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('UKT Demo'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await choose(tester, 'demo-role-parent', 'Pengunjung');
    expect(find.byTooltip('Notifikasi'), findsNothing);
    expect(find.text('UKT Demo'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
