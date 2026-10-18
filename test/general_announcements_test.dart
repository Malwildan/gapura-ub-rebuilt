import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/model/general_announcement.dart';
import 'package:gapura_ub/service/general_announcements.dart';

// Synthetic data only; no recovered configuration or announcement content.
const config = GeneralAnnouncementsFirebaseConfig(
  apiKey: 'synthetic-key',
  appId: 'synthetic-app',
  messagingSenderId: 'synthetic-sender',
  projectId: 'synthetic-project',
  storageBucket: 'synthetic-bucket',
);

class FakeSdk implements GeneralAnnouncementsSdk {
  final calls = <String>[];
  String value = '[]';
  bool changed = true;
  bool failInit = false;
  bool failSettings = false;
  bool failFetch = false;
  bool failRead = false;
  Completer<void>? initGate;
  Completer<void>? fetchGate;
  Duration? timeout;
  Duration? interval;
  GeneralAnnouncementsFirebaseConfig? initializedWith;

  @override
  Future<void> initialize(GeneralAnnouncementsFirebaseConfig config) async {
    calls.add('initialize');
    initializedWith = config;
    if (initGate != null) await initGate!.future;
    if (failInit) throw StateError('synthetic private SDK detail');
  }

  @override
  Future<void> setConfigSettings({
    required Duration fetchTimeout,
    required Duration minimumFetchInterval,
  }) async {
    calls.add('settings');
    timeout = fetchTimeout;
    interval = minimumFetchInterval;
    if (failSettings) throw StateError('synthetic private SDK detail');
  }

  @override
  Future<bool> fetchAndActivate() async {
    calls.add('fetchAndActivate');
    if (fetchGate != null) await fetchGate!.future;
    if (failFetch) throw StateError('synthetic private SDK detail');
    return changed;
  }

  @override
  String getString(String key) {
    calls.add('getString:$key');
    if (failRead) throw StateError('synthetic private SDK detail');
    return value;
  }
}

GeneralAnnouncementsSource source(FakeSdk sdk) => GeneralAnnouncementsSource(
  sdk: sdk,
  config: config,
  platform: GeneralAnnouncementsPlatform.android,
);

Matcher fails(GeneralAnnouncementsFailure failure) => throwsA(
  isA<GeneralAnnouncementsException>().having(
    (error) => error.failure,
    'failure',
    failure,
  ),
);

