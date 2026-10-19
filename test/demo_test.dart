import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/demo/demo_adapters.dart';
import 'package:gapura_ub/demo/demo_app.dart';
import 'package:gapura_ub/demo/demo_session.dart';
import 'package:gapura_ub/model/news_feed.dart';
import 'package:gapura_ub/model/student_attendance.dart';

DemoSession session(
  DemoRole role, [
  DemoScenario state = DemoScenario.populated,
]) => DemoSession(role: role, scenario: state, delay: Duration.zero);

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
}

Future<void> selectRole(WidgetTester tester, DemoRole role) async {
  final loading = tester.widget<DropdownButtonFormField<DemoScenario>>(
    find.byType(DropdownButtonFormField<DemoScenario>),
  ).initialValue == DemoScenario.loading;
  tester
      .widget<DropdownButtonFormField<DemoRole>>(
        find.byType(DropdownButtonFormField<DemoRole>),
      )
      .onChanged!(role);
  if (loading) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  } else {
    await settle(tester);
  }
}

Future<void> selectScenario(WidgetTester tester, DemoScenario scenario) async {
  tester
      .widget<DropdownButtonFormField<DemoScenario>>(
        find.byType(DropdownButtonFormField<DemoScenario>),
      )
      .onChanged!(scenario);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  if (scenario != DemoScenario.loading) await tester.pumpAndSettle();
}

Future<void> menu(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Menu'),
    ),
  );
  await settle(tester);
}

void main() {
  test(
    'synthetic adapters distinguish empty/failure and local writes',
    () async {
      final account = DemoAccount(session(DemoRole.student));
      final first = await account.request('attendanceMeetings');
      expect(attendanceRows(first, 'output').single['K_ABSENSI'], '');
      await account.request(
        'attendanceSubmit',
        parameters: {
          'confirmed': true,
          'meeting': 'DEMO-MEETING',
          'status': 'H',
          'mode': '0',
        },
      );
      expect(
        attendanceRows(
          await account.request('attendanceMeetings'),
          'output',
        ).single['K_ABSENSI'],
        'H',
      );
      expect(
        attendanceRows(
          await DemoAccount(
            session(DemoRole.student),
          ).request('attendanceMeetings'),
          'output',
        ).single['K_ABSENSI'],
        '',
      );
      await expectLater(
        DemoAccount(session(DemoRole.parent)).request('attendanceSubmit'),
        throwsStateError,
      );
      await expectLater(
        DemoAccount(session(DemoRole.staff)).request('schedule'),
        throwsUnsupportedError,
      );
      final empty = DemoService(session(DemoRole.guest, DemoScenario.empty));
      final failure = DemoService(session(DemoRole.guest, DemoScenario.error));
      addTearDown(empty.close);
      addTearDown(failure.close);
      expect(await empty.newsFeed(NewsFeed.official), isEmpty);
      await expectLater(failure.newsFeed(NewsFeed.official), throwsStateError);
    },
  );

  for (final width in [360.0, 1280.0]) {
    testWidgets('role navigation and menu boundaries at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const GapuraDemoApp(delay: Duration.zero));
      await settle(tester);
      for (final role in DemoRole.values) {
        await selectRole(tester, role);
        final bar = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(
          bar.items.map((item) => item.label),
          role == DemoRole.guest
              ? ['Beranda', 'Berita']
              : role.employee
              ? ['Beranda', 'Pendapa', 'Menu', 'Berita', 'Profil']
              : ['Beranda', 'Menu', 'Berita', 'Profil'],
        );
        if (role == DemoRole.guest) {
          expect(find.byTooltip('Notifikasi'), findsNothing);
        } else {
          await menu(tester);
          if (role.employee) {
            expect(find.text('Kepegawaian'), findsOneWidget);
            expect(find.text('Presensi Kelas'), findsNothing);
            expect(
              find.text('Jadwal Mengajar'),
              role == DemoRole.lecturer ? findsOneWidget : findsNothing,
            );
            await tester.tap(find.text('Kepegawaian'));
            await settle(tester);
            expect(find.text('Data Diri'), findsOneWidget);
            expect(find.text('SISTER'), findsOneWidget);
            expect(find.text('Riwayat'), findsOneWidget);
            await tester.pageBack();
            await settle(tester);
          } else {
            expect(find.text('Biaya Kuliah'), findsOneWidget);
            expect(
              find.text('Presensi Kelas'),
              role == DemoRole.student ? findsOneWidget : findsNothing,
            );
          }
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets(
    'changing data state remounts pending requests and clears navigation',
    (tester) async {
      await tester.pumpWidget(const GapuraDemoApp(delay: Duration.zero));
      await settle(tester);
      await menu(tester);
      await tester.tap(find.text('Biaya Kuliah'));
      await settle(tester);
      expect(find.text('UKT Demo'), findsOneWidget);
      await selectScenario(tester, DemoScenario.loading);
      expect(find.text('UKT Demo'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await selectRole(tester, DemoRole.staff);
      // Role switch preserves the selected loading scenario until changed.
      await selectScenario(tester, DemoScenario.populated);
      await menu(tester);
      expect(find.text('Kepegawaian'), findsOneWidget);
      expect(find.text('UKT Demo'), findsNothing);
      await selectScenario(tester, DemoScenario.error);
      expect(find.textContaining('Simulasi gagal memuat data'), findsWidgets);
      await selectScenario(tester, DemoScenario.empty);
      expect(find.textContaining('Simulasi gagal memuat data'), findsNothing);
      expect(find.text('Tidak ada berita untuk saat ini.'), findsWidgets);
      await selectScenario(tester, DemoScenario.populated);
      expect(find.textContaining('Berita Demo'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('public remote illustrations use local demo placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      const GapuraDemoApp(initialRole: DemoRole.guest, delay: Duration.zero),
    );
    await settle(tester);
      await tester.drag(find.byType(RefreshIndicator).first, const Offset(0, -700));
      await tester.pumpAndSettle();
    await tester.tap(find.text('Pimpinan'));
    await settle(tester);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is NetworkImage,
      ),
      findsNothing,
    );
    expect(find.byIcon(Icons.image_outlined), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
