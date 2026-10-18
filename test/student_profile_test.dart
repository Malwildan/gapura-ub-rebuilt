import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/model/records.dart';
import 'package:gapura_ub/ui/guest/student_profile.dart';

// Synthetic fixtures only; no original account or profile values.
const _profile = <String, dynamic>{
  'NAMA': 'Synthetic Student',
  'ANGKATAN': '2099',
  'STATUS': 'Synthetic Status',
  'FAKULTAS': 'Synthetic Faculty',
  'JURUSAN': 'Synthetic Department',
  'JENJANG': 'Synthetic Level',
  'PROGRAM': 'Synthetic Program',
  'NIM': 'profile-nim-must-not-be-header',
};

Future<void> _show(
  WidgetTester tester, {
  Record profile = _profile,
  Record? user,
  ImageProvider Function(String)? portraitProvider,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(
      textTheme: const TextTheme(bodyLarge: TextStyle(color: Colors.purple)),
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 100),
          child: portraitProvider == null
              ? StudentProfileView(profile: profile, user: user)
              : StudentProfileView(
                  profile: profile,
                  user: user,
                  portraitProvider: portraitProvider,
                ),
        ),
      ),
    ),
  ),
);

List<Text> _texts(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(StudentProfileView),
        matching: find.byType(Text),
      ),
    )
    .toList();

void main() {
  for (final width in [390.0, 1600.0]) {
    testWidgets('portrait stays 30px inside constrained parent at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: const Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: StudentProfileView(profile: _profile),
                ),
              ),
            ),
          ),
        ),
      );
      final parent = tester.getRect(find.byType(StudentProfileView));
      final portrait = tester.getRect(find.byType(Positioned));
      expect(parent.right - portrait.right, 30);
      expect(portrait.width, 100);
      expect(portrait.left, parent.right - 130);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'six exact rows, ordered fields, final divider and recovered style',
    (tester) async {
      await _show(tester);
      final texts = _texts(tester);
      expect(texts.skip(3).map((text) => text.data), [
        'Nama',
        'Synthetic Student',
        'Angkatan:',
        '2099',
        'Status Akademik',
        'Synthetic Status',
        'Fakultas',
        'Synthetic Faculty',
        'Jurusan',
        'Synthetic Department',
        'Jenjang dan Program Studi',
        'Synthetic Level - Synthetic Program',
      ]);
      expect(find.byType(Divider), findsNWidgets(6));
      for (var i = 3; i < texts.length; i += 2) {
        expect(texts[i].style?.fontSize, 12);
        expect(texts[i].style?.color, const Color(0xff636363));
        expect(texts[i + 1].style?.fontSize, 16);
        expect(texts[i + 1].style?.fontWeight, FontWeight.w500);
        expect(texts[i + 1].style?.color, Colors.purple);
        expect(texts[i + 1].textAlign, TextAlign.left);
      }
      final size = MediaQuery.sizeOf(
        tester.element(find.byType(StudentProfileView)),
      );
      final row = tester.widget<Container>(
        find
            .ancestor(of: find.text('Nama'), matching: find.byType(Container))
            .first,
      );
      expect(row.constraints?.maxWidth, size.width);
      expect(
        row.padding,
        EdgeInsets.fromLTRB(
          size.height / 50,
          size.height / 50,
          size.height / 50,
          0,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('null values stay empty; join preserves its literal separator', (
    tester,
  ) async {
    await _show(tester, profile: const {'NAMA': null, 'JENJANG': null});
    expect(_texts(tester).map((text) => text.data), [
      'MAHASISWA UB',
      '',
      '',
      'Nama',
      '',
      'Angkatan:',
      '',
      'Status Akademik',
      '',
      'Fakultas',
      '',
      'Jurusan',
      '',
      'Jenjang dan Program Studi',
      ' - ',
    ]);
    await _show(tester, profile: const {'PROGRAM': 'Synthetic Program'});
    expect(find.text(' - Synthetic Program'), findsOneWidget);
    await _show(tester, profile: const {'JENJANG': 'Synthetic Level'});
    expect(find.text('Synthetic Level - '), findsOneWidget);
  });

  testWidgets('header uses user nim/email and updates when inputs refresh', (
    tester,
  ) async {
    await _show(
      tester,
      user: const {
        'nim': 'synthetic-user-nim',
        'email': 'synthetic@example.invalid',
        'displayname': 'Wrong Header Source',
        'username': 'Wrong Username Source',
      },
    );
    expect(_texts(tester).take(3).map((text) => text.data), [
      'MAHASISWA UB',
      'synthetic-user-nim',
      'synthetic@example.invalid',
    ]);
    expect(find.text('profile-nim-must-not-be-header'), findsNothing);
    expect(find.text('Wrong Header Source'), findsNothing);
    expect(find.text('Wrong Username Source'), findsNothing);
    final position = tester.widget<Positioned>(find.byType(Positioned));
    expect(position.top, -60);
    expect(position.left, isNull);
    expect(position.right, 30);
    await _show(tester, profile: const {'NAMA': 'Refreshed Synthetic Student'});
    expect(find.text('Synthetic Student'), findsNothing);
    expect(find.text('Refreshed Synthetic Student'), findsOneWidget);
    expect(_texts(tester).take(3).map((text) => text.data), [
      'MAHASISWA UB',
      '',
      '',
    ]);
  });

  testWidgets('portrait uses FILE_FOTO unchanged and no invented fallback', (
    tester,
  ) async {
    final urls = <String>[];
    final image = MemoryImage(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    ImageProvider provider(String url) {
      urls.add(url);
      return image;
    }

    for (final photo in [null, '', '  ']) {
      await _show(
        tester,
        profile: {'FILE_FOTO': photo},
        portraitProvider: provider,
      );
    }
    expect(urls, isEmpty);
    const photo = 'https://example.invalid/synthetic-photo.png';
    await _show(
      tester,
      profile: const {'FILE_FOTO': photo},
      portraitProvider: provider,
    );
    await tester.pumpAndSettle();
    expect(urls, [photo]);
    final portrait = tester
        .widgetList<Container>(find.byType(Container))
        .singleWhere(
          (container) =>
              container.decoration is BoxDecoration &&
              (container.decoration! as BoxDecoration).image != null,
        );
    final decoration = portrait.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.image?.image, image);
    expect(decoration.image?.alignment, Alignment.topCenter);
    expect(decoration.image?.fit, BoxFit.cover);
    final surround = tester
        .widgetList<Container>(find.byType(Container))
        .singleWhere((container) => container.constraints?.maxWidth == 100);
    expect(surround.constraints?.maxHeight, 100);
    expect(surround.padding, const EdgeInsets.all(3));
    expect(tester.takeException(), isNull);
  });
}