void main() {
  group('recovered announcement model', () {
    test('preserves all rows, order, nullable text and plain content', () {
      final rows = GeneralAnnouncement.parseList(
        jsonEncode([
          {
            'id': 'second',
            'start_date': '2099-01-01',
            'end_date': '2000-01-01',
            'title': null,
            'content': '<b>synthetic text</b>',
          },
          {'id': 'first'},
          {'id': 'second', 'title': ''},
        ]),
      );
      expect(rows.map((row) => row.id), ['second', 'first', 'second']);
      expect(rows.first.title, isNull);
      expect(rows.first.content, '<b>synthetic text</b>');
      expect(rows[1].startDate, isNull);
      expect(rows[1].endDate, isNull);
      expect(rows[1].content, isNull);
      expect(() => rows.clear(), throwsUnsupportedError);
    });

    test('uses DateTime.parse timezone and overflow semantics', () {
      final row = GeneralAnnouncement.fromJson({
        'start_date': '2020-01-42',
        'end_date': '2020-02-11T12:00:00+07:00',
      });
      expect(row.startDate, DateTime.parse('2020-01-42'));
      expect(row.endDate, DateTime.utc(2020, 2, 11, 5));
      expect(row.endDate!.isUtc, isTrue);
      final nulls = GeneralAnnouncement.fromJson({
        'start_date': null,
        'end_date': null,
      });
      expect(nulls.startDate, isNull);
      expect(nulls.endDate, isNull);
    });

    for (final malformed in [
      '',
      '{}',
      'null',
      '[null]',
      '[1]',
      '[{"id":1}]',
      '[{"title":false}]',
      '[{"content":[]}]',
      '[{"start_date":"invalid"}]',
      '[{"start_date":""}]',
      '[{"end_date":123}]',
    ]) {
      test('rejects malformed shape/types: $malformed', () {
        expect(
          () => GeneralAnnouncement.parseList(malformed),
          throwsA(anything),
        );
      });
    }
  });

  group('explicit SDK source', () {
    test(
      'construction is inert; exact SDK sequence and settings on fetch',
      () async {
        final sdk = FakeSdk()..value = '[{"id":"synthetic"}]';
        final service = source(sdk);
        expect(sdk.calls, isEmpty);
        expect(service.cached, isNull);
        final rows = await service.fetch();
        expect(rows.single.id, 'synthetic');
        expect(service.cached, same(rows));
        expect(sdk.initializedWith, same(config));
        expect(sdk.calls, [
          'initialize',
          'settings',
          'fetchAndActivate',
          'getString:global_pengumuman',
        ]);
        expect(sdk.timeout, const Duration(seconds: 10));
        expect(sdk.interval, Duration.zero);
        await service.initialize();
        await service.initialize();
        expect(sdk.calls.where((call) => call == 'initialize'), hasLength(1));
      },
    );

    test(
      'false activation still reads; successful empty list replaces cache',
      () async {
        final sdk = FakeSdk()..value = '[{"id":"old"}]';
        final service = source(sdk);
        await service.fetch();
        sdk
          ..changed = false
          ..value = '[]';
        expect(await service.fetch(), isEmpty);
        expect(service.cached, isEmpty);
        expect(sdk.calls.where((call) => call == 'initialize'), hasLength(1));
        expect(
          sdk.calls.where((call) => call == 'fetchAndActivate'),
          hasLength(2),
        );
      },
    );

    test('concurrent initialize and fetch share pending work', () async {
      final sdk = FakeSdk()
        ..initGate = Completer<void>()
        ..fetchGate = Completer<void>();
      final service = source(sdk);
      final init1 = service.initialize();
      final init2 = service.initialize();
      final fetch1 = service.fetch();
      final fetch2 = service.fetch();
      expect(init1, same(init2));
      expect(fetch1, same(fetch2));
      expect(sdk.calls, ['initialize']);
      sdk.initGate!.complete();
      await init1;
      await Future<void>.delayed(Duration.zero);
      expect(sdk.calls, ['initialize', 'settings', 'fetchAndActivate']);
      sdk.fetchGate!.complete();
      expect(await fetch1, same(await fetch2));
      expect(sdk.calls.last, 'getString:global_pengumuman');
    });

    for (final failure in ['init', 'settings']) {
      test(
        '$failure failure is explicit and initialization can retry',
        () async {
          final sdk = FakeSdk()
            ..failInit = failure == 'init'
            ..failSettings = failure == 'settings';
          final service = source(sdk);
          await expectLater(
            service.fetch(),
            fails(GeneralAnnouncementsFailure.initialization),
          );
          expect(service.cached, isNull);
          expect(sdk.calls, isNot(contains('fetchAndActivate')));
          sdk
            ..failInit = false
            ..failSettings = false;
          await service.fetch();
          expect(sdk.calls.where((call) => call == 'initialize'), hasLength(2));
        },
      );
    }

    test(
      'fetch/read failures retain prior list, do not parse fallback, retry',
      () async {
        final sdk = FakeSdk()..value = '[{"id":"old"}]';
        final service = source(sdk);
        final old = await service.fetch();
        sdk
          ..failFetch = true
          ..value = '[{"id":"new"}]';
        await expectLater(
          service.fetch(),
          fails(GeneralAnnouncementsFailure.fetch),
        );
        expect(sdk.calls.last, 'fetchAndActivate');
        expect(service.cached, same(old));
        sdk
          ..failFetch = false
          ..failRead = true;
        await expectLater(
          service.fetch(),
          fails(GeneralAnnouncementsFailure.fetch),
        );
        expect(service.cached, same(old));
        sdk.failRead = false;
        expect((await service.fetch()).single.id, 'new');
      },
    );

    test(
      'partial parse never replaces prior list; malformed values remain explicit',
      () async {
        final sdk = FakeSdk()..value = '[{"id":"old"}]';
        final service = source(sdk);
        final old = await service.fetch();
        for (final bad in ['', '{}', '[{"id":"new"},{"start_date":"bad"}]']) {
          sdk.value = bad;
          await expectLater(
            service.fetch(),
            fails(GeneralAnnouncementsFailure.parsing),
          );
          expect(service.cached, same(old));
        }
        sdk.value = '[{"id":"recovered"}]';
        expect((await service.fetch()).single.id, 'recovered');
      },
    );

    for (final platform in [
      GeneralAnnouncementsPlatform.web,
      GeneralAnnouncementsPlatform.unsupported,
    ]) {
      test(
        '$platform never calls SDK, even with missing configuration',
        () async {
          final sdk = FakeSdk();
          final service = GeneralAnnouncementsSource(
            sdk: sdk,
            platform: platform,
            config: const GeneralAnnouncementsFirebaseConfig(
              apiKey: '',
              appId: '',
              messagingSenderId: '',
              projectId: '',
              storageBucket: '',
            ),
          );
          await expectLater(
            service.initialize(),
            fails(GeneralAnnouncementsFailure.unsupportedPlatform),
          );
          await expectLater(
            service.fetch(),
            fails(GeneralAnnouncementsFailure.unsupportedPlatform),
          );
          expect(sdk.calls, isEmpty);
          expect(service.cached, isNull);
        },
      );
    }

    test(
      'each missing field fails before any SDK call; errors exclude values',
      () async {
        for (var index = 0; index < 5; index++) {
          final fields = List<String>.filled(5, 'synthetic-private-value');
          fields[index] = ' ';
          final sdk = FakeSdk();
          final service = GeneralAnnouncementsSource(
            sdk: sdk,
            platform: GeneralAnnouncementsPlatform.android,
            config: GeneralAnnouncementsFirebaseConfig(
              apiKey: fields[0],
              appId: fields[1],
              messagingSenderId: fields[2],
              projectId: fields[3],
              storageBucket: fields[4],
            ),
          );
          await expectLater(
            service.fetch(),
            fails(GeneralAnnouncementsFailure.missingConfiguration),
          );
          expect(sdk.calls, isEmpty);
        }
        for (final failure in GeneralAnnouncementsFailure.values) {
          final text = GeneralAnnouncementsException(failure).toString();
          expect(text, contains(failure.name));
          expect(text, isNot(contains('synthetic-private-value')));
        }
      },
    );
  });

  test('published configuration template contains only blank values', () {
    final template = jsonDecode(
      File('config/native.example.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(template.keys.toSet(), <String>{
      'GAPURA_CLIENT_ID',
      'GAPURA_SERVICE_TOKEN',
      'GAPURA_OAUTH_CLIENT_SECRET',
      'GAPURA_FIREBASE_API_KEY',
      'GAPURA_FIREBASE_APP_ID',
      'GAPURA_FIREBASE_MESSAGING_SENDER_ID',
      'GAPURA_FIREBASE_PROJECT_ID',
      'GAPURA_FIREBASE_STORAGE_BUCKET',
    });
    expect(template.values.every((value) => value == ''), isTrue);
  });
}
