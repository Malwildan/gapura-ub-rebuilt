import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/model/general_announcement.dart';
import 'package:gapura_ub/widget/general_announcement_banner.dart';

// Synthetic dates and text only. No SDK or live content is used here.
final now = DateTime(2099, 1, 2);
final inverted = GeneralAnnouncement(
  title: 'Synthetic inverted interval',
  content: '<b>Raw synthetic content</b>',
  startDate: DateTime(2099, 1, 3),
  endDate: DateTime(2099, 1, 1),
);
final ordinary = GeneralAnnouncement(
  title: 'Synthetic ordinary interval',
  content: 'Second synthetic row',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 1, 3),
);

Future<void> showBanner(WidgetTester tester, List<GeneralAnnouncement>? rows) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GeneralAnnouncementBanner(
            announcements: rows,
            clock: () => now,
          ),
        ),
      ),
    );

void main() {
  test(
    'preserves inverted date predicate and a fresh clock for each comparison',
    () {
      expect(announcementVisibilityCount([ordinary], clock: () => now), 0);
      expect(announcementVisibilityCount([inverted], clock: () => now), 1);
      var calls = 0;
      expect(
        announcementVisibilityCount(
          [GeneralAnnouncement(startDate: now, endDate: now)],
          clock: () {
            calls++;
            return now;
          },
        ),
        1,
      );
      expect(calls, 4);
    },
  );

  testWidgets(
    'null/empty/current ordinary lists never open a dialog automatically',
    (tester) async {
      for (final rows in <List<GeneralAnnouncement>?>[
        null,
        [],
        [ordinary],
      ]) {
        await showBanner(tester, rows);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ListTile), findsNothing);
      }
    },
  );

  testWidgets(
    'missing date hides the banner as an explicit failure accommodation',
    (tester) async {
      await showBanner(tester, [
        inverted,
        const GeneralAnnouncement(title: 'Missing date'),
      ]);
      expect(find.byType(ListTile), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tap shows complete ordered list, raw text and original date format',
    (tester) async {
      await showBanner(tester, [inverted, ordinary]);
      expect(find.text('2 pengumuman penting'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('2 pengumuman penting'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Synthetic inverted interval'), findsOneWidget);
      expect(find.text('Synthetic ordinary interval'), findsOneWidget);
      expect(find.text('<b>Raw synthetic content</b>'), findsOneWidget);
      expect(find.text('3 January 2099 - 1 January 2099'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Synthetic inverted interval')).dy,
        lessThan(
          tester.getTopLeft(find.text('Synthetic ordinary interval')).dy,
        ),
      );
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('2 pengumuman penting'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
