"""Loopback-only, fixed public readers for the reconstructed Flutter application.

Run from any directory: python tool/api_relay.py
The web development server must use port 8790. This relay does not handle
student sessions, IAM tokens or arbitrary upstream destinations. Its separate
notification reader accepts a bounded account identity and performs no writes.
"""

import json
import re
import threading
import time
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime
from html.parser import HTMLParser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import parse_qsl, urljoin, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

HOST = '127.0.0.1'
PORT = 8791
ORIGINS = frozenset({'http://localhost:8790', 'http://127.0.0.1:8790'})
FEED = 'https://prasetya.ub.ac.id/category/headline/feed/'
NEWS_FEEDS = {
    'official': 'https://ub.ac.id/id/feed/',
    'prasetya': FEED,
    'selma': 'https://selma.ub.ac.id/id/rss',
    'rsub': 'https://rumahsakit.ub.ac.id/feed/',
    'rsgm': 'https://rsgm.ub.ac.id/feed/',
    'klinik': 'https://klinik.ub.ac.id/feed/',
    'latest': 'http://prasetya.ub.ac.id/feed/',
}
NEWS_REDIRECT_LIMIT = 4
NOTIFICATION_URL = 'https://apps.ub.ac.id/gateway/api/kepegawaian/notification/find_user_notifications'
WS_ROUTES = {
    '/statistics': ('GetStatistik', 'STATISTIK', ('ITEM', 'JML')),
    '/calendar': ('GetKalenderAkademik', 'KALENDER',
                  ('NAMA_KEGIATAN', 'THN_AKAD', 'TGL_MULAI', 'TGL_SELESAI')),
    '/images': ('GetGambar', 'GAMBAR', ('URL_FILE',)),
    '/achievements': ('GetGambar', 'GAMBAR', ('URL_FILE',)),
}
ROUTES = frozenset({'/news', *WS_ROUTES})
IDENTITY = 'gapura-flutter-public-relay-v1'
LIMIT = 2_000_000
CONFIG_PATH = Path(__file__).resolve().parents[1] / '.local' / 'native-config.json'


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *_):
        return None


URL_OPEN = build_opener(NoRedirect).open


def load_config(path=CONFIG_PATH):
    try:
        config = json.loads(path.read_text(encoding='utf-8'))
    except ValueError:
        raise ValueError('Shared UB service configuration is invalid') from None
    keys = {'clientId': 'GAPURA_CLIENT_ID', 'token': 'GAPURA_SERVICE_TOKEN'}
    if not isinstance(config, dict) or not all(
            isinstance(config.get(key), str) and config[key].strip()
            for key in keys.values()):
        raise ValueError('Shared UB service configuration is missing')
    return {name: config[key] for name, key in keys.items()}


def public_url(value, allow_http=False):
    """HTTPS by default; HTTP is permitted only for public RSS URL handling."""
    if not isinstance(value, str):
        return ''
    try:
        parts = urlsplit(value.strip())
        hostname = parts.hostname or ''
        if (parts.scheme in (('http', 'https') if allow_http else ('https',)) and
                (hostname == 'ub.ac.id' or hostname.endswith('.ub.ac.id')) and
                parts.username is None and parts.password is None and
                parts.port in (None, 443 if parts.scheme == 'https' else 80)):
            return value.strip()
    except ValueError:
        pass
    return ''


