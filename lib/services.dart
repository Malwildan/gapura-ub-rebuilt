import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'model/news_feed.dart';

/// Native builds use direct service/feed readers. Browser builds use the
/// loopback relay so shared service configuration stays outside web assets.
class GapuraService {
  GapuraService({
    http.Client? client,
    String baseUrl = const String.fromEnvironment(
      'GAPURA_API',
      defaultValue: 'http://127.0.0.1:8791',
    ),
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final String _baseUrl;

  Future<List<Map<String, dynamic>>> news() => _read('news');
  Future<List<Map<String, dynamic>>> newsFeed(NewsFeed feed) =>
      _read('news', feed: feed);
  Future<List<Map<String, dynamic>>> latestNews() => newsFeed(NewsFeed.latest);
  Future<List<Map<String, dynamic>>> statistics() => _read('statistics');
  Future<List<Map<String, dynamic>>> calendar() => _read('calendar');
  Future<List<Map<String, dynamic>>> images() => _read('images');
  Future<List<Map<String, dynamic>>> achievements() => _read('achievements');

  /// Read-only notifications for the identity obtained from AccountBridge.
  /// This sends no IAM access token and never marks or deletes a notification.
  Future<List<Map<String, dynamic>>> notifications(String username) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._@+\-]{0,199}$').hasMatch(username)) {
      throw const GapuraServiceException('Identitas akun UB belum tersedia.');
    }
    return _read('notifications', username: username);
  }

  Future<List<Map<String, dynamic>>> _read(
    String route, {
    String? username,
    NewsFeed? feed,
  }) async {
    try {
      if (!kIsWeb) {
        return await _readNative(route, username: username, feed: feed);
      }
      final uri = Uri.parse('$_baseUrl/$route').replace(
        queryParameters: username == null && feed == null
            ? null
            : {'username': ?username, 'source': ?feed?.id},
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 18));
      if (response.statusCode != 200) {
        throw const GapuraServiceException(
          'Layanan UB belum tersedia. Coba muat ulang beberapa saat lagi.',
        );
      }
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload is! List || payload.any((row) => row is! Map)) {
        throw const FormatException('Expected list of records');
      }
      return payload
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    } on TimeoutException {
      throw const GapuraServiceException(
        'Layanan UB terlalu lama merespons. Silakan coba lagi.',
      );
    } on http.ClientException {
      throw GapuraServiceException(
        kIsWeb
            ? 'Koneksi belum tersedia. Jalankan python tool/api_relay.py '
                  'dan buka Flutter pada port 8790.'
            : 'Layanan UB belum dapat dihubungi. Periksa koneksi internet Anda.',
      );
    } on FormatException {
      throw const GapuraServiceException(
        'Format data layanan UB belum dapat dibaca.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _readNative(
    String route, {
    String? username,
    NewsFeed? feed,
  }) async {
    if (route == 'news') {
      return _readNativeNews(feed ?? NewsFeed.prasetya);
    }
    const methods = {
      'statistics': ('GetStatistik', 'STATISTIK'),
      'calendar': ('GetKalenderAkademik', 'KALENDER'),
      'images': ('GetGambar', 'GAMBAR'),
      'achievements': ('GetGambar', 'GAMBAR'),
    };
    final http.Request request;
    {
      const clientId = String.fromEnvironment('GAPURA_CLIENT_ID');
      const serviceToken = String.fromEnvironment('GAPURA_SERVICE_TOKEN');
      if (clientId.isEmpty || serviceToken.isEmpty) {
        throw const GapuraServiceException(
          'Konfigurasi layanan belum tersedia. Jalankan '
          'salin config/native.example.json ke .local/native-config.json, isi konfigurasi yang sah, lalu flutter run '
          '--dart-define-from-file=.local/native-config.json.',
        );
      }
      final method = methods[route];
      if (method == null && route != 'notifications') {
        throw const FormatException('Unknown reader');
      }
      request =
          http.Request(
              'POST',
              route == 'notifications'
                  ? Uri.https(
                      'apps.ub.ac.id',
                      '/gateway/api/kepegawaian/notification/find_user_notifications',
                    )
                  : Uri.https('apigapura.ub.ac.id', '/WS/${method!.$1}'),
            )
            ..headers.addAll({
              'Content-Type': 'application/json',
              'Authorization': '',
              'Client-Id': clientId,
              'Token': serviceToken,
            });
      if (route == 'notifications') {
        request.body = jsonEncode({
          'id_notification': null,
          'title': null,
          'body': null,
          'image_url': null,
          'sentdatetime': null,
          'username': username,
          'timestamp': null,
        });
      }
    }
    request.followRedirects = false;
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw GapuraServiceException(
        'Layanan UB belum tersedia (HTTP ${response.statusCode}).',
      );
    }
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 15),
    )) {
      bytes.addAll(chunk);
      if (bytes.length > 2000000) {
        throw const GapuraServiceException('Respons layanan UB terlalu besar.');
      }
    }
    final text = utf8.decode(bytes);
    final payload = jsonDecode(text);
    if (route == 'notifications') {
      dynamic rows = payload;
      if (rows is Map) rows = rows['data'];
      if (rows is Map) rows = rows['data'];
      if (rows is! List ||
          rows.any(
            (row) =>
                row is! Map ||
                (row['title'] is! String && row['body'] is! String),
          )) {
        throw const FormatException('Invalid notification records');
      }
      return rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
    }
    final groups = payload is Map ? payload[methods[route]!.$2] : null;
    if (groups is! List) throw const FormatException('Expected groups');
    if (route == 'achievements') return achievementRecords(groups);
    final required = switch (route) {
      'statistics' => ['ITEM', 'JML'],
      'calendar' => ['NAMA_KEGIATAN', 'THN_AKAD', 'TGL_MULAI', 'TGL_SELESAI'],
      _ => ['URL_FILE'],
    };
    final records = <Map<String, dynamic>>[];
    for (final group in groups) {
      if (group is! Map || group.isEmpty) {
        throw const FormatException('Invalid group');
      }
      for (final entry in group.entries) {
        if (entry.value is! List) {
          throw const FormatException('Invalid records');
        }
        for (final row in entry.value as List) {
          if (row is! Map || required.any((key) => row[key] is! String)) {
            throw const FormatException('Invalid record');
          }
          records.add({
            ...Map<String, dynamic>.from(row),
            '_group': '${entry.key}',
          });
        }
      }
    }
    return records;
  }

  Future<List<Map<String, dynamic>>> _readNativeNews(NewsFeed feed) async {
    final abort = Completer<void>();
    const timeout = Duration(seconds: 18);
    final timer = Timer(timeout, () => abort.complete());
    try {
      return await _followNews(feed.uri, abort.future).timeout(timeout);
    } on http.RequestAbortedException {
      throw TimeoutException('Berita UB terlalu lama merespons.');
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<List<Map<String, dynamic>>> _followNews(
    Uri initial,
    Future<void> abort,
  ) async {
    var uri = initial;
    for (var redirects = 0; ; redirects++) {
      if (!_isNewsUrl(uri)) {
        throw const GapuraServiceException('Tujuan berita UB tidak diizinkan.');
      }
      final request = http.AbortableRequest('GET', uri, abortTrigger: abort)
        ..followRedirects = false
        ..headers['Accept'] = 'application/rss+xml';
      final response = await _client.send(request);
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        await response.stream.listen((_) {}).cancel();
        final location = response.headers['location'];
        if (redirects >= 4 || location == null || location.isEmpty) {
          throw const GapuraServiceException(
            'Pengalihan berita UB tidak dapat diikuti.',
          );
        }
        if (_hasNewsUserInfo(location)) {
          throw const GapuraServiceException(
            'Tujuan berita UB tidak diizinkan.',
          );
        }
        uri = uri.resolve(location);
        continue;
      }
      if (response.statusCode != 200) {
        await response.stream.listen((_) {}).cancel();
        throw GapuraServiceException(
          'Berita UB belum tersedia (HTTP ${response.statusCode}).',
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > 2000000) {
          throw const GapuraServiceException(
            'Respons berita UB terlalu besar.',
          );
        }
        bytes.addAll(chunk);
      }
      return _newsRecords(utf8.decode(bytes));
    }
  }

  bool _isNewsUrl(Uri uri) =>
      ['http', 'https'].contains(uri.scheme) &&
      uri.userInfo.isEmpty &&
      !uri.authority.contains('@') &&
      uri.port == (uri.scheme == 'https' ? 443 : 80) &&
      (uri.host == 'ub.ac.id' || uri.host.endsWith('.ub.ac.id'));

  // Uri canonicalizes an empty userinfo marker away; reject it before parsing.
  bool _hasNewsUserInfo(String value) => RegExp(
    r'^(?:https?:)?//[^/?#]*@',
    caseSensitive: false,
  ).hasMatch(value.trim());

  List<Map<String, dynamic>> _newsRecords(String text) {
    if (RegExp(r'<!\s*(DOCTYPE|ENTITY)', caseSensitive: false).hasMatch(text)) {
      throw const FormatException('Unexpected feed declaration');
    }
    try {
      final xml = XmlDocument.parse(text);
      if (xml.rootElement.name.local != 'rss' ||
          xml.rootElement.getElement('channel') == null) {
        throw const FormatException('Expected RSS');
      }
      final rows = <Map<String, dynamic>>[];
      for (final item in xml.findAllElements('item').take(50)) {
        final title = _plain(item.getElement('title')?.innerText ?? '', 250);
        final description = item.getElement('description')?.innerText ?? '';
        final link = _newsUrl(item.getElement('link')?.innerText);
        if (title.isEmpty || link.isEmpty) continue;
        final row = <String, dynamic>{
          'title': title,
          'description': _plain(description, 600),
          'link': link,
          'date': item.getElement('pubDate')?.innerText ?? '',
        };
        final imageTags = RegExp(
          r'''<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["']''',
          caseSensitive: false,
        );
        final candidates = [
          for (final match in imageTags.allMatches(description)) match.group(1),
          for (final node in item.descendantElements)
            if (['thumbnail', 'content', 'enclosure'].contains(node.name.local))
              node.getAttribute('url'),
        ];
        final images = candidates.map(_newsUrl).where((url) => url.isNotEmpty);
        if (images.isNotEmpty) row['image'] = images.first;
        rows.add(row);
      }
      return rows;
    } on XmlException {
      throw const FormatException('Invalid RSS');
    }
  }

  String _newsUrl(String? value) {
    try {
      if (_hasNewsUserInfo(value ?? '')) return '';
      final uri = Uri.tryParse((value ?? '').trim());
      return uri != null && _isNewsUrl(uri) ? uri.toString() : '';
    } on FormatException {
      return '';
    }
  }

  String _plain(String value, int limit) {
    var result = value
        .replaceAll(
          RegExp(
            r'<(script|style)\b[^>]*>.*?</\1\s*>',
            caseSensitive: false,
            dotAll: true,
          ),
          '',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (result.length > limit) result = result.substring(0, limit);
    return result;
  }

  void close() => _client.close();
}

/// Original getAchievement selects GAMBAR[1].PENGHARGAAN, not every image group.
List<Map<String, dynamic>> achievementRecords(List<dynamic> groups) {
  final rows = groups.length > 1 && groups[1] is Map
      ? (groups[1] as Map)['PENGHARGAAN']
      : null;
  if (rows is! List ||
      rows.any((row) => row is! Map || row['URL_FILE'] is! String)) {
    throw const FormatException('Invalid achievement records');
  }
  return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
}

class GapuraServiceException implements Exception {
  const GapuraServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
