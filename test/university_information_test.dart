import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/model/university_information.dart';
import 'package:gapura_ub/ui/guest/university_information.dart';

void main() {
  final evidence =
      jsonDecode(
            File('test/fixtures/university_information.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final pools = <int, String>{
    for (final rows in (evidence['public_literals'] as Map).values)
      for (final literal in rows as List)
        literal['pool_slot'] as int: literal['value'] as String,
  };

  test('all faculty and facility fields retain evidence order and values', () {
    final faculties = evidence['faculty_rows'] as List;
    expect(universityFaculties, hasLength(18));
    for (var i = 0; i < faculties.length; i++) {
      final fields = faculties[i]['fields'];
      final actual = universityFaculties[i];
      expect(actual.title, fields['title@3']['value']);
      expect(actual.website, fields['website@7']['value']);
      expect(actual.colorHex, fields['color_hex@0xb']['value']);
      expect(
        actual.colorArgb,
        int.parse('ff${actual.colorHex.substring(1)}', radix: 16),
      );
    }
    final facilities = evidence['facility_rows'] as List;
    expect(universityFacilities, hasLength(10));
    for (var i = 0; i < facilities.length; i++) {
      final fields = facilities[i]['fields'];
      final actual = universityFacilities[i];
      expect(actual.title, fields['title@3']['value']);
      expect(actual.subtitle, fields['subtitle@7']['value']);
      expect(actual.thumbnailUrl, fields['thumbnail_url@0xb']['value']);
      expect(actual.website, fields['website@0xf']['value']);
    }
  });

  test('seven historical officials retain every field in display order', () {
    final rows = evidence['officials_in_display_order'] as List;
    expect(universityOfficials, hasLength(7));
    for (var i = 0; i < rows.length; i++) {
      final fields = <String, String>{
        for (final field in rows[i]['fields'])
          (field['immediate_store']['instruction'] as String)
                  .split('#')[1]
                  .split(']')[0]:
              field['value'] as String,
      };
      final actual = universityOfficials[i];
      expect(actual.ordinal, i + 1);
      expect(
        [
          actual.role,
          actual.name,
          actual.phone,
          actual.office,
          actual.address,
          actual.education,
          actual.portraitUrl,
        ],
        [
          for (final offset in [
            '0xb',
            '0xf',
            '0x13',
            '0x17',
            '0x1b',
            '0x1f',
            '0x23',
          ])
            fields[offset],
        ],
      );
      expect(actual.degrees, [
        for (final offset in ['0x27', '0x2b', '0x2f'])
          if (fields.containsKey(offset)) fields[offset],
      ]);
    }
    expect(universityOfficialsHeroUrl, pools[15312]);
  });

  test(
    'all bundled prose, section order, bullets and emblem cells are exact',
    () {
      expect(universityOverviewSections.map((s) => s.title), [
        'Visi',
        'Misi',
        'Tujuan',
        'Sasaran',
      ]);
      expect(universityOverviewSections.map((s) => s.paragraphs.length), [
        1,
        2,
        3,
        7,
      ]);
      expect(universityOverviewSections.map((s) => s.bulleted), [
        false,
        true,
        true,
        true,
      ]);
      expect(universityOverviewSections.expand((s) => s.paragraphs), [
        for (final slot in [
          15240,
          15242,
          15245,
          15247,
          15248,
          15249,
          ...List.generate(7, (i) => 15251 + i),
        ])
          pools[slot],
      ]);
      expect(universityHistoryText, pools[15287]);
      expect(universityHistoryText.length, 5693);
      expect(universityHistoryText.startsWith('\n'), isTrue);
      expect(universityEmblemRows, [
        for (var i = 15263; i <= 15270; i++) pools[i],
      ]);
      expect(
        universityEmblemRows.map((r) => r.split('*').length),
        everyElement(2),
      );
      expect(universityEmblemRows[5].startsWith('6.*akra'), isTrue);
      expect(universityLogoAsset, pools[15260]);
      expect(
        [
          for (final page in [
            'overview',
            'faculty',
            'officials',
            'facility',
            'university_history',
            'lambang',
          ])
            universityInformationTitle(page),
        ],
        [
          pools[15237],
          'Fakultas dan Program',
          pools[15311],
          'Fasilitas',
          pools[15285],
          pools[15259],
        ],
      );
      expect(universityInformationTitle('news'), isNull);
    },
  );

  Future<void> showPage(
    WidgetTester tester,
    String page, {
    ValueChanged<String>? onTitleChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              UniversityInformationView(
                page: page,
                onTitleChanged: onTitleChanged,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'overview and history render unedited prose inside parent scrolling',
    (tester) async {
      await showPage(tester, 'overview');
      expect(find.byType(Card), findsNWidgets(4));
      expect(find.text('•  '), findsNWidgets(12));
      for (final section in universityOverviewSections) {
        expect(find.text(section.title), findsOneWidget);
        for (final paragraph in section.paragraphs) {
          expect(find.text(paragraph), findsOneWidget);
        }
      }
      await showPage(tester, 'university_history');
      expect(find.text(universityHistoryHeading), findsOneWidget);
      expect(find.text(universityHistoryText), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('faculty tap exposes original failure and sends title update', (
    tester,
  ) async {
    String? title;
    await showPage(tester, 'faculty', onTitleChanged: (value) => title = value);
    expect(find.byType(Card), findsNWidgets(18));
    final colors = tester
        .widgetList<CircleAvatar>(find.byType(CircleAvatar))
        .map((w) => w.backgroundColor);
    expect(colors, universityFaculties.map((f) => Color(f.colorArgb)));
    await tester.tap(find.text(universityFaculties.first.title));
    await tester.pump();
    expect(title, universityFeedError);
    expect(find.text(universityFeedError), findsOneWidget);
    await showPage(tester, 'overview');
    expect(find.text(universityFeedError), findsNothing);
  });

  testWidgets(
    'facility thumbnails use exact URLs and handle fixture failures; tap fails',
    (tester) async {
      // Flutter widget tests return HTTP 400; no live image request is made.
      await showPage(tester, 'facility');
      expect(find.byType(Card), findsNWidgets(10));
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(
        images.map((i) => (i.image as NetworkImage).url),
        universityFacilities.map((f) => f.thumbnailUrl),
      );
      expect(
        images.map((i) => (i.image as NetworkImage).webHtmlElementStrategy),
        everyElement(WebHtmlElementStrategy.prefer),
      );
      for (final image in images) {
        expect((image.image as NetworkImage).headers, isNull);
      }
      expect(find.byIcon(Icons.broken_image_outlined), findsWidgets);
      await tester.tap(find.text(universityFacilities.first.title));
      await tester.pump();
      expect(find.text(universityFeedError), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'historical official dialog opens with original details and closes',
    (tester) async {
      await showPage(tester, 'officials');
      expect(find.byType(Card), findsNWidgets(7));
      final hero = tester.widget<Image>(find.byType(Image));
      expect((hero.image as NetworkImage).url, universityOfficialsHeroUrl);
      final official = universityOfficials.first;
      await tester.tap(find.text(official.name));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      final dialog = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Text),
      );
      final text = tester.widgetList<Text>(dialog).map((t) => t.data);
      expect(
        text,
        containsAll([
          official.name,
          official.role,
          official.phone,
          'Rektorat UB',
          official.address,
          official.education,
          'Kembali',
        ]),
      );
      final portrait = tester.widget<Image>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Image),
        ),
      );
      expect((portrait.image as NetworkImage).url, official.portraitUrl);
      expect(find.byIcon(Icons.broken_image_outlined), findsWidgets);
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('emblem uses bundled asset and eight split table rows', (
    tester,
  ) async {
    await showPage(tester, 'lambang');
    expect(
      (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName,
      universityLogoAsset,
    );
    expect(tester.widget<Table>(find.byType(Table)).children, hasLength(8));
    for (final row in universityEmblemRows) {
      for (final cell in row.split('*')) {
        expect(find.text(cell), findsOneWidget);
      }
    }
    expect(tester.takeException(), isNull);
  });
}
