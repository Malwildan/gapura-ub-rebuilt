import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gapura_ub/account_bridge_native.dart';
import 'account_bridge_native_test.dart' show MemorySessionStore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/model/student_attendance.dart';
import 'package:gapura_ub/service/student_attendance.dart';
import 'package:gapura_ub/widget/student_attendance.dart';

Map<String, dynamic> gateBody(dynamic flag) => {
  'output': {
    'data': [
      {'STAT_ISI': flag},
    ],
  },
};
Map<String, dynamic> meetingBody({
  String status = '',
  String id = 'SYNTHETIC-MEETING',
}) => {
  'output': {
    'data': [
      {
        'K_MATERI_AJAR': id,
        'K_ABSENSI': status,
        'MATA_KULIAH': 'Synthetic course',
        'KELAS': 'Z',
        'MATERI': 'Synthetic lesson',
        'KETERANGAN': '',
        'WAKTU_TUTUP': '2031-01-01 12:00:00',
        'IS_DARING': '0',
      },
    ],
  },
};
Map<String, dynamic> choice({
  String status = 'H',
  String mode = '0',
  String meeting = 'SYNTHETIC-MEETING',
}) => {'confirmed': true, 'meeting': meeting, 'status': status, 'mode': mode};

void main() {
  for (final flag in ['1', '0', '', 'true', 1, true, null]) {
    test(
      'Gate preserves exact type and value: $flag (${flag.runtimeType})',
      () {
        expect(
          surveyGate(gateBody(flag)),
          flag == '1'
              ? SurveyGate.complete
              : flag is String
              ? SurveyGate.pending
              : SurveyGate.unknown,
        );
      },
    );
  }
  test('Malformed wrappers fail closed', () {
    for (final body in <Map<String, dynamic>>[
      {},
      {'output': {}},
      {
        'output': {'data': []},
      },
      {
        'output': {
          'data': [null],
        },
      },
    ]) {
      expect(surveyGate(body), SurveyGate.unknown);
    }
    expect(
      attendanceResult({
        'mhs': {
          'data': [
            {'ERRSTATE': 0},
          ],
        },
      }),
      isNull,
    );
    expect(
      attendanceResult({
        'mhs': {
          'data': [
            {'ERRSTATE': '00000'},
          ],
        },
      }),
      '00000',
    );
    expect(attendanceResult({}), isNull);
  });
  for (final selection in [
    choice(),
    choice(mode: '1'),
    choice(status: 'I'),
    choice(status: 'S'),
  ]) {
    test('Verified write maps original callback values $selection', () async {
      final calls = <String>[];
      final result = await submitStudentAttendance(
        parameters: selection,
        profile: () async => {
          'K_FAKULTAS': 'SYNTHETIC-F',
          'K_CABANG': 'SYNTHETIC-B',
        },
        read: (path, query) async {
          calls.add(path);
          if (path.contains('cekStatus')) {
            expect(query, isNull);
            return gateBody('1');
          }
          expect(query, {
            'is_aktif': '1',
            'k_fakultas': 'SYNTHETIC-F',
            'k_cabang': 'SYNTHETIC-B',
          });
          return meetingBody();
        },
        write: (path, query) async {
          calls.add(path);
          expect(path, '/mahasiswa/index/insupdPresensiMhs/');
          expect(query, {
            'k_materi': 'SYNTHETIC-MEETING',
            'k_absensi': selection['status'],
            'keterangan': '',
            'k_fakultas': 'SYNTHETIC-F',
            'k_cabang': 'SYNTHETIC-B',
            'is_daring': selection['mode'],
            'catatan': selection['status'] == 'H' ? '' : 'catatan',
          });
          return {
            'mhs': {
              'data': [
                {'ERRSTATE': '00000'},
              ],
            },
          };
        },
      );
      expect(attendanceResult(result), '00000');
      expect(calls, [
        '/mahasiswa/index/cekStatusSurveyHarian/',
        '/mahasiswa/getDataMateriByMhs/',
        '/mahasiswa/index/cekStatusSurveyHarian/',
        '/mahasiswa/index/insupdPresensiMhs/',
      ]);
    });
  }
  test(
    'Pending, malformed, expired gate, forged and already recorded meetings never write',
    () async {
      for (var scenario = 0; scenario < 7; scenario++) {
        var gates = 0, writes = 0;
        await expectLater(
          submitStudentAttendance(
            parameters: choice(
              meeting: scenario == 3 ? 'FORGED' : 'SYNTHETIC-MEETING',
            ),
            profile: () async =>
                scenario == 6 ? {} : {'K_FAKULTAS': 'F', 'K_CABANG': 'B'},
            read: (path, query) async {
              if (path.contains('cekStatus')) {
                gates++;
                return gateBody(
                  scenario == 0
                      ? '0'
                      : scenario == 1
                      ? 1
                      : scenario == 2 && gates == 2
                      ? '0'
                      : '1',
                );
              }
              return scenario == 5
                  ? {
                      'output': {'data': []},
                    }
                  : meetingBody(status: scenario == 4 ? 'H' : '');
            },
            write: (path, query) async {
              writes++;
              return {};
            },
          ),
          throwsStateError,
        );
        expect(writes, 0);
      }
    },
  );
  test('Unknown write outcome is never retried', () async {
    var writes = 0;
    await expectLater(
      submitStudentAttendance(
        parameters: choice(),
        profile: () async => {'K_FAKULTAS': 'F', 'K_CABANG': 'B'},
        read: (path, query) async =>
            path.contains('cekStatus') ? gateBody('1') : meetingBody(),
        write: (path, query) async {
          writes++;
          throw TimeoutException('Synthetic');
        },
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('belum diketahui'),
        ),
      ),
    );
    expect(writes, 1);
  });
  test(
    'Choice contract rejects alternate notes, statuses, modes, unconfirmed calls',
    () {
      for (final bad in [
        choice(status: 'A'),
        choice(status: 'I', mode: '1'),
        choice(mode: 'true'),
        {...choice(), 'confirmed': false},
        {...choice(), 'url': 'https://example.invalid'},
        choice(meeting: ''),
      ]) {
        expect(() => validateAttendanceChoice(bad), throwsStateError);
      }
    },
  );
  test(
    'Native bridge sends only fixed bodyless Bearer reads and confirmed write',
    () async {
      final store = MemorySessionStore()
        ..record = {
          'accessToken': 'SYNTHETIC-NATIVE-TOKEN',
          'expiresAt': DateTime.now()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
        };
      final calls = <http.Request>[];
      final pending = Completer<http.Response>();
      var pendingWrite = false;
      final bridge = AccountBridge(
        store: store,
        client: MockClient((request) async {
          calls.add(request);
          expect(request.url.host, 'api.ub.ac.id');
          expect(request.body, '');
          expect(request.followRedirects, false);
          expect(
            request.headers['Authorization'],
            'Bearer SYNTHETIC-NATIVE-TOKEN',
          );
          final path = request.url.path;
          if (path.contains('cekStatus')) {
            return http.Response(jsonEncode(gateBody('1')), 200);
          }
          if (path.contains('getBio')) {
            expect(request.method, 'POST');
            return http.Response(
              jsonEncode({
                'mhs': {
                  'data': [
                    {'K_FAKULTAS': 'F', 'K_CABANG': 'B'},
                  ],
                },
              }),
              200,
            );
          }
          expect(request.method, 'GET');
          if (path.contains('getDataMateri')) {
            return http.Response(jsonEncode(meetingBody()), 200);
          }
          expect(path, '/mahasiswa/index/insupdPresensiMhs/');
          expect(request.url.queryParameters, {
            'k_materi': 'SYNTHETIC-MEETING',
            'k_absensi': 'I',
            'keterangan': '',
            'k_fakultas': 'F',
            'k_cabang': 'B',
            'is_daring': '0',
            'catatan': 'catatan',
          });
          if (pendingWrite) return pending.future;
          return http.Response(
            jsonEncode({
              'mhs': {
                'data': [
                  {'ERRSTATE': '00000'},
                ],
              },
            }),
            200,
          );
        }),
      );
      await bridge.request('surveyStatus');
      await bridge.request('attendanceMeetings', parameters: {'active': false});
      expect(calls.where((r) => r.url.path.contains('insupd')), isEmpty);
      expect(calls.last.url.queryParameters['is_aktif'], '0');
      final result = await bridge.request(
        'attendanceSubmit',
        parameters: choice(status: 'I'),
      );
      expect(attendanceResult(result), '00000');
      final count = calls.length;
      await expectLater(
        bridge.request(
          'attendanceSubmit',
          parameters: {...choice(), 'confirmed': false},
        ),
        throwsStateError,
      );
      expect(calls.length, count);
      pendingWrite = true;
      final first = bridge.request(
        'attendanceSubmit',
        parameters: choice(status: 'I'),
      );
      for (
        var i = 0;
        i < 20 && calls.where((r) => r.url.path.contains('insupd')).length < 2;
        i++
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      await expectLater(
        bridge.request('attendanceSubmit', parameters: choice(status: 'I')),
        throwsStateError,
      );
      pending.completeError(TimeoutException('SYNTHETIC'));
      await expectLater(
        first,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('belum diketahui'),
          ),
        ),
      );
      expect(calls.where((r) => r.url.path.contains('insupd')).length, 2);
    },
  );

  for (final result in <Map<String, dynamic>>[
    {},
    {
      'mhs': {
        'data': [
          {'ERRSTATE': 0},
        ],
      },
    },
    {
      'mhs': {
        'data': [
          {'ERRSTATE': '99999'},
        ],
      },
    },
  ]) {
    testWidgets(
      'Malformed/non-success results never reload as success: $result',
      (tester) async {
        final calls = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StudentAttendance(
                  request: (action, parameters) async {
                    calls.add(action);
                    if (action == 'surveyStatus') return gateBody('1');
                    if (action == 'attendanceMeetings') return meetingBody();
                    return result;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('IZIN'));
        await tester.pumpAndSettle();
        expect(find.text('Luring'), findsNothing);
        await tester.tap(find.text('Lanjutkan'));
        await tester.pumpAndSettle();
        expect(calls, [
          'surveyStatus',
          'attendanceMeetings',
          'attendanceSubmit',
        ]);
        expect(find.text('HADIR'), findsNothing);
        expect(find.textContaining('telah tersimpan'), findsNothing);
        expect(find.text('Muat ulang status'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'Pending survey renders genuine dropdowns empty and cannot submit or override',
    (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StudentAttendance(
                request: (action, parameters) async {
                  calls.add(action);
                  if (action == 'surveyStatus') return gateBody('0');
                  return {
                    'status': 'true',
                    'output': {
                      'data': [
                        {
                          'K_PERTANYAAN': 'SYNTHETIC-Q',
                          'PERTANYAAN': '<p>Synthetic question</p>',
                          'JAWABAN': {
                            'JAWABAN_LIST': [
                              {
                                'K_JAWABAN': 'SYNTHETIC-A',
                                'JAWABAN': 'Synthetic option',
                                'IS_KETERANGAN': '1',
                                'REDIRECT_LINK': 'https://example.invalid',
                              },
                            ],
                          },
                        },
                      ],
                    },
                  };
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, ['surveyStatus', 'surveyQuestions']);
      expect(find.text('Synthetic question'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
            .value,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.textContaining('Jawaban belum dikirim'), findsOneWidget);
      await tester.tap(find.text('Muat ulang status'));
      await tester.pumpAndSettle();
      expect(calls, [
        'surveyStatus',
        'surveyQuestions',
        'surveyStatus',
        'surveyQuestions',
      ]);
    },
  );
  testWidgets(
    'Attendance only sends on confirmation, blocks duplicate taps, reloads on string success',
    (tester) async {
      final calls = <String>[];
      final pending = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StudentAttendance(
                request: (action, parameters) async {
                  calls.add(action);
                  if (action == 'surveyStatus') return gateBody('1');
                  if (action == 'attendanceMeetings') return meetingBody();
                  expect(parameters, choice(mode: '1'));
                  return pending.future;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, ['surveyStatus', 'attendanceMeetings']);
      await tester.tap(find.text('HADIR'));
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      await tester.tap(find.text('HADIR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daring'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls.where((c) => c == 'attendanceSubmit').length, 1);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'HADIR'),
            )
            .onPressed,
        isNull,
      );
      pending.complete({
        'mhs': {
          'data': [
            {'ERRSTATE': '00000'},
          ],
        },
      });
      await tester.pumpAndSettle();
      expect(calls, [
        'surveyStatus',
        'attendanceMeetings',
        'attendanceSubmit',
        'surveyStatus',
        'attendanceMeetings',
      ]);
    },
  );
}
