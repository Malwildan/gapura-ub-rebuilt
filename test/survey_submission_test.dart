import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/account_bridge_native.dart';
import 'package:gapura_ub/service/survey_submission.dart';
import 'package:gapura_ub/widget/student_attendance.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'account_bridge_native_test.dart' show MemorySessionStore, TestAppAuth;

Map<String, dynamic> status(Object? flag) => {
  'output': {
    'data': [
      {'STAT_ISI': flag},
    ],
  },
};
List<Map<String, dynamic>> form() => [
  for (final id in ['Q2', 'Q1'])
    {
      'K_PERTANYAAN': id,
      'PERTANYAAN': '<p>Sintetis & ? # = + % \u00e9 \u5065\u5eb7 ($id)</p>',
      'JAWABAN': {
        'JAWABAN_LIST': [
          {
            'K_JAWABAN': 'A$id',
            'JAWABAN': 'Pilihan $id',
            'IS_KETERANGAN': '1',
            'REDIRECT_LINK': 'https://example.invalid',
          },
          {'K_JAWABAN': 'B$id', 'JAWABAN': 'Lain $id', 'IS_KETERANGAN': '0'},
        ],
      },
    },
];
Map<String, dynamic> questions(List<Map<String, dynamic>> rows) => {
  'status': 'true',
  'output': {'data': rows},
};
Map<String, dynamic> save() => {
  'status': 'true',
  'err_msg': '',
  'output': {
    'data': [
      {
        'ERRSTATE': 'arbitrary',
        'MESSAGE': 'Synthetic response',
        'ELAPSED_TIME': '0',
      },
    ],
  },
};
Map<String, dynamic> params() => {
  'confirmed': true,
  'questions': surveySnapshot(form()),
  'answers': [
    for (final q in form())
      {
        'question': q['K_PERTANYAAN'],
        'answer': 'A${q['K_PERTANYAAN']}',
        'explanation': '\u00e9 \u5065\u5eb7 &x=?#+% , ()',
      },
  ],
};
MemorySessionStore store({bool expired = false}) =>
    MemorySessionStore()
      ..record = {
        'accessToken': 'SYNTHETIC',
        'refreshToken': 'fixture-refresh',
        'expiresAt': DateTime.now()
            .add(Duration(hours: expired ? -1 : 1))
            .millisecondsSinceEpoch,
      };

