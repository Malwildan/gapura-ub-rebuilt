import 'dart:convert';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/account_bridge_native.dart';
import 'package:gapura_ub/model/academic_term.dart';
import 'package:gapura_ub/services.dart';
import 'package:gapura_ub/service/session_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class TestAppAuth extends FlutterAppAuth {
  int refreshCalls = 0;
  int loginCalls = 0;

  @override
  Future<AuthorizationTokenResponse> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) async {
    loginCalls++;
    throw StateError('Unexpected interactive login in passive account reader');
  }

  @override
  Future<TokenResponse> token(TokenRequest request) async {
    refreshCalls++;
    expect(request.clientId, 'GapuraUb2020-Mobile');
    expect(request.redirectUrl, 'ub.gapura.app:/oauthredirect');
    expect(request.refreshToken, 'fixture-refresh');
    return TokenResponse(
      'fixture-refreshed-access',
      'fixture-new-refresh',
      DateTime.now().add(const Duration(hours: 1)),
      null,
      'Bearer',
      null,
      null,
    );
  }
}

class MemorySessionStore implements SessionStore {
  Map<String, dynamic>? record;
  @override
  Future<Map<String, dynamic>?> read() async =>
      record == null ? null : Map<String, dynamic>.from(record!);
  @override
  Future<void> write(Map<String, dynamic> session) async {
    record = Map<String, dynamic>.from(session);
  }

  @override
  Future<void> clear() async {
    record = null;
  }
}

late MemorySessionStore testStore;

