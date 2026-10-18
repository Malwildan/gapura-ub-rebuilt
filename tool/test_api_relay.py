"""Boundary/schema regression tests. All values here are synthetic fixtures."""

import http.client
import json
import threading
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch

import api_relay as relay


class FakeResponse:
    status = 200

    def __init__(self, body, status=200, headers=None):
        self.body = body
        self.status = status
        self.headers = headers or {}
        self.position = 0

    def __enter__(self):
        return self

    def __exit__(self, *_):
        pass

    def read(self, count):
        chunk = self.body[self.position:self.position + count]
        self.position += len(chunk)
        return chunk


class ConfigTests(unittest.TestCase):
    def test_native_define_names_map_to_service_headers(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'config.json'
            path.write_text(json.dumps({
                'GAPURA_CLIENT_ID': 'synthetic-client',
                'GAPURA_SERVICE_TOKEN': 'synthetic-token',
                'UNRELATED': 'synthetic-other',
            }), encoding='utf-8')
            self.assertEqual(relay.load_config(path), {
                'clientId': 'synthetic-client', 'token': 'synthetic-token'})

    def test_missing_or_wrongly_typed_config_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'config.json'
            for config in ({}, [], {'GAPURA_CLIENT_ID': 'synthetic-private'},
                           {'GAPURA_CLIENT_ID': 'synthetic-private', 'GAPURA_SERVICE_TOKEN': ' '},
                           {'GAPURA_CLIENT_ID': 123, 'GAPURA_SERVICE_TOKEN': 'synthetic-private'}):
                path.write_text(json.dumps(config), encoding='utf-8')
                with self.assertRaisesRegex(ValueError, '^Shared UB service configuration is missing$'):
                    relay.load_config(path)

    def test_malformed_json_error_excludes_input(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'config.json'
            path.write_text('synthetic-private-invalid-json', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, '^Shared UB service configuration is invalid$'):
                relay.load_config(path)


class SchemaTests(unittest.TestCase):
    def test_achievements_select_original_second_group_without_other_images(self):
        payload = {'GAMBAR': [
            {'PENGHARGAAN': [{'URL_FILE': 'https://ub.ac.id/wrong.png'}]},
            {'PENGHARGAAN': [{'URL_FILE': 'https://ub.ac.id/award.png', 'NO_URUT': '2'}]},
            {'LOGO': [{'URL_FILE': 'https://ub.ac.id/logo.png'}]},
        ]}
        self.assertEqual(relay.normalize_ws(json.dumps(payload), '/achievements'),
                         payload['GAMBAR'][1]['PENGHARGAAN'])
        for groups in ([], [{}], [{}, {'LOGO': []}], [{}, {'PENGHARGAAN': [None]}]):
            with self.assertRaises(ValueError):
                relay.normalize_ws(json.dumps({'GAMBAR': groups}), '/achievements')

    def test_news_source_mapping_order_and_exact_latest_http_identity(self):
        self.assertEqual(list(relay.NEWS_FEEDS),
                         ['official', 'prasetya', 'selma', 'rsub', 'rsgm', 'klinik', 'latest'])
        self.assertEqual(relay.NEWS_FEEDS['official'], 'https://ub.ac.id/id/feed/')
        self.assertEqual(relay.NEWS_FEEDS['selma'], 'https://selma.ub.ac.id/id/rss')
        self.assertEqual(relay.NEWS_FEEDS['rsub'], 'https://rumahsakit.ub.ac.id/feed/')
        self.assertEqual(relay.NEWS_FEEDS['rsgm'], 'https://rsgm.ub.ac.id/feed/')
        self.assertEqual(relay.NEWS_FEEDS['klinik'], 'https://klinik.ub.ac.id/feed/')
        self.assertEqual(relay.NEWS_FEEDS['latest'], 'http://prasetya.ub.ac.id/feed/')
        self.assertNotEqual(relay.NEWS_FEEDS['latest'], relay.NEWS_FEEDS['prasetya'])

    def test_news_source_accepts_only_fixed_enum_ids_before_network(self):
        self.assertEqual(relay.news_source('/news'), 'prasetya')
        for source in relay.NEWS_FEEDS:
            self.assertEqual(relay.news_source('/news?source=' + source), source)
        called = []
        for path in ('/news?source=', '/news?source=unknown',
                     '/news?source=official&source=prasetya',
                     '/news?source=official&url=https://ub.ac.id/',
                     '/news?url=https://ub.ac.id/feed/',
                     '/news?source=http://prasetya.ub.ac.id/feed/',
                     '/news?source=official#fragment'):
            with self.assertRaises((ValueError, UnicodeError), msg=path):
                relay.fetch_route(path, {}, lambda *args, **kwargs: called.append(args))
        self.assertEqual(called, [])

    def test_all_news_sources_get_exact_public_destination_without_credentials(self):
        for source, url in relay.NEWS_FEEDS.items():
            def opener(request, timeout):
                self.assertEqual(request.full_url, url)
                self.assertEqual(request.get_method(), 'GET')
                self.assertIsNone(request.data)
                for header in ('Authorization', 'Token', 'Client-id', 'Cookie'):
                    self.assertIsNone(request.get_header(header))
                return FakeResponse(b'<rss><channel/></rss>')
            self.assertEqual(relay.fetch_route('/news?source=' + source, {}, opener), [])

    def test_news_redirects_follow_only_ub_hosts_and_preserve_get_without_credentials(self):
        observed = []
        def opener(request, timeout):
            observed.append(request)
            if len(observed) == 1:
                return FakeResponse(b'', 301, {'Location': 'https://prasetya.ub.ac.id/feed/'})
            return FakeResponse(b'<rss><channel/></rss>')
        body, metadata = relay.read_news_feed('latest', opener)
        self.assertEqual(relay.normalize_news(body), [])
        self.assertEqual(metadata['initial_url'], 'http://prasetya.ub.ac.id/feed/')
        self.assertEqual(metadata['final_url'], 'https://prasetya.ub.ac.id/feed/')
        self.assertEqual(len(metadata['redirects']), 1)
        self.assertEqual([r.get_method() for r in observed], ['GET', 'GET'])
        self.assertTrue(all(r.get_header('Token') is None for r in observed))
        for location in ('https://evil.test/', 'https://ub.ac.id.evil.test/',
                         'https://user:pass@ub.ac.id/', 'https://@ub.ac.id/', 'https://ub.ac.id:123/',
                         'file:///tmp/feed', 'javascript:alert(1)', '//evil.test/'):
            calls = []
            def denied(request, timeout):
                calls.append(request.full_url)
                return FakeResponse(b'', 302, {'Location': location})
            with self.assertRaises(ValueError, msg=location):
                relay.read_news_feed('official', denied)
            self.assertEqual(calls, [relay.NEWS_FEEDS['official']])

    def test_news_redirect_count_and_deadline_are_bounded(self):
        calls = []
        def looping(request, timeout):
            calls.append(request.full_url)
            return FakeResponse(b'', 302, {'Location': '/id/feed/'})
        with self.assertRaisesRegex(ValueError, 'redirect limit'):
            relay.read_news_feed('official', looping)
        self.assertEqual(len(calls), relay.NEWS_REDIRECT_LIMIT + 1)
        calls.clear()
        with patch.object(relay.time, 'monotonic', side_effect=[0, 19]):
            with self.assertRaises(TimeoutError):
                relay.read_news_feed('official', looping)
        self.assertEqual(calls, [])

    def test_latest_http_failure_does_not_upgrade_or_substitute_a_feed(self):
        calls = []
        def failing(request, timeout):
            calls.append(request.full_url)
            return FakeResponse(b'<html>Unavailable</html>', 404)
        with self.assertRaisesRegex(ValueError, 'HTTP 404'):
            relay.fetch_route('/news?source=latest', {}, failing)
        self.assertEqual(calls, ['http://prasetya.ub.ac.id/feed/'])

    def test_news_accepts_original_http_ub_article_links_without_upgrading(self):
        records = relay.normalize_news(b'<rss><channel><item><title>Fixture</title>'
            b'<link>http://prasetya.ub.ac.id/fixture/</link></item></channel></rss>')
        self.assertEqual(records[0]['link'], 'http://prasetya.ub.ac.id/fixture/')
        self.assertEqual(relay.public_url('http://prasetya.ub.ac.id/fixture/'), '')

    def test_news_is_plain_text_with_official_links(self):
        body = b'''<rss><channel><item><title><![CDATA[<b>Berita</b>]]></title>
          <description><![CDATA[<p>Isi <b>berita</b></p><script>hidden()</script>
          <img src="https://prasetya.ub.ac.id/test.jpg">]]></description>
          <link>https://prasetya.ub.ac.id/test/</link>
          <pubDate>Mon, 19 Oct 2026 01:00:00 +0000</pubDate></item>
          <item><title>Unsafe</title><link>javascript:alert(1)</link></item>
          </channel></rss>'''
        rows = relay.normalize_news(body)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0], {
            'title': 'Berita', 'description': 'Isi berita',
            'link': 'https://prasetya.ub.ac.id/test/',
            'date': '2026-10-19T01:00:00+00:00',
            'image': 'https://prasetya.ub.ac.id/test.jpg',
        })

    def test_feed_rejects_declarations_and_non_rss(self):
        for body in (b'<!DOCTYPE rss><rss/>', b'<html/>', b'<rss/>'):
            with self.assertRaises(ValueError):
                relay.normalize_news(body)

    def test_public_urls_disallow_deceptive_hosts_and_credentials(self):
        for value in ('http://ub.ac.id/', 'https://ub.ac.id.evil.test/',
                      'https://evilub.ac.id/', 'https://user@ub.ac.id/',
                      'https://ub.ac.id:123/', 'javascript:alert(1)', None):
            self.assertEqual(relay.public_url(value), '', value)
        self.assertEqual(relay.public_url('https://ub.ac.id/'), 'https://ub.ac.id/')

    def test_ws_flattening_preserves_values_and_group(self):
        record = {'ITEM': 'Fixture', 'JML': '12', 'NO_URUT': '1', 'GRUP': 'SEKILAS'}
        body = json.dumps({'STATISTIK': [{'SEKILAS': [record]}]}).encode()
        self.assertEqual(relay.normalize_ws(body, '/statistics'),
                         [{**record, '_group': 'SEKILAS'}])
        self.assertEqual(relay.normalize_ws(b'{"GAMBAR":[]}', '/images'), [])

    def test_ws_schema_failures(self):
        for payload in ({}, [], {'STATISTIK': [None]},
                        {'STATISTIK': [{'A': [{}]}]}, {'STATISTIK': [{'A': 'wrong'}]}):
            with self.assertRaises(ValueError):
                relay.normalize_ws(json.dumps(payload).encode(), '/statistics')

    def test_fixed_upstream_request_contracts(self):
        config = {'clientId': 'fixture-client', 'token': 'fixture-token'}
        observed = []

        def opener(request, timeout):
            observed.append((request, timeout))
            if request.get_method() == 'GET':
                return FakeResponse(b'<rss><channel/></rss>')
            key = relay.WS_ROUTES['/' + {
                'GetStatistik': 'statistics', 'GetKalenderAkademik': 'calendar',
                'GetGambar': 'images',
            }[request.full_url.rsplit('/', 1)[-1]]][1]
            groups = [{'LOGO': []}, {'PENGHARGAAN': []}] if key == 'GAMBAR' else []
            return FakeResponse(json.dumps({key: groups}).encode())

        for route, (method, _, _) in relay.WS_ROUTES.items():
            self.assertEqual(relay.fetch_route(route, config, opener), [])
            request, timeout = observed[-1]
            self.assertEqual(request.full_url, 'https://apigapura.ub.ac.id/WS/' + method)
            self.assertEqual(request.get_method(), 'POST')
            self.assertIsNone(request.data)
            self.assertEqual(request.get_header('Client-id'), 'fixture-client')
            self.assertEqual(request.get_header('Token'), 'fixture-token')
            self.assertEqual(request.get_header('Authorization'), '')
            self.assertEqual(timeout, 12)
        relay.fetch_route('/news', config, opener)
        self.assertEqual(observed[-1][0].full_url, relay.FEED)
        self.assertIsNone(observed[-1][0].get_header('Token'))
        with self.assertRaises(ValueError):
            relay.fetch_route('/https://evil.test', config, opener)

    def test_response_limit(self):
        with self.assertRaisesRegex(ValueError, 'limit'):
            relay.fetch_route('/news', {}, lambda *a, **k: FakeResponse(b'x' * (relay.LIMIT + 1)))

    def test_notification_exact_contract_and_schema(self):
        def opener(request, timeout):
            self.assertEqual(request.full_url, relay.NOTIFICATION_URL)
            self.assertEqual(request.get_method(), 'POST')
            self.assertEqual(request.get_header('Authorization'), '')
            self.assertEqual(request.get_header('Client-id'), 'fixture-client')
            self.assertEqual(request.get_header('Token'), 'fixture-service-token')
            self.assertEqual(timeout, 12)
            self.assertEqual(json.loads(request.data), {
                'id_notification': None, 'title': None, 'body': None,
                'image_url': None, 'sentdatetime': None,
                'username': 'fixture-user', 'timestamp': None,
            })
            return FakeResponse(b'[{"title":"Fixture","body":"Body","sentdatetime":"2026-01-01"}]')

        records = relay.fetch_notifications('fixture-user', {
            'clientId': 'fixture-client', 'token': 'fixture-service-token'}, opener)
        self.assertEqual(records[0]['title'], 'Fixture')
        with self.assertRaises(ValueError):
            relay.fetch_notifications('https://evil.test', {}, opener)
        with self.assertRaises(ValueError):
            relay.fetch_notifications('fixture-user', {
                'clientId': 'fixture-client', 'token': 'fixture-service-token'},
                lambda *a, **k: FakeResponse(b'{"data":[{}]}'))

    def test_notification_identity_only_accepts_one_bounded_username(self):
        self.assertEqual(relay.notification_identity('/notifications?username=fixture-user'), 'fixture-user')
        self.assertEqual(relay.notification_identity('/notifications?username=a%2Bb%40ub.ac.id'), 'a+b@ub.ac.id')
        for path in ('/notifications', '/notifications?username=',
                     '/notifications?username=one&username=two',
                     '/notifications?username=one&url=https://evil.test',
                     '/notifications?token=private', '/notifications?username=%0d%0a',
                     '/notifications?username=' + 'a' * 201,
                     '/notifications?username=one#fragment', '/notifications/?username=one'):
            self.assertIsNone(relay.notification_identity(path), path)


class HttpBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = relay.RelayServer(('127.0.0.1', 0), config={})
        cls.server.fetcher = lambda route, config: [{'route': route}]
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def request(self, path='/news', method='GET', headers=None, body=None):
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=3)
        request_headers = {'Origin': 'http://127.0.0.1:8790'}
        request_headers.update(headers or {})
        connection.request(method, path, body=body, headers=request_headers)
        response = connection.getresponse()
        result = (response.status, dict(response.getheaders()), response.read())
        connection.close()
        return result

    def test_valid_reads_and_health(self):
        for path in relay.ROUTES:
            status, headers, body = self.request(path)
            self.assertEqual(status, 200)
            self.assertEqual(headers['Access-Control-Allow-Origin'], 'http://127.0.0.1:8790')
            self.assertEqual(json.loads(body), [{'route': path}])
        self.assertEqual(json.loads(self.request('/health')[2]), {'service': relay.IDENTITY})

    def test_exact_route_only(self):
        for path in ('/news/', '//news', '/notifications',
                     '/statistics?NIM=1', '/%6eews', '/https://evil.test'):
            self.assertEqual(self.request(path)[0], 403, path)

    def test_news_source_http_validation_and_separate_cache_keys(self):
        previous = self.server.fetcher
        calls = []
        def fetch(route, config):
            calls.append(route)
            return [{'source': relay.news_source(route)}]
        self.server.fetcher = fetch
        self.server.cache.clear()
        try:
            for source in ('official', 'latest', 'prasetya', 'official'):
                status, _, body = self.request('/news?source=' + source)
                self.assertEqual(status, 200)
                self.assertEqual(json.loads(body), [{'source': source}])
            self.assertEqual(calls, ['/news?source=official', '/news?source=latest',
                                     '/news?source=prasetya'])
            before = len(calls)
            for path in ('/news?source=unknown', '/news?source=',
                         '/news?source=official&source=latest',
                         '/news?url=https://evil.test', '/news?source=official&extra=x'):
                self.assertEqual(self.request(path)[0], 400, path)
            self.assertEqual(len(calls), before)
        finally:
            self.server.fetcher = previous
            self.server.cache.clear()

    def test_origin_and_host_boundary(self):
        for origin in ('https://evil.test', 'null', 'http://localhost:1234',
                       'http://127.0.0.1:8790.evil.test', ''):
            status, headers, _ = self.request(headers={'Origin': origin})
            self.assertEqual(status, 403)
            self.assertNotIn('Access-Control-Allow-Origin', headers)
        self.assertEqual(self.request(headers={'Host': 'evil.test'})[0], 403)
        self.assertEqual(self.request(headers={'Origin': 'http://localhost:8790'})[0], 200)

    def test_no_private_identity_or_request_bodies(self):
        for headers in ({'Authorization': 'Bearer fixture'}, {'Cookie': 'session=fixture'},
                        {'Transfer-Encoding': 'chunked'}, {'Content-Length': '1'}):
            self.assertEqual(self.request(headers=headers)[0], 403)
        self.assertEqual(self.request(method='POST', body='{}')[0], 405)

    def test_options_allows_only_simple_read(self):
        self.assertEqual(self.request(method='OPTIONS', headers={
            'Access-Control-Request-Method': 'GET'})[0], 204)
        self.assertEqual(self.request(method='OPTIONS', headers={
            'Access-Control-Request-Method': 'POST'})[0], 403)
        self.assertEqual(self.request(method='OPTIONS', headers={
            'Access-Control-Request-Headers': 'authorization'})[0], 403)

    def test_upstream_failure_is_explicit_and_does_not_reflect_details(self):
        previous = self.server.fetcher

        def fail(*_):
            raise RuntimeError('fixture secret must not be returned')

        self.server.cache.clear()
        self.server.fetcher = fail
        try:
            status, _, body = self.request()
            self.assertEqual(status, 502)
            self.assertIn('error', json.loads(body))
            self.assertNotIn(b'secret', body)
        finally:
            self.server.fetcher = previous

    def test_notification_reader_keeps_origin_boundaries_and_never_caches(self):
        calls = []
        previous = self.server.notification_fetcher

        def notifications(username, config):
            calls.append(username)
            return [{'title': 'Fixture', 'body': 'Body'}]

        self.server.notification_fetcher = notifications
        try:
            for _ in range(2):
                status, _, body = self.request('/notifications?username=fixture-user')
                self.assertEqual(status, 200)
                self.assertEqual(json.loads(body), [{'title': 'Fixture', 'body': 'Body'}])
            self.assertEqual(len(calls), 2)
            for path in ('/notifications?username=fixture-user&url=https://evil.test',
                         '/notifications?username=one&username=two'):
                self.assertEqual(self.request(path)[0], 403)
            self.assertEqual(self.request('/notifications?username=fixture-user',
                                         headers={'Origin': 'https://evil.test'})[0], 403)
            self.assertEqual(self.request('/notifications?username=fixture-user',
                                         headers={'Authorization': 'Bearer fixture'})[0], 403)
            self.assertEqual(len(calls), 2)
            self.assertFalse(any('notifications' in key for key in self.server.cache))
        finally:
            self.server.notification_fetcher = previous


if __name__ == '__main__':
    unittest.main()