class PlainHTML(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.text = []
        self.images = []
        self.hidden = 0

    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style'):
            self.hidden += 1
        if tag == 'img' and not self.hidden:
            self.images.append(dict(attrs).get('src', ''))
        if tag in ('p', 'div', 'br', 'li'):
            self.text.append(' ')

    def handle_endtag(self, tag):
        if tag in ('script', 'style') and self.hidden:
            self.hidden -= 1
        if tag in ('p', 'div', 'li'):
            self.text.append(' ')

    def handle_data(self, data):
        if not self.hidden:
            self.text.append(data)


def plain_html(source, limit=600):
    parser = PlainHTML()
    parser.feed(source or '')
    return re.sub(r'\s+', ' ', ''.join(parser.text)).strip()[:limit], parser.images


def normalize_news(body):
    # These feeds do not require DTDs; reject declarations before parsing.
    if b'<!doctype' in body.lower() or b'<!entity' in body.lower():
        raise ValueError('Unsupported feed declaration')
    root = ET.fromstring(body)
    channel = root.find('channel')
    if root.tag != 'rss' or channel is None:
        raise ValueError('Expected RSS feed')
    rows = []
    for item in channel.findall('item')[:50]:
        title, _ = plain_html(item.findtext('title', ''), 250)
        description, images = plain_html(item.findtext('description', ''))
        link = public_url(item.findtext('link', ''), allow_http=True)
        if not title or not link:
            continue
        date = item.findtext('pubDate', '')
        try:
            date = parsedate_to_datetime(date).isoformat()
        except (ValueError, TypeError, OverflowError):
            date = date[:100]
        row = {'title': title, 'description': description, 'link': link, 'date': date}
        for element in item.iter():
            if element.tag.rsplit('}', 1)[-1] in ('thumbnail', 'content', 'enclosure'):
                candidate = element.get('url', '')
                if candidate:
                    images.append(candidate)
        image = next((url for candidate in images
                      if (url := public_url(candidate, allow_http=True))), '')
        if image:
            row['image'] = image
        rows.append(row)
    return rows


def normalize_ws(body, route):
    _, root_key, required = WS_ROUTES[route]
    payload = json.loads(body)
    groups = payload.get(root_key) if isinstance(payload, dict) else None
    if not isinstance(groups, list):
        raise ValueError('Expected UB group list')
    if route == '/achievements':
        records = groups[1].get('PENGHARGAAN') if len(groups) > 1 and isinstance(groups[1], dict) else None
        if not isinstance(records, list) or any(
                not isinstance(row, dict) or not isinstance(row.get('URL_FILE'), str)
                for row in records):
            raise ValueError('Unexpected achievement schema')
        return records
    rows = []
    for group in groups:
        if not isinstance(group, dict) or not group:
            raise ValueError('Expected UB group')
        for name, records in group.items():
            if not isinstance(records, list):
                raise ValueError('Expected UB record list')
            for record in records:
                if not isinstance(record, dict) or any(
                        not isinstance(record.get(key), str) for key in required):
                    raise ValueError('Unexpected UB record schema')
                rows.append({**record, '_group': name})
    return rows


def news_source(path):
    """Only enum source IDs, never URLs, repeated fields or extra arguments."""
    parsed = urlsplit(path)
    if (parsed.path != '/news' or parsed.scheme or parsed.netloc or parsed.fragment):
        raise ValueError('Invalid news route')
    if not parsed.query:
        return 'prasetya'
    pairs = parse_qsl(parsed.query, keep_blank_values=True,
                      strict_parsing=True, errors='strict')
    if len(pairs) != 1 or pairs[0][0] != 'source' or pairs[0][1] not in NEWS_FEEDS:
        raise ValueError('Unknown news source')
    return pairs[0][1]


def is_news_path(path):
    try:
        parsed = urlsplit(path)
        return parsed.path == '/news' and not parsed.scheme and not parsed.netloc
    except ValueError:
        return False


def read_news_feed(source, opener=None):
    """Exact fixed source, public-only bounded redirects, no scheme fallback."""
    if source not in NEWS_FEEDS:
        raise ValueError('Unknown news source')
    initial = current = NEWS_FEEDS[source]
    redirects = []
    deadline = time.monotonic() + 18
    while True:
        if not public_url(current, allow_http=True):
            raise ValueError('News redirect destination is not allowed')
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError('News deadline exceeded')
        request = Request(current, method='GET', headers={
            'Accept': 'application/rss+xml',
            'User-Agent': 'GapuraFlutterReconstruction/1.0',
        })
        try:
            response = (opener or URL_OPEN)(request, timeout=min(12, remaining))
        except HTTPError as error:
            if error.code not in (301, 302, 303, 307, 308):
                raise
            response = error
        with response:
            if response.status in (301, 302, 303, 307, 308):
                location = response.headers.get('Location')
                if not location or len(redirects) >= NEWS_REDIRECT_LIMIT:
                    raise ValueError('News redirect limit or missing location')
                destination = urljoin(current, location)
                if not public_url(destination, allow_http=True):
                    raise ValueError('News redirect destination is not allowed')
                redirects.append({'status': response.status, 'from': current,
                                  'to': destination})
                current = destination
                continue
            if response.status != 200:
                raise ValueError(f'News service unavailable (HTTP {response.status})')
            chunks, size = [], 0
            read_chunk = getattr(response, 'read1', response.read)
            while True:
                if time.monotonic() >= deadline:
                    raise TimeoutError('News deadline exceeded')
                chunk = read_chunk(min(65536, LIMIT + 1 - size))
                if not chunk:
                    break
                size += len(chunk)
                if size > LIMIT:
                    raise ValueError('News response exceeds limit')
                chunks.append(chunk)
            return b''.join(chunks), {'source': source, 'initial_url': initial,
                                     'final_url': current, 'redirects': redirects}


def fetch_route(route, config, opener=None):
    """Fixed service routes and enumerated news IDs; arbitrary URLs never enter."""
    if is_news_path(route):
        source = news_source(route)  # Validate before any network request.
        body, _ = read_news_feed(source, opener)
        return normalize_news(body)
    if route not in WS_ROUTES:
        raise ValueError('Unknown route')
    method, _, _ = WS_ROUTES[route]
    request = Request('https://apigapura.ub.ac.id/WS/' + method, method='POST', headers={
        'Content-Type': 'application/json', 'Authorization': '',
        'Client-Id': config['clientId'], 'Token': config['token'],
    })
    with (opener or URL_OPEN)(request, timeout=12) as response:
        if response.status != 200:
            raise ValueError('Upstream service unavailable')
        body = response.read(LIMIT + 1)
    if len(body) > LIMIT:
        raise ValueError('Upstream response exceeds limit')
    return normalize_ws(body, route)


def notification_identity(path):
    """A single fixed reader, never an arbitrary query or upstream URL."""
    try:
        parsed = urlsplit(path)
        if parsed.path != '/notifications' or parsed.fragment or parsed.netloc or parsed.scheme:
            return None
        pairs = parse_qsl(parsed.query, keep_blank_values=True, strict_parsing=True, errors='strict')
        if len(pairs) != 1 or pairs[0][0] != 'username':
            return None
        username = pairs[0][1]
        return username if re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._@+\-]{0,199}', username) else None
    except (ValueError, UnicodeError):
        return None


