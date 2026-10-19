import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/guest_demo/guest_demo_adapters.dart';
import 'package:gapura_ub/guest_demo/guest_demo_app.dart';
import 'package:gapura_ub/guest_demo/guest_demo_session.dart';
import 'package:gapura_ub/model/general_announcement.dart';
import 'package:gapura_ub/model/university_library.dart';
import 'package:gapura_ub/ui/guest/university_library.dart';
import 'package:gapura_ub/ui/home.dart';
import 'package:gapura_ub/widget/general_announcement_banner.dart';

void main() {
  test('guest service exposes the four synthetic data states', () async {
    final populated = GuestDemoService(
      GuestDemoSession(GuestDemoScenario.populated),
    );
    expect(
      (await populated.latestNews()).single['title'],
      'Berita Terkini Demo',
    );
    populated.close();

    final empty = GuestDemoService(GuestDemoSession(GuestDemoScenario.empty));
    expect(await empty.latestNews(), isEmpty);
    empty.close();

    final failed = GuestDemoService(GuestDemoSession(GuestDemoScenario.error));
    await expectLater(failed.latestNews(), throwsA(isA<StateError>()));
    failed.close();

    final loading = GuestDemoService(
      GuestDemoSession(GuestDemoScenario.loading),
    );
    final pending = loading.latestNews();
    final invalidated = expectLater(pending, throwsA(isA<StateError>()));
    await Future<void>.delayed(Duration.zero);
    loading.close();
    await invalidated;
  });

  test(
    'populated guest announcement matches the recovered visibility rule',
    () async {
      final session = GuestDemoSession(GuestDemoScenario.populated);
      final announcements = await GuestDemoAnnouncements(session).fetch();
      final fixedNow = DateTime(2026, 10, 19);
      expect(
        announcementVisibilityCount([
          GeneralAnnouncement(
            startDate: fixedNow.add(const Duration(days: 1)),
            endDate: fixedNow.subtract(const Duration(days: 1)),
          ),
        ], clock: () => fixedNow),
        1,
      );
      expect(
        announcementVisibilityCount(announcements, clock: () => DateTime.now()),
        1,
      );
      session.close();
    },
  );

  testWidgets('guest navigation is public-only and data changes reset it', (
    tester,
  ) async {
    await tester.pumpWidget(const GapuraGuestDemoApp());
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Berita Terkini'), findsWidgets);
    expect(find.text('Demo lokal · data sintetis'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('1 pengumuman penting'), findsOneWidget);
    expect(
      find.text(
        'Masuk untuk melihat jadwal kuliah, hasil studi, dan layanan mahasiswa Anda.',
      ),
      findsNothing,
    );

    await tester.tap(find.text('Berita').last);
    await tester.pumpAndSettle();
    expect(find.text('Demo lokal · data sintetis'), findsOneWidget);
    expect(find.text('Pilih sumber berita'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('guest-preview-populated')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kosong').last);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Halo, Pengunjung\n'), findsOneWidget);
    expect(find.byKey(const ValueKey('guest-preview-empty')), findsOneWidget);
    expect(find.text('Berita Terkini Demo'), findsNothing);
  });

  testWidgets('guest library taps cannot launch an external URL', (
    tester,
  ) async {
    await tester.pumpWidget(const GapuraGuestDemoApp());
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    final dynamic home = tester.state(find.byType(GapuraHome));
    home.go('library');
    await tester.pumpAndSettle();

    expect(find.byType(UniversityLibraryView), findsOneWidget);
    expect(find.text('Demo lokal · data sintetis'), findsOneWidget);
    final view = tester.widget<UniversityLibraryView>(
      find.byType(UniversityLibraryView),
    );
    expect(
      await view.launcher.canLaunch(universityLibraryLinks.first.uri),
      isFalse,
    );
    expect(await view.launcher.open(universityLibraryLinks.first.uri), isFalse);
    await tester.ensureVisible(find.text(universityLibraryLinks.first.title));
    await tester.tap(find.text(universityLibraryLinks.first.title));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
