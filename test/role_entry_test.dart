import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/account_bridge.dart';
import 'package:gapura_ub/app.dart';

class _TrackingAccountBridge extends AccountBridge {
  final actions = <String>[];

  @override
  Future<Map<String, dynamic>> request(
    String action, {
    Map<String, dynamic> parameters = const {},
  }) async {
    actions.add(action);
    return {};
  }
}

void main() {
  testWidgets('all welcome actions fit a short mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const GapuraApp(showWelcome: true));

    for (final label in [
      'MASUK SEBAGAI PENGUNJUNG',
      'MASUK DENGAN AKUN UB',
      'TENDIK',
      'DOSEN',
      'ORTU',
    ]) {
      final rect = tester.getRect(find.text(label));
      expect(rect.top, greaterThanOrEqualTo(0), reason: label);
      expect(rect.bottom, lessThanOrEqualTo(568), reason: label);
    }
  });

  testWidgets('welcome opens a local Tendik session and logout clears it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const GapuraApp(showWelcome: true));
    expect(find.text('Satu Aplikasi\nBanyak Kemudahan'), findsOneWidget);
    expect(find.text('MASUK SEBAGAI PENGUNJUNG'), findsOneWidget);
    expect(find.text('MASUK DENGAN AKUN UB'), findsOneWidget);
    expect(find.text('TENDIK'), findsOneWidget);
    expect(find.text('DOSEN'), findsOneWidget);
    expect(find.text('ORTU'), findsOneWidget);

    await tester.tap(find.text('TENDIK'));
    await tester.pumpAndSettle();
    expect(find.text('Halo, Nadia Kusumawardani'), findsOneWidget);
    final carouselAssets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((image) => image.assetName)
        .toList();
    expect(carouselAssets, contains('assets/img/awards_1.jpg'));
    expect(
      carouselAssets,
      isNot(contains('assets/img/app-logo_gapura-logo.png')),
    );
    expect(
      find.textContaining(
        RegExp(r'demo|sintetis|belum dipulihkan', caseSensitive: false),
      ),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Buka menu'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Keluar dari akun'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Keluar dari akun'));
    await tester.pumpAndSettle();
    expect(find.text('Satu Aplikasi\nBanyak Kemudahan'), findsOneWidget);
    expect(find.text('Halo, Nadia Kusumawardani'), findsNothing);
  });

  testWidgets('guest entry does not restore an existing UB session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final account = _TrackingAccountBridge();
    await tester.pumpWidget(GapuraApp(showWelcome: true, account: account));
    await tester.tap(find.text('MASUK SEBAGAI PENGUNJUNG'));
    await tester.pumpAndSettle();
    expect(account.actions, isEmpty);
    expect(find.textContaining('Halo, Pengunjung'), findsOneWidget);
  });
}