def fetch_notifications(username, config, opener=None):
    if not isinstance(username, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._@+\-]{0,199}', username):
        raise ValueError('Invalid account identity')
    request = Request(NOTIFICATION_URL, method='POST',
        headers={'Content-Type': 'application/json', 'Authorization': '',
                 'Client-Id': config['clientId'], 'Token': config['token']},
        data=json.dumps({'id_notification': None, 'title': None, 'body': None,
                         'image_url': None, 'sentdatetime': None,
                         'username': username, 'timestamp': None}).encode('utf-8'))
    with (opener or URL_OPEN)(request, timeout=12) as response:
        if response.status != 200:
            raise ValueError('Notification service unavailable')
        body = response.read(LIMIT + 1)
    if len(body) > LIMIT:
        raise ValueError('Notification response exceeds limit')
    rows = json.loads(body)
    for _ in range(2):
        if isinstance(rows, dict):
            rows = rows.get('data')
    if not isinstance(rows, list) or any(not isinstance(row, dict) or
            not any(isinstance(row.get(key), str) for key in ('title', 'body')) for row in rows):
        raise ValueError('Unexpected notification schema')
    return rows


class RelayServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address=(HOST, PORT), config=None):
        super().__init__(address, Handler)
        self.config = config or {}
        self.cache = {}
        self.cache_lock = threading.Lock()
        self.fetcher = fetch_route
        self.notification_fetcher = fetch_notifications

    def read_route(self, route):
        with self.cache_lock:
            stamp, records = self.cache.get(route, (0, None))
            if time.monotonic() - stamp < 120:
                return records
        records = self.fetcher(route, self.config)
        with self.cache_lock:
            self.cache[route] = (time.monotonic(), records)
        return records


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def allowed(self):
        return (
            self.headers.get_all('Origin', []) in [[origin] for origin in ORIGINS] and
            self.headers.get('Host') == f'{HOST}:{self.server.server_port}' and
            self.requestline.split()[1] == self.path and
            (self.path in ROUTES | {'/health'} or is_news_path(self.path) or
             notification_identity(self.path) is not None) and
            self.headers.get('Content-Length', '0') == '0' and
            not self.headers.get('Transfer-Encoding') and
            not self.headers.get('Authorization') and
            not self.headers.get('Cookie')
        )

    def respond(self, status, payload=None):
        body = json.dumps(payload, ensure_ascii=False).encode('utf-8') if payload is not None else b''
        self.send_response(status)
        origin = self.headers.get('Origin')
        if origin in ORIGINS:
            self.send_header('Access-Control-Allow-Origin', origin)
            self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
            self.send_header('Access-Control-Allow-Private-Network', 'true')
        self.send_header('Vary', 'Origin')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(body)

    def do_OPTIONS(self):
        if (not self.allowed() or
                self.headers.get('Access-Control-Request-Method', 'GET') != 'GET' or
                self.headers.get('Access-Control-Request-Headers')):
            self.respond(403, {'error': 'Permintaan tidak diizinkan.'})
            return
        self.respond(204)

    def do_GET(self):
        if not self.allowed():
            self.respond(403, {'error': 'Permintaan tidak diizinkan.'})
            return
        if self.path == '/health':
            self.respond(200, {'service': IDENTITY})
            return
        if is_news_path(self.path):
            try:
                source = news_source(self.path)
            except (ValueError, UnicodeError):
                self.respond(400, {'error': 'Sumber berita tidak valid.'})
                return
            route = '/news' if self.path == '/news' else '/news?source=' + source
        else:
            route = self.path
        try:
            username = notification_identity(self.path)
            if username is not None:
                # Personal results are never stored in the public-response cache.
                self.respond(200, self.server.notification_fetcher(username, self.server.config))
                return
            self.respond(200, self.server.read_route(route))
        except Exception:
            # Never reflect upstream bodies, configured credentials or exceptions.
            self.respond(502, {'error': 'Layanan UB belum tersedia. Silakan coba lagi.'})

    def do_POST(self):
        self.respond(405, {'error': 'Hanya pembacaan GET yang diizinkan.'})


def main():
    try:
        config = load_config()
    except (OSError, ValueError, KeyError):
        config = {}
        print('Shared service config unavailable; only public news can be read.', flush=True)
    server = RelayServer(config=config)
    print(f'Gapura public relay: http://{HOST}:{PORT} (Flutter web port 8790)', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
