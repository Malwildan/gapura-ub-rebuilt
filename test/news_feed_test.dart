import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/model/news_feed.dart';
import 'package:gapura_ub/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const emptyRss = '<rss><channel/></rss>';

void main() {
  test(
    'NewsFeed preserves the six original tab destinations and distinct home',
    () {
      expect(NewsFeed.tabs.map((feed) => feed.label), [
        'UB Official',
        'Prasetya',
        'SELMA',
        'RSUB',
        'RSGM',
        'Klinik',
      ]);
      expect(NewsFeed.tabs.map((feed) => feed.uri.toString()), [
        'https://ub.ac.id/id/feed/',
        'https://prasetya.ub.ac.id/category/headline/feed/',
        'https://selma.ub.ac.id/id/rss',
        'https://rumahsakit.ub.ac.id/feed/',
        'https://rsgm.ub.ac.id/feed/',
        'https://klinik.ub.ac.id/feed/',
      ]);
      expect(NewsFeed.latest.uri.toString(), 'http://prasetya.ub.ac.id/feed/');
      expect(NewsFeed.tabs, isNot(contains(NewsFeed.latest)));
    },
  );

  test(
    'every native news reader uses its exact GET without private headers',
    () async {
      final calls = <Uri>[];
      final service = GapuraService(
        client: MockClient((request) async {
          calls.add(request.url);
          expect(request.method, 'GET');
          expect(request.followRedirects, isFalse);
          expect(request.body, isEmpty);
          final keys = request.headers.keys.map((key) => key.toLowerCase());
          for (final header in [
            'authorization',
            'token',
            'client-id',
            'cookie',
          ]) {
            expect(keys, isNot(contains(header)));
          }
          return http.Response(emptyRss, 200);
        }),
      );
      for (final feed in NewsFeed.values) {
        expect(await service.newsFeed(feed), isEmpty);
        expect(calls.last, feed.uri);
      }
      await service.news();
      expect(calls.last, NewsFeed.prasetya.uri);
      await service.latestNews();
      expect(calls.last, NewsFeed.latest.uri);
      service.close();
    },
  );

  test(
    'public redirects are bounded and never carry shared service headers',
    () async {
      final calls = <Uri>[];
      final service = GapuraService(
        client: MockClient((request) async {
          calls.add(request.url);
          expect(
            request.headers.keys.map((key) => key.toLowerCase()),
            isNot(contains('token')),
          );
          return calls.length == 1
              ? http.Response(
                  '',
                  301,
                  headers: {'location': 'https://prasetya.ub.ac.id/feed/'},
                )
              : http.Response(emptyRss, 200);
        }),
      );
      expect(await service.latestNews(), isEmpty);
      expect(calls.map((uri) => uri.toString()), [
        'http://prasetya.ub.ac.id/feed/',
        'https://prasetya.ub.ac.id/feed/',
      ]);
      service.close();

      for (final location in [
        'https://evil.test/',
        'https://ub.ac.id.evil.test/',
        'https://user:pass@ub.ac.id/',
        'https://@ub.ac.id/',
        'https://ub.ac.id:123/',
        'file:///tmp/feed',
        'javascript:alert(1)',
        '//evil.test/',
      ]) {
        var sent = 0;
        final blocked = GapuraService(
          client: MockClient((_) async {
            sent++;
            return http.Response('', 302, headers: {'location': location});
          }),
        );
        await expectLater(
          blocked.newsFeed(NewsFeed.official),
          throwsA(isA<GapuraServiceException>()),
        );
        expect(sent, 1, reason: location);
        blocked.close();
      }

      var sent = 0;
      final looping = GapuraService(
        client: MockClient((_) async {
          sent++;
          return http.Response('', 302, headers: {'location': '/id/feed/'});
        }),
      );
      await expectLater(
        looping.newsFeed(NewsFeed.official),
        throwsA(isA<GapuraServiceException>()),
      );
      expect(sent, 5);
      looping.close();
    },
  );

  test(
    'HTTP LatestNews failures remain failures without source substitution',
    () async {
      final calls = <Uri>[];
      final service = GapuraService(
        client: MockClient((request) async {
          calls.add(request.url);
          return http.Response('<html>Not found</html>', 404);
        }),
      );
      await expectLater(
        service.latestNews(),
        throwsA(
          predicate(
            (error) =>
                error is GapuraServiceException &&
                error.message.contains('404'),
          ),
        ),
      );
      expect(calls, [NewsFeed.latest.uri]);
      service.close();
    },
  );

  test(
    'RSS parsing keeps source links, strips HTML and excludes foreign URLs',
    () async {
      final service = GapuraService(
        client: MockClient(
          (_) async => http.Response('''
      <rss xmlns:media="http://search.yahoo.com/mrss/"><channel>
        <item><title><![CDATA[<b>Fixture</b>]]></title>
          <description><![CDATA[<p>Body</p><script>hidden()</script>]]></description>
          <link>http://prasetya.ub.ac.id/fixture/</link>
          <media:thumbnail url="https://ub.ac.id/fixture.jpg"/>
        </item>
        <item><title>Unsafe</title><link>https://ub.ac.id.evil.test/</link></item>
        <item><title>Bad port</title><link>https://ub.ac.id:invalid/</link></item>
      </channel></rss>''', 200),
        ),
      );
      final rows = await service.latestNews();
      expect(rows, hasLength(1));
      expect(rows.single['title'], 'Fixture');
      expect(rows.single['description'], 'Body');
      expect(rows.single['link'], 'http://prasetya.ub.ac.id/fixture/');
      expect(rows.single['image'], 'https://ub.ac.id/fixture.jpg');
      service.close();
    },
  );

  test(
    'oversized, HTML and declaration responses cannot become empty success',
    () async {
      for (final body in [
        'x' * 2000001,
        '<html><title>Challenge</title></html>',
        '<!DOCTYPE rss><rss><channel/></rss>',
        '<rss/>',
      ]) {
        final service = GapuraService(
          client: MockClient(
            (_) async => http.Response.bytes(utf8.encode(body), 200),
          ),
        );
        await expectLater(
          service.news(),
          throwsA(isA<GapuraServiceException>()),
        );
        service.close();
      }
      final timedOut = GapuraService(
        client: MockClient(
          (_) async => throw TimeoutException('Synthetic network timeout'),
        ),
      );
      await expectLater(
        timedOut.news(),
        throwsA(
          predicate(
            (error) =>
                error is GapuraServiceException &&
                error.message.contains('lama'),
          ),
        ),
      );
      timedOut.close();
    },
  );
}
