import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gapura_ub/services.dart';
import 'package:gapura_ub/widget/achievement_carousel.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class AchievementFixture extends GapuraService {
  @override
  Future<List<Map<String, dynamic>>> achievements() async => [
    {'URL_FILE': '', 'JENIS_GAMBAR': 'First fixture'},
    {'URL_FILE': '', 'JENIS_GAMBAR': 'Second fixture'},
  ];
}

void main() {
  testWidgets('autoplay advances and wraps, then disposes its timer', (
    tester,
  ) async {
    final service = AchievementFixture();
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AchievementCarousel(service: service, onOpen: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Finder selectedDot(int index) => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.selected == true &&
          widget.properties.label == 'Penghargaan $index dari 2',
    );
    expect(selectedDot(1), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 801));
    expect(selectedDot(2), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 801));
    expect(selectedDot(1), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });
  test('achievement selection uses only the original second group', () {
    final rows = achievementRecords([
      {
        'PENGHARGAAN': [
          {'URL_FILE': 'https://ub.ac.id/wrong.png'},
        ],
      },
      {
        'PENGHARGAAN': [
          {'URL_FILE': 'https://ub.ac.id/second.png', 'NO_URUT': '2'},
          {'URL_FILE': 'https://ub.ac.id/first.png', 'NO_URUT': '1'},
        ],
      },
      {
        'LOGO': [
          {'URL_FILE': 'https://ub.ac.id/logo.png'},
        ],
      },
    ]);
    expect(rows.map((row) => row['NO_URUT']), ['2', '1']);
    expect(
      achievementRecords([
        {},
        {'PENGHARGAAN': []},
      ]),
      isEmpty,
    );
    for (final groups in <List<dynamic>>[
      [],
      [{}],
      [
        {},
        {'LOGO': []},
      ],
      [
        {},
        {
          'PENGHARGAAN': [null],
        },
      ],
    ]) {
      expect(() => achievementRecords(groups), throwsFormatException);
    }
  });

  test(
    'native achievement reader preserves the bodyless WS POST',
    () async {
      const configured = String.fromEnvironment('GAPURA_CLIENT_ID');
      if (configured.isEmpty) return;
      final service = GapuraService(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://apigapura.ub.ac.id/WS/GetGambar',
          );
          expect(request.bodyBytes, isEmpty);
          expect(request.headers['Authorization'], '');
          expect(request.headers['Client-Id'], configured);
          return http.Response(
            jsonEncode({
              'GAMBAR': [
                {'LOGO': []},
                {
                  'PENGHARGAAN': [
                    {'URL_FILE': 'https://ub.ac.id/award.png'},
                  ],
                },
              ],
            }),
            200,
          );
        }),
      );
      expect(
        (await service.achievements()).single['URL_FILE'],
        'https://ub.ac.id/award.png',
      );
      service.close();
    },
    skip: const String.fromEnvironment('GAPURA_CLIENT_ID').isEmpty
        ? 'Run with synthetic service defines to exercise the HTTP boundary.'
        : false,
  );
}
