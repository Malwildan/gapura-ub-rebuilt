import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/demo/demo_app.dart';
import 'package:gapura_ub/demo/demo_session.dart';
import 'package:gapura_ub/ui/dosen/dosen_module.dart';

void main() {
  Future<void> phoneViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.text('Menu').last);
    await tester.pumpAndSettle();
  }

  Future<void> choose<T>(WidgetTester tester, Type type, String label) async {
    await tester.tap(find.byType(type).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('lecturer menu reaches recovered routes, Pendapa and profile', (
    tester,
  ) async {
    await phoneViewport(tester);
    await tester.pumpWidget(
      const GapuraDemoApp(initialRole: DemoRole.lecturer, delay: Duration.zero),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beranda'), findsWidgets);
    expect(find.text('Pendapa'), findsOneWidget);
    await openMenu(tester);
    expect(find.text('Jadwal Mengajar'), findsOneWidget);
    expect(find.text('Bimbingan Akademik'), findsOneWidget);
    expect(find.text('Statistik Publikasi'), findsOneWidget);
    await tester.tap(find.text('Jadwal Mengajar'));
    await tester.pumpAndSettle();
    expect(find.text('SEN'), findsOneWidget);
    expect(find.textContaining('Mata Kuliah Demo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pendapa').last);
    await tester.pumpAndSettle();
    expect(find.text('Pendapa'), findsWidgets);
    expect(find.text('Surat Masuk'), findsOneWidget);

    await tester.tap(find.text('Profil').last);
    await tester.pumpAndSettle();
    expect(find.text('Profil Saya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'scenario change from an open DOSEN route replaces the route with fresh data',
    (tester) async {
      await phoneViewport(tester);
      await tester.pumpWidget(
        const GapuraDemoApp(
          initialRole: DemoRole.lecturer,
          delay: Duration.zero,
        ),
      );
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.text('Presensi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tugas'));
      await tester.pumpAndSettle();
      expect(find.text('Siapkan materi demo'), findsOneWidget);
      await tester.tap(find.text('Tambah Tugas'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Tugas dari sesi sebelumnya',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Tugas dari sesi sebelumnya'), findsOneWidget);

      // Scenario selection while the pushed route is open returns to a fresh root.
      await choose<DemoScenario>(
        tester,
        DropdownButtonFormField<DemoScenario>,
        'Kosong',
      );
      expect(find.byType(DosenModuleScreen), findsNothing);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Demo lokal · data sintetis'), findsOneWidget);
      await openMenu(tester);
      await tester.tap(find.text('Presensi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tugas'));
      await tester.pumpAndSettle();
      expect(find.text('Siapkan materi demo'), findsNothing);
      expect(find.text('Tidak ada data.'), findsOneWidget);

      await choose<DemoScenario>(
        tester,
        DropdownButtonFormField<DemoScenario>,
        'Berisi',
      );
      expect(find.byType(DosenModuleScreen), findsNothing);
      await openMenu(tester);
      await tester.tap(find.text('Presensi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tugas'));
      await tester.pumpAndSettle();
      expect(find.text('Siapkan materi demo'), findsOneWidget);
      expect(find.text('Tugas dari sesi sebelumnya'), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'role change from an open DOSEN route removes lecturer-only destinations',
    (tester) async {
      await phoneViewport(tester);
      await tester.pumpWidget(
        const GapuraDemoApp(
          initialRole: DemoRole.lecturer,
          delay: Duration.zero,
        ),
      );
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.text('Jadwal Mengajar'));
      await tester.pumpAndSettle();
      expect(find.text('SEN'), findsOneWidget);

      await choose<DemoRole>(
        tester,
        DropdownButtonFormField<DemoRole>,
        'Tendik',
      );
      expect(find.byType(DosenModuleScreen), findsNothing);
      expect(find.text('SEN'), findsNothing);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Demo lokal · data sintetis'), findsOneWidget);
      await openMenu(tester);
      expect(find.text('Jadwal Mengajar'), findsNothing);
      expect(find.text('Presensi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
