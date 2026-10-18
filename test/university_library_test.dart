import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/main.dart';
import 'package:gapura_ub/model/university_library.dart';
import 'package:gapura_ub/ui/guest/university_library.dart';
import 'package:url_launcher/url_launcher.dart';

import 'widget_test.dart' show FixtureAccount, FixturePublic, openStudentMenu;

class _LibraryPublic extends FixturePublic {
  @override
  Future<List<Map<String, dynamic>>> achievements() async => [];
}

void main() {
  test('all nine ordered records match the retained evidence exactly', () {
    final evidence =
        jsonDecode(File('test/fixtures/university_library.json').readAsStringSync())
            as Map<String, dynamic>;
    final rows = evidence['rows'] as List;
    expect(universityLibraryBaseLinks, hasLength(8));
    expect(universityLibraryLinks, hasLength(9));
    for (var i = 0; i < rows.length; i++) {
      final link = universityLibraryLinks[i];
      expect(link.title, rows[i]['title_at_3']['value']);
      expect(link.url, rows[i]['url_at_7']['value']);
      expect(link.colorHex, rows[i]['color_hex_at_0xb']['value']);
      expect(
        link.colorArgb,
        int.parse('ff${link.colorHex.substring(1)}', radix: 16),
      );
    }
  });

  test('each bundled URI is probed before exact external launch', () async {
    final calls = <String>[];
    final launcher = LibraryExternalLauncher(
      canLaunch: (uri) async {
        calls.add('probe:$uri');
        return true;
      },
      launch: (uri, {required mode, required webOnlyWindowName}) async {
        expect(mode, LaunchMode.externalApplication);
        expect(webOnlyWindowName, '_blank');
        calls.add('launch:$uri');
        return true;
      },
    );
    for (final link in universityLibraryLinks) {
      expect(await launcher.open(link.uri), isTrue);
    }
    expect(calls, [
      for (final link in universityLibraryLinks) ...[
        'probe:${link.url}',
        'launch:${link.url}',
      ],
    ]);
  });

  test('nonbundled targets are rejected before any platform call', () async {
    var probes = 0, launches = 0;
    final launcher = LibraryExternalLauncher(
      canLaunch: (_) async {
        probes++;
        return true;
      },
      launch: (_, {required mode, required webOnlyWindowName}) async {
        launches++;
        return true;
      },
    );
    for (final target in [
      'https://repository.ub.ac.id/',
      'https://lib.ub.ac.id/dashboard-lib/',
      'https://lib.ub.ac.id/dasboard-lib/?token=secret',
      'https://play.google.com/store/apps/details?id=another.package',
      'https://example.com/',
      'javascript:alert(1)',
    ]) {
      expect(await launcher.open(Uri.parse(target)), isFalse);
    }
    expect(probes, 0);
    expect(launches, 0);
  });

  test('failed capability never launches or reports success', () async {
    var launched = false;
    final launcher = LibraryExternalLauncher(
      canLaunch: (_) async => false,
      launch: (_, {required mode, required webOnlyWindowName}) async {
        launched = true;
        return true;
      },
    );
    expect(await launcher.open(universityLibraryLinks.first.uri), isFalse);
    expect(launched, isFalse);
  });

  for (final failProbe in [true, false]) {
    test('platform exception is contained, probe=$failProbe', () async {
      final launcher = LibraryExternalLauncher(
        canLaunch: (_) async {
          if (failProbe) throw PlatformException(code: 'unavailable');
          return true;
        },
        launch: (_, {required mode, required webOnlyWindowName}) async =>
            throw PlatformException(code: 'unavailable'),
      );
      expect(await launcher.open(universityLibraryLinks.first.uri), isFalse);
    });
  }

  test('false launch result remains a failure', () async {
    final launcher = LibraryExternalLauncher(
      canLaunch: (_) async => true,
      launch: (_, {required mode, required webOnlyWindowName}) async => false,
    );
    expect(await launcher.open(universityLibraryLinks.first.uri), isFalse);
  });

  testWidgets('only a tap launches; rebuilds do not load; refresh appends', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<UniversityLibraryViewState>();
    final launched = <Uri>[];
    final launcher = LibraryExternalLauncher(
      canLaunch: (_) async => true,
      launch: (uri, {required mode, required webOnlyWindowName}) async {
        launched.add(uri);
        return false;
      },
    );
    Widget host() => MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text(universityLibraryTitle)),
        body: SingleChildScrollView(
          child: UniversityLibraryView(key: key, launcher: launcher),
        ),
      ),
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(launched, isEmpty);
    expect(find.byType(ListTile), findsNWidgets(9));
    expect(find.byType(TextField), findsNothing);
    for (final link in universityLibraryLinks) {
      await tester.tap(find.text(link.title));
      await tester.pumpAndSettle();
    }
    expect(launched, universityLibraryLinks.map((link) => link.uri));
    expect(find.text(universityLibraryTitle), findsOneWidget);
    expect(find.text('Error Opening Feed.'), findsNothing);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(9));
    await key.currentState!.reload();
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(10));
    await key.currentState!.reload();
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(11));
    expect(find.text('E-Library UB (Android)'), findsNWidgets(3));
    expect(launched, hasLength(9));
  });

  testWidgets('Home library entry and both refresh controls stay local', (
    tester,
  ) async {
    final api = _LibraryPublic();
    final account = FixtureAccount();
    addTearDown(api.close);
    await tester.pumpWidget(GapuraApp(service: api, account: account));
    await tester.pumpAndSettle();
    await openStudentMenu(tester);
    await tester.ensureVisible(find.text('Layanan Perpustakaan'));
    await tester.pumpAndSettle();
    final before = account.requests.length;
    await tester.tap(find.text('Layanan Perpustakaan'));
    await tester.pumpAndSettle();
    expect(find.text(universityLibraryTitle), findsOneWidget);
    final list = find.descendant(
      of: find.byType(UniversityLibraryView),
      matching: find.byType(ListView),
    );
    int count() =>
        (tester.widget<ListView>(list).childrenDelegate
                as SliverChildBuilderDelegate)
            .childCount!;
    expect(count(), 9);
    await tester.tap(find.byTooltip('Muat ulang'));
    await tester.pumpAndSettle();
    expect(count(), 10);
    final outerScroll = find.byType(Scrollable).first;
    await tester.drag(outerScroll, const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(count(), 11);
    expect(account.requests, hasLength(before));
    expect(find.text(universityLibraryTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