void main() {
  setUp(() {
    surveySubmissionGuard.inFlight = false;
    surveySubmissionGuard.unknown = false;
  });
  test(
    'Native fixed GET, one encoded value, raw server text and returned order; Bearer only',
    () async {
      final calls = <http.Request>[];
      final bridge = AccountBridge(
        store: store(),
        client: MockClient((r) async {
          calls.add(r);
          expect(r.method, 'GET');
          expect(r.body, isEmpty);
          expect(r.followRedirects, false);
          expect(r.headers['Authorization'], 'Bearer SYNTHETIC');
          expect(
            r.headers.keys.where(
              (k) =>
                  ['token', 'client-id', 'device-id'].contains(k.toLowerCase()),
            ),
            isEmpty,
          );
          final body = r.url.path.contains('cekStatus')
              ? status('0')
              : r.url.path.contains('getPertanyaan')
              ? questions(form())
              : save();
          return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
        }),
      );
      final result = await bridge.request('surveySubmit', parameters: params());
      expect(surveySaveMessage(result), 'Synthetic response');
      expect(calls.map((r) => r.url.path), [
        '/mahasiswa/index/cekStatusSurveyHarian/',
        '/mahasiswa/index/getPertanyaanSurvey/',
        '/mahasiswa/index/insSurveyKesehatanBulk/',
      ]);
      final uri = calls.last.url;
      expect(uri.queryParameters.keys, ['data_all']);
      expect(
        uri.queryParameters['data_all'],
        form()
            .map(
              (q) =>
                  '("${q['K_PERTANYAAN']}", "${q['PERTANYAAN']}", "A${q['K_PERTANYAAN']}", "\u00e9 \u5065\u5eb7 &x=?#+% , ()")',
            )
            .join(','),
      );
      expect(uri.fragment, isEmpty);
    },
  );
  test(
    'Invalid caller parameters rejected before token refresh or transport',
    () async {
      final auth = TestAppAuth();
      var calls = 0;
      final bridge = AccountBridge(
        store: store(expired: true),
        appAuth: auth,
        client: MockClient((r) async {
          calls++;
          throw StateError('unexpected');
        }),
      );
      final missing = params();
      (missing['answers'] as List)[0]['answer'] = null;
      final forged = params();
      (forged['answers'] as List)[0]['answer'] = 'FORGED';
      for (final p in [
        {...params(), 'confirmed': false},
        {...params(), 'url': 'https://example.invalid'},
        missing,
        forged,
      ]) {
        await expectLater(
          bridge.request('surveySubmit', parameters: p),
          throwsStateError,
        );
      }
      expect(auth.refreshCalls, 0);
      expect(calls, 0);
    },
  );
  for (final value in ['"', '\\', '\n', '\r', '\t', '\x00', '\x1f', '\x7f']) {
    test('Unsupported tuple character rejected: ${value.codeUnits}', () async {
      for (final field in ['question', 'answer', 'explanation']) {
        final p = params();
        (p['answers'] as List)[0][field] = value;
        expect(() => validateSurveySubmission(p), throwsStateError);
      }
      final rows = form();
      rows[0]['PERTANYAAN'] = value;
      var writes = 0;
      await expectLater(
        submitHealthSurvey(
          parameters: params(),
          read: (path, q) async =>
              path.contains('cekStatus') ? status('0') : questions(rows),
          write: (p, q) async {
            writes++;
            return save();
          },
        ),
        throwsStateError,
      );
      expect(writes, 0);
    });
  }
  for (final change in [
    'order',
    'question',
    'answer',
    'metadata',
    'empty',
    'duplicate',
  ]) {
    test('Fresh form change $change cannot reuse selections', () async {
      var rows = form();
      if (change == 'order') rows = rows.reversed.toList();
      if (change == 'question') {
        rows[0]['PERTANYAAN'] = 'Changed';
      }
      if (change == 'answer') {
        ((rows[0]['JAWABAN'] as Map)['JAWABAN_LIST'] as List)[0]['K_JAWABAN'] =
            'NEW';
      }
      if (change == 'metadata') {
        ((rows[0]['JAWABAN'] as Map)['JAWABAN_LIST']
                as List)[0]['IS_KETERANGAN'] =
            '0';
      }
      if (change == 'empty') rows = [];
      if (change == 'duplicate') rows = [rows.first, rows.first];
      var writes = 0;
      await expectLater(
        submitHealthSurvey(
          parameters: params(),
          read: (p, q) async =>
              p.contains('cekStatus') ? status('0') : questions(rows),
          write: (p, q) async {
            writes++;
            return save();
          },
        ),
        throwsStateError,
      );
      expect(writes, 0);
    });
  }
  for (final flag in ['1', 1, true, null]) {
    test('Preflight status $flag cannot dispatch', () async {
      var reads = 0, writes = 0;
      await expectLater(
        submitHealthSurvey(
          parameters: params(),
          read: (p, q) async {
            reads++;
            return status(flag);
          },
          write: (p, q) async {
            writes++;
            return save();
          },
        ),
        throwsStateError,
      );
      expect(reads, 1);
      expect(writes, 0);
    });
  }
  test(
    'Global across bridge/auth contexts, no retry, unknown requires explicit valid status reload',
    () async {
      var writes = 0, reads = 0;
      final pending = Completer<http.Response>();
      final client = MockClient((r) async {
        if (r.url.path.contains('insSurvey')) {
          writes++;
          return pending.future;
        }
        reads++;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode(
              r.url.path.contains('cekStatus')
                  ? status('0')
                  : questions(form()),
            ),
          ),
          200,
        );
      });
      final a = AccountBridge(store: store(), client: client),
          b = AccountBridge(store: store(), client: client);
      final first = a.request('surveySubmit', parameters: params());
      for (var i = 0; i < 30 && writes == 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      await expectLater(
        b.request('surveySubmit', parameters: params()),
        throwsStateError,
      );
      // A status read while a write is pending cannot unlock the guard.
      await b.request('surveyStatus');
      pending.completeError(TimeoutException('PRIVATE_URL_ANSWERS_TOKEN'));
      await expectLater(
        first,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'safe error',
            surveyUnknown,
          ),
        ),
      );
      final count = reads;
      await expectLater(
        b.request('surveySubmit', parameters: params()),
        throwsStateError,
      );
      expect(writes, 1);
      expect(reads, count);
      await b.request('surveyStatus');
      expect(surveySubmissionGuard.unknown, false);
    },
  );
  test(
    'Malformed save response becomes unknown without exposing payload',
    () async {
      await expectLater(
        submitHealthSurvey(
          parameters: params(),
          read: (p, q) async =>
              p.contains('cekStatus') ? status('0') : questions(form()),
          write: (p, q) async => {'PRIVATE': 'SECRET'},
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'safe error',
            surveyUnknown,
          ),
        ),
      );
      expect(surveySubmissionGuard.unknown, true);
      surveySubmissionGuard.statusRead(status(1));
      expect(surveySubmissionGuard.unknown, true);
    },
  );
  test(
    'Status read started before failed write cannot unlock a later retry',
    () async {
      final pendingWrite = Completer<http.Response>(),
          pendingStatus = Completer<http.Response>();
      var writes = 0, holdStatus = false;
      final bridge = AccountBridge(
        store: store(),
        client: MockClient((r) async {
          if (r.url.path.contains('insSurvey')) {
            writes++;
            return pendingWrite.future;
          }
          if (holdStatus && r.url.path.contains('cekStatus')) {
            return pendingStatus.future;
          }
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(
                r.url.path.contains('cekStatus')
                    ? status('0')
                    : questions(form()),
              ),
            ),
            200,
          );
        }),
      );
      final first = bridge.request('surveySubmit', parameters: params());
      for (var i = 0; i < 30 && writes == 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      holdStatus = true;
      final staleRead = bridge.request('surveyStatus');
      pendingWrite.completeError(TimeoutException('SYNTHETIC'));
      await expectLater(first, throwsStateError);
      pendingStatus.complete(http.Response(jsonEncode(status('0')), 200));
      await staleRead;
      expect(surveySubmissionGuard.unknown, true);
      await expectLater(
        bridge.request('surveySubmit', parameters: params()),
        throwsStateError,
      );
      expect(writes, 1);
      holdStatus = false;
      await bridge.request('surveyStatus');
      expect(surveySubmissionGuard.unknown, false);
    },
  );

  testWidgets(
    'User selections only, explanation retained across changes, cancel does nothing, save only reloads status',
    (tester) async {
      final calls = <String>[];
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StudentAttendance(
                request: (a, p) async {
                  calls.add(a);
                  if (a == 'surveyStatus') return status('0');
                  if (a == 'surveyQuestions') return questions(form());
                  if (a == 'surveySubmit') {
                    sent = p;
                    return save();
                  }
                  throw StateError('Attendance must remain blocked');
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Kirim Jawaban'),
            )
            .onPressed,
        isNull,
      );
      Future<void> choose(int i, String label) async {
        await tester.tap(find.byType(DropdownButton<int>).at(i));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await choose(0, 'Pilihan Q2');
      await tester.enterText(
        find.byType(TextField).first,
        'Synthetic explanation',
      );
      await choose(
        0,
        'Lain Q2',
      ); // hidden explanation must survive, original controller semantics
      await choose(1, 'Pilihan Q1');
      await tester.ensureVisible(find.text('Kirim Jawaban'));
      await tester.tap(find.text('Kirim Jawaban'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(calls, ['surveyStatus', 'surveyQuestions']);
      await tester.tap(find.text('Kirim Jawaban'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kirim'));
      await tester.pumpAndSettle();
      expect(calls, [
        'surveyStatus',
        'surveyQuestions',
        'surveySubmit',
        'surveyStatus',
        'surveyQuestions',
      ]);
      expect((sent!['answers'] as List)[0], {
        'question': 'Q2',
        'answer': 'BQ2',
        'explanation': 'Synthetic explanation',
      });
      expect(find.text('HADIR'), findsNothing);
      expect(
        tester
            .widget<DropdownButton<int>>(find.byType(DropdownButton<int>).first)
            .value,
        isNull,
      );
    },
  );
}