void seedSession({bool expired = false}) {
  testStore.record = {
    'accessToken': 'fixture-access',
    'refreshToken': 'fixture-refresh',
    'expiresAt': DateTime.now()
        .add(Duration(hours: expired ? -1 : 1))
        .millisecondsSinceEpoch,
    'username': 'fixture-user',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => testStore = MemorySessionStore());

  test(
    'identity reads the original bodyless profile POST with Bearer only',
    () async {
      seedSession();
      var calls = 0;
      final auth = TestAppAuth();
      final bridge = AccountBridge(
        store: testStore,
        appAuth: auth,
        client: MockClient((request) async {
          calls++;
          expect(request.url.toString(), 'https://api.ub.ac.id/profile');
          expect(request.method, 'POST');
          expect(request.bodyBytes, isEmpty);
          expect(request.followRedirects, false);
          expect(request.headers, {'Authorization': 'Bearer fixture-access'});
          return http.Response(
            jsonEncode({
              'X-Ub-Nim': 'SYNTHETIC-NIM',
              'X-Ub-Email': 'synthetic@example.invalid',
            }),
            200,
          );
        }),
      );
      expect(await bridge.request('identity'), {
        'X-Ub-Nim': 'SYNTHETIC-NIM',
        'X-Ub-Email': 'synthetic@example.invalid',
      });
      expect(calls, 1);
      expect(auth.loginCalls, 0);
      expect(auth.refreshCalls, 0);
    },
  );

  test(
    'notifications uses only the recovered read POST and rejects arbitrary identity input',
    () async {
      var requests = 0;
      final service = GapuraService(
        client: MockClient((request) async {
          requests++;
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://apps.ub.ac.id/gateway/api/kepegawaian/notification/find_user_notifications',
          );
          expect(request.followRedirects, false);
          expect(request.headers['Authorization'], '');
          expect(request.headers['Token'], isNotEmpty);
          expect(jsonDecode(request.body), {
            'id_notification': null,
            'title': null,
            'body': null,
            'image_url': null,
            'sentdatetime': null,
            'username': 'fixture-user',
            'timestamp': null,
          });
          return http.Response(
            '[{"title":"Fixture","body":"Body","sentdatetime":"2026-01-01"}]',
            200,
          );
        }),
      );
      expect(
        () => service.notifications('https://evil.test'),
        throwsA(isA<GapuraServiceException>()),
      );
      final records = await service.notifications('fixture-user');
      expect(records.first['title'], 'Fixture');
      expect(requests, 1);
      service.close();
    },
    skip: const String.fromEnvironment('GAPURA_SERVICE_TOKEN').isEmpty
        ? 'Run with --dart-define-from-file=.local/native-config.json to verify native configured reader.'
        : false,
  );

  test(
    'unsigned connection/profile never opens login or sends API requests',
    () async {
      final auth = TestAppAuth();
      var requests = 0;
      final bridge = AccountBridge(
        store: testStore,
        appAuth: auth,
        client: MockClient((request) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      expect(await bridge.request('connection'), {'connected': false});
      await expectLater(bridge.request('profile'), throwsA(isA<StateError>()));
      expect(auth.loginCalls, 0);
      expect(requests, 0);
    },
  );

  test(
    'stored session uses fixed HTTPS profile reader and no redirects',
    () async {
      seedSession();
      final bridge = AccountBridge(
        store: testStore,
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.ub.ac.id/mahasiswa/index/getBioMhs_v2',
          );
          expect(request.method, 'POST');
          expect(request.bodyBytes, isEmpty);
          expect(request.headers.containsKey('Content-Type'), false);
          expect(request.followRedirects, false);
          expect(request.headers['Authorization'], 'Bearer fixture-access');
          return http.Response('{"biodata":{"NAMA":"Fixture only"}}', 200);
        }),
      );
      expect((await bridge.request('profile'))['biodata'], {
        'NAMA': 'Fixture only',
      });
    },
  );

  test(
    'expired access token refreshes using privately retained refresh token',
    () async {
      seedSession(expired: true);
      final auth = TestAppAuth();
      final bridge = AccountBridge(
        store: testStore,
        appAuth: auth,
        client: MockClient((request) async {
          expect(
            request.headers['Authorization'],
            'Bearer fixture-refreshed-access',
          );
          return http.Response('{"biodata":{}}', 200);
        }),
      );
      await bridge.request('profile');
      expect(auth.refreshCalls, 1);
      final record = await testStore.read();
      expect(record!['refreshToken'], 'fixture-new-refresh');
    },
  );

  test('current-term reads derive query from account schedule', () async {
    seedSession();
    var requests = 0;
    final bridge = AccountBridge(
      store: testStore,
      client: MockClient((request) async {
        requests++;
        if (requests == 1) {
          expect(request.url.path, '/mahasiswa/getJadwalKuliah/');
          return http.Response(
            '{"jadwal":{"data":[{"TAHUN":"2026","IS_GANJIL":"1"}]}}',
            200,
          );
        }
        expect(request.url.path, '/mahasiswa/getKRS/');
        expect(request.url.queryParameters, {
          'tahun': '2026',
          'is_ganjil': '1',
          'is_pendek': '0',
        });
        return http.Response('{"krs":[]}', 200);
      }),
    );
    expect(
      await bridge.request('krs', parameters: {'tahun': 'attacker-value'}),
      {'krs': []},
    );
    expect(requests, 2);
  });

  test(
    'materials obtains faculty and branch from real profile fields',
    () async {
      seedSession();
      var requests = 0;
      final bridge = AccountBridge(
        store: testStore,
        client: MockClient((request) async {
          requests++;
          if (requests == 1) {
            expect(request.url.path, '/mahasiswa/index/getBioMhs_v2');
            expect(request.method, 'POST');
            expect(request.bodyBytes, isEmpty);
            return http.Response(
              '{"mhs":{"data":[{"K_FAKULTAS":"F","K_CABANG":"2"}]}}',
              200,
            );
          }
          expect(request.url.path, '/mahasiswa/getDataMateriByMhs/');
          expect(request.url.queryParameters, {
            'is_aktif': '0',
            'k_fakultas': 'F',
            'k_cabang': '2',
          });
          return http.Response('{"materi":{"data":[]}}', 200);
        }),
      );
      await bridge.request(
        'materials',
        parameters: {'active': false, 'k_cabang': 'attacker-value'},
      );
      expect(requests, 2);
    },
  );

  test(
    'materials missing profile context is explicit rather than guessed',
    () async {
      seedSession();
      var requests = 0;
      final bridge = AccountBridge(
        store: testStore,
        client: MockClient((request) async {
          requests++;
          expect(request.url.path, '/mahasiswa/index/getBioMhs_v2');
          return http.Response('{"mhs":{"data":[{"K_FAKULTAS":"F"}]}}', 200);
        }),
      );
      await expectLater(
        bridge.request('materials'),
        throwsA(isA<StateError>()),
      );
      expect(requests, 1);
    },
  );

  test(
    'history matches verified fixed flags and actual selected course branch',
    () async {
      seedSession();
      final course = {
        'K_MK': 'A',
        'KELAS': 'Z',
        'TAHUN': '2026',
        'IS_GANJIL': '1',
        'K_FAKULTAS': 'F',
        'K_JENJANG': 'S1',
        'K_JURUSAN': 'J',
        'K_PROG_STUDI': 'P',
        'THN_MK': '2025',
        'K_CABANG': '3',
        'IS_PENDEK': '0',
        'K_TIPE_SELEKSI': 'OTHER',
      };
      var requests = 0;
      final bridge = AccountBridge(
        store: testStore,
        client: MockClient((request) async {
          requests++;
          if (requests == 1) {
            return http.Response(
              jsonEncode({
                'jadwal': {
                  'data': [course],
                },
              }),
              200,
            );
          }
          expect(request.url.path, '/mahasiswa/index/getRiwayatMateriMhs/');
          expect(request.url.queryParameters.length, 12);
          expect(request.url.queryParameters['is_pendek'], '0');
          expect(request.url.queryParameters['k_tipe_seleksi'], 'x');
          expect(request.url.queryParameters['k_cabang'], '3');
          return http.Response('{"materi":{"data":[]}}', 200);
        }),
      );
      await bridge.request('history', parameters: {'course': course});
      expect(requests, 2);
    },
  );

  test('history rejects courses outside the live account schedule', () async {
    seedSession();
    var requests = 0;
    final bridge = AccountBridge(
      store: testStore,
      client: MockClient((request) async {
        requests++;
        return http.Response(
          '{"jadwal":{"data":[{"K_MK":"A","KELAS":"A","TAHUN":"2026","IS_GANJIL":"1"}]}}',
          200,
        );
      }),
    );
    await expectLater(
      bridge.request(
        'history',
        parameters: {
          'course': {
            'K_MK': 'OTHER',
            'KELAS': 'A',
            'TAHUN': '2026',
            'IS_GANJIL': '1',
          },
        },
      ),
      throwsA(isA<StateError>()),
    );
    expect(requests, 1);
  });

  test('academic term validates selections and preserves exact query keys', () {
    const regular = AcademicTerm();
    expect(regular.query(), {'is_pendek': '0'});
    expect(regular.query(allTerms: true), {
      'tahun': 'x',
      'is_ganjil': 'x',
      'is_pendek': '0',
    });
    final previous = AcademicTerm.fromParameters({
      'year': '2023',
      'odd': false,
      'short': true,
    });
    expect(previous.query(), {
      'tahun': '2023',
      'is_ganjil': '0',
      'is_pendek': '1',
    });
    expect(previous.toParameters(), {
      'year': '2023',
      'odd': false,
      'short': true,
    });
    expect(previous.label, '2023 · Genap · Pendek');
    expect(previous, const AcademicTerm(year: '2023', odd: false, short: true));
    expect(AcademicTerm.fromParameters({'year': null, 'odd': null}).query(), {
      'is_pendek': '0',
    });
  });

  test(
    'history checks the real matched course short flag, not caller claim',
    () async {
      seedSession();
      var requests = 0;
      final course = {
        'K_MK': 'A',
        'KELAS': 'Z',
        'TAHUN': '2024',
        'IS_GANJIL': '1',
        'IS_PENDEK': '1',
      };
      final bridge = AccountBridge(
        store: testStore,
        client: MockClient((request) async {
          requests++;
          expect(request.url.path, '/mahasiswa/getJadwalKuliah/');
          return http.Response(
            jsonEncode({
              'jadwal': {
                'data': [course],
              },
            }),
            200,
          );
        }),
      );
      await expectLater(
        bridge.request(
          'history',
          parameters: {
            'course': {...course, 'IS_PENDEK': '0'},
          },
        ),
        throwsA(isA<StateError>()),
      );
      expect(requests, 1);
    },
  );

  test(
    'explicit previous term bypasses schedule and forwards selected short',
    () async {
      seedSession();
      final calls = <Uri>[];
      final bridge = AccountBridge(
        store: testStore,
        client: MockClient((request) async {
          calls.add(request.url);
          expect(request.url.queryParameters, {
            'tahun': '2023',
            'is_ganjil': '0',
            'is_pendek': '1',
          });
          return http.Response('{"data":[]}', 200);
        }),
      );
      for (final action in ['krs', 'grades', 'transcript']) {
        await bridge.request(
          action,
          parameters: {'year': '2023', 'odd': false, 'short': true},
        );
      }
      expect(calls.map((uri) => uri.path), [
        '/mahasiswa/getKRS/',
        '/mahasiswa/getKHS/',
        '/mahasiswa/getKHS/',
      ]);
    },
  );

  test(
    'short current KRS derives term from selected short schedule only',
    () async {
      seedSession();
      var requests = 0;
      final bridge = AccountBridge(
        store: testStore,
        client: MockClient((request) async {
          requests++;
          if (requests == 1) {
            expect(request.url.path, '/mahasiswa/getJadwalKuliah/');
            expect(request.url.queryParameters, {'is_pendek': '1'});
            return http.Response(
              '{"jadwal":{"data":[{"TAHUN":"2024","IS_GANJIL":"1"}]}}',
              200,
            );
          }
          expect(request.url.path, '/mahasiswa/getKRS/');
          expect(request.url.queryParameters, {
            'tahun': '2024',
            'is_ganjil': '1',
            'is_pendek': '1',
          });
          return http.Response('{"krs":{"data":[]}}', 200);
        }),
      );
      await bridge.request('krs', parameters: {'short': true});
      expect(requests, 2);
    },
  );

  test(
    'schedule short flag and old transcript finance defaults remain exact',
    () async {
      seedSession();
      final calls = <Uri>[];
      final bridge = AccountBridge(
        store: testStore,
        client: MockClient((request) async {
          calls.add(request.url);
          return http.Response('{"data":[]}', 200);
        }),
      );
      await bridge.request('schedule', parameters: {'short': true});
      await bridge.request('transcript');
      await bridge.request('finance');
      expect(calls[0].queryParameters, {'is_pendek': '1'});
      expect(calls[1].queryParameters, {
        'tahun': 'x',
        'is_ganjil': 'x',
        'is_pendek': '0',
      });
      expect(calls[2].queryParameters, {
        'tahun': 'x',
        'is_ganjil': 'x',
        'is_pendek': '0',
      });
    },
  );

  test(
    'incomplete and invalid term arguments fail before refresh or HTTP',
    () async {
      seedSession(expired: true);
      final auth = TestAppAuth();
      var requests = 0;
      final bridge = AccountBridge(
        store: testStore,
        appAuth: auth,
        client: MockClient((request) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      final invalid = <Map<String, dynamic>>[
        {'year': '2023'},
        {'odd': true},
        {'year': '2023', 'odd': null},
        {'year': 2023, 'odd': true},
        {'year': '202x', 'odd': true},
        {'year': '1899', 'odd': true},
        {'year': '2201', 'odd': false},
        {'year': '2023', 'odd': 1},
        {'short': '1'},
        {'short': null},
        {'year': '2023&url=evil', 'odd': true},
      ];
      for (final parameters in invalid) {
        await expectLater(
          bridge.request('krs', parameters: parameters),
          throwsA(isA<FormatException>()),
        );
      }
      await expectLater(
        bridge.request('finance', parameters: {'short': true}),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        bridge.request('finance', parameters: {'year': '2023', 'odd': false}),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        bridge.request('history', parameters: {'short': true}),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        bridge.request(
          'history',
          parameters: {
            'course': {'IS_PENDEK': '1'},
          },
        ),
        throwsA(isA<StateError>()),
      );
      expect(auth.refreshCalls, 0);
      expect(requests, 0);
    },
  );

  test('explicit term still works without a current short schedule', () async {
    seedSession();
    var requests = 0;
    final bridge = AccountBridge(
      store: testStore,
      client: MockClient((request) async {
        requests++;
        if (request.url.path.contains('getJadwal')) {
          return http.Response('{"jadwal":{"data":[]}}', 200);
        }
        return http.Response('{"krs":{"data":[]}}', 200);
      }),
    );
    await expectLater(
      bridge.request('schedule', parameters: {'year': '2023', 'odd': true}),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      bridge.request('krs', parameters: {'short': true}),
      throwsA(isA<StateError>()),
    );
    await bridge.request(
      'krs',
      parameters: {'year': '2023', 'odd': true, 'short': true},
    );
    expect(requests, 2);
  });

  test('disconnect clears local session without remote writes', () async {
    seedSession();
    final bridge = AccountBridge(
      store: testStore,
      client: MockClient((request) async {
        fail('Disconnect must not write to an upstream service');
      }),
    );
    expect(await bridge.request('disconnect'), {'connected': false});
    expect(await bridge.request('connection'), {'connected': false});
    expect(await testStore.read(), isNull);
  });

  test(
    'HTML/verification responses report an error instead of fabricated data',
    () async {
      seedSession();
      final bridge = AccountBridge(
        store: testStore,
        client: MockClient(
          (request) async => http.Response('<html>challenge</html>', 200),
        ),
      );
      await expectLater(bridge.request('profile'), throwsA(isA<StateError>()));
    },
  );

  test(
    'native news uses official feed directly and sanitizes rendered content',
    () async {
      final service = GapuraService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://prasetya.ub.ac.id/category/headline/feed/',
          );
          expect(request.headers.containsKey('Token'), false);
          return http.Response(
            '''<rss><channel><item><title>Fixture</title>
        <description><![CDATA[<p>Article body</p><script>hidden</script>]]></description>
        <link>https://prasetya.ub.ac.id/fixture</link><pubDate>Mon, 19 Oct 2026 01:00:00 +0000</pubDate>
        </item><item><title>Unsafe</title><link>https://evil.test/</link></item></channel></rss>''',
            200,
          );
        }),
      );
      final rows = await service.news();
      expect(rows.length, 1);
      expect(rows.first['description'], 'Article body');
      expect(rows.first['link'], 'https://prasetya.ub.ac.id/fixture');
      service.close();
    },
  );
}
