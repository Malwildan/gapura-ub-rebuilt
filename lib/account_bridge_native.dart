import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;

import 'model/academic_term.dart';
import 'service/session_store.dart';
import 'service/student_attendance.dart';
import 'model/student_attendance.dart';
import 'service/survey_submission.dart';

/// Native counterpart of the browser account bridge, using recovered IAM flows.
/// Tokens stay in this app's private SQLite store. Fixed readers and explicit,
/// guarded student submissions are exposed through the facade.
class AccountBridge {
  AccountBridge({
    http.Client? client,
    FlutterAppAuth? appAuth,
    SessionStore? store,
  }) : _client = client ?? http.Client(),
       _appAuth = appAuth ?? const FlutterAppAuth(),
       _store = store ?? SqliteSessionStore();

  static const _issuer = 'https://iam.ub.ac.id/auth/realms/ub';
  static const _clientId = 'GapuraUb2020-Mobile';
  static const _redirect = 'ub.gapura.app:/oauthredirect';
  static const _secret = String.fromEnvironment('GAPURA_OAUTH_CLIENT_SECRET');
  static const _scopes = [
    'openid',
    'offline_access',
    'profile',
    'email',
    'address',
    'phone',
    'roles',
    'web-origins',
    'microprofile-jwt',
    'groups',
    'nip_nik',
  ];
  static const _configuration = AuthorizationServiceConfiguration(
    authorizationEndpoint: '$_issuer/protocol/openid-connect/auth',
    tokenEndpoint: '$_issuer/protocol/openid-connect/token',
    endSessionEndpoint: '$_issuer/protocol/openid-connect/logout',
  );
  final http.Client _client;
  final FlutterAppAuth _appAuth;
  final SessionStore _store;
  Future<Map<String, dynamic>>? _refreshing;
  bool _attendanceInFlight = false;

  Future<Map<String, dynamic>> request(
    String action, {
    Map<String, dynamic> parameters = const {},
  }) async {
    final submit = action == 'surveySubmit';
    final recovering =
        action == 'surveyStatus' &&
        surveySubmissionGuard.unknown &&
        !surveySubmissionGuard.inFlight;
    if (submit) surveySubmissionGuard.begin(parameters);
    try {
      final checked = submit
          ? Map<String, dynamic>.from(jsonDecode(jsonEncode(parameters)) as Map)
          : parameters;
      final result = await _request(action, parameters: checked);
      if (recovering) surveySubmissionGuard.statusRead(result);
      return result;
    } catch (_) {
      if (submit && surveySubmissionGuard.unknown) {
        throw StateError(surveyUnknown);
      }
      rethrow;
    } finally {
      if (submit) surveySubmissionGuard.inFlight = false;
    }
  }

  Future<Map<String, dynamic>> _request(
    String action, {
    Map<String, dynamic> parameters = const {},
  }) async {
    if (action == 'disconnect' || action == 'logout') {
      await _store.clear();
      return {'connected': false};
    }
    if (action == 'login') return login();
    const actions = {
      'connection',
      'identity',
      'profile',
      'schedule',
      'transcript',
      'finance',
      'announcements',
      'materials',
      'krs',
      'grades',
      'history',
      'surveyStatus',
      'surveyQuestions',
      'attendanceMeetings',
    };
    if (!actions.contains(action) &&
        action != 'attendanceSubmit' &&
        action != 'surveySubmit') {
      throw StateError('Pembaca akun tidak tersedia.');
    }
    const termActions = {
      'schedule',
      'krs',
      'grades',
      'transcript',
      'finance',
      'history',
      'surveyStatus',
      'surveyQuestions',
      'attendanceMeetings',
    };
    final selection = termActions.contains(action)
        ? AcademicTerm.fromParameters(parameters)
        : const AcademicTerm();
    if (action == 'finance' && (selection.isExplicit || selection.short)) {
      throw StateError(
        'Tagihan memakai periode layanan UB dan tidak menerima pilihan semester.',
      );
    }
    if (action == 'schedule' && selection.isExplicit) {
      throw StateError(
        'Jadwal kuliah hanya menerima pilihan semester reguler atau pendek.',
      );
    }
    final chosenCourse = parameters['course'];
    if (action == 'history' &&
        (selection.short ||
            (chosenCourse is Map &&
                [true, 1, '1'].contains(chosenCourse['IS_PENDEK'])))) {
      throw StateError(
        'Riwayat materi semester pendek belum tersedia untuk kontrak ini.',
      );
    }
    if (action == 'attendanceSubmit') validateAttendanceChoice(parameters);
    final session = await _session();
    if (session == null) {
      if (action == 'connection') return {'connected': false};
      throw StateError('Masuk dengan akun UB untuk membaca data Anda.');
    }
    final active = await _freshSession(session);
    if (action == 'connection') {
      return {'connected': true, 'username': active['username'] ?? ''};
    }
    final accessToken = active['accessToken'] as String;
    Future<Map<String, dynamic>> get(
      String path, [
      Map<String, String>? query,
    ]) => _readAccount(path, query, accessToken);
    Future<Map<String, dynamic>> currentProfile() async {
      final response = await _readAccount(
        '/mahasiswa/index/getBioMhs_v2',
        null,
        accessToken,
        method: 'POST',
      );
      final wrapper = response['mhs'];
      final records = wrapper is Map ? wrapper['data'] : null;
      if (records is! List || records.isEmpty || records.first is! Map) {
        throw StateError(
          'Profil mahasiswa UB belum tersedia. Muat profil kembali.',
        );
      }
      return Map<String, dynamic>.from(records.first as Map);
    }

    String contextField(Map record, String key) {
      final value = record[key];
      if ((value is! String && value is! num) || '$value'.trim().isEmpty) {
        throw StateError(
          'Data akademik akun UB belum lengkap. Muat profil dan jadwal kembali.',
        );
      }
      return '$value';
    }

    if (action == 'surveySubmit') {
      return submitHealthSurvey(parameters: parameters, read: get, write: get);
    }
    if (action == 'attendanceSubmit') {
      if (_attendanceInFlight) throw StateError('Presensi sedang dikirim.');
      _attendanceInFlight = true;
      try {
        return await submitStudentAttendance(
          parameters: parameters,
          read: get,
          profile: currentProfile,
          write: (path, query) => _readAccount(path, query, accessToken),
        );
      } finally {
        _attendanceInFlight = false;
      }
    }
    if (action == 'surveyStatus') {
      return get('/mahasiswa/index/cekStatusSurveyHarian/');
    }
    if (action == 'surveyQuestions') {
      return get('/mahasiswa/index/getPertanyaanSurvey/');
    }
    if (action == 'attendanceMeetings' &&
        surveyGate(await get('/mahasiswa/index/cekStatusSurveyHarian/')) !=
            SurveyGate.complete) {
      throw StateError('Survey kesehatan belum terverifikasi.');
    }
    const schedulePath = '/mahasiswa/getJadwalKuliah/';
    switch (action) {
      case 'identity':
        return _readAccount('/profile', null, accessToken, method: 'POST');
      case 'profile':
        return _readAccount(
          '/mahasiswa/index/getBioMhs_v2',
          null,
          accessToken,
          method: 'POST',
        );
      case 'schedule':
        return get(schedulePath, selection.query());
      case 'transcript':
        return get('/mahasiswa/getKHS/', selection.query(allTerms: true));
      case 'finance':
        return get('/mahasiswa/getTagihan/', {
          'tahun': 'x',
          'is_ganjil': 'x',
          'is_pendek': '0',
        });
      case 'announcements':
        return get('/mahasiswa/index/getPengumumanMhs/');
      case 'attendanceMeetings':
      case 'materials':
        final profile = await currentProfile();
        return get('/mahasiswa/getDataMateriByMhs/', {
          'is_aktif': parameters['active'] == false ? '0' : '1',
          'k_fakultas': contextField(profile, 'K_FAKULTAS'),
          'k_cabang': contextField(profile, 'K_CABANG'),
        });
    }
    if ((action == 'krs' || action == 'grades') && selection.isExplicit) {
      return get(
        '/mahasiswa/${action == 'krs' ? 'getKRS' : 'getKHS'}/',
        selection.query(),
      );
    }
    final schedule = await get(schedulePath, {
      'is_pendek': selection.short ? '1' : '0',
    });
    final jadwal = schedule['jadwal'];
    final courses = jadwal is Map ? jadwal['data'] : null;
    if (courses is! List || courses.any((row) => row is! Map)) {
      throw StateError('Format jadwal UB tidak dikenali.');
    }
    if (action == 'history') {
      final chosen = parameters['course'];
      if (chosen is! Map) {
        throw StateError('Pilih mata kuliah dari jadwal Anda.');
      }
      final matching = courses.where(
        (row) => [
          'K_MK',
          'KELAS',
          'TAHUN',
          'IS_GANJIL',
        ].every((key) => '${row[key] ?? ''}' == '${chosen[key] ?? ''}'),
      );
      if (matching.isEmpty) {
        throw StateError('Mata kuliah tidak ditemukan pada jadwal akun ini.');
      }
      final course = matching.first as Map;
      if ([true, 1, '1'].contains(course['IS_PENDEK'])) {
        throw StateError(
          'Riwayat materi semester pendek belum tersedia untuk kontrak ini.',
        );
      }
      const fields = {
        'k_fakultas': 'K_FAKULTAS',
        'k_jenjang': 'K_JENJANG',
        'k_jurusan': 'K_JURUSAN',
        'k_prog_studi': 'K_PROG_STUDI',
        'k_mk': 'K_MK',
        'thn_mk': 'THN_MK',
        'tahun': 'TAHUN',
        'is_ganjil': 'IS_GANJIL',
        'kelas': 'KELAS',
      };
      final cabang = course['K_CABANG'];
      final branchContext =
          (cabang is String || cabang is num) && '$cabang'.trim().isNotEmpty
          ? course
          : await currentProfile();
      return get('/mahasiswa/index/getRiwayatMateriMhs/', {
        for (final field in fields.entries)
          field.key: contextField(course, field.value),
        'is_pendek': '0',
        'k_tipe_seleksi': 'x',
        'k_cabang': contextField(branchContext, 'K_CABANG'),
      });
    }
    final terms = courses.where(
      (row) => row['TAHUN'] != null && row['IS_GANJIL'] != null,
    );
    if (terms.isEmpty) {
      throw StateError('Semester berjalan belum tersedia pada jadwal Anda.');
    }
    final term = terms.first as Map;
    final year = term['TAHUN'];
    final odd = term['IS_GANJIL'];
    if ((year is! String && year is! num) ||
        ![true, false, 0, 1, '0', '1'].contains(odd)) {
      throw StateError('Semester berjalan belum dapat dibaca dari jadwal UB.');
    }
    final current = AcademicTerm.fromParameters({
      'year': '$year',
      'odd': [true, 1, '1'].contains(odd),
      'short': selection.short,
    });
    return get(
      '/mahasiswa/${action == 'krs' ? 'getKRS' : 'getKHS'}/',
      current.query(),
    );
  }

  /// Login is only initiated by an explicit user action.
  Future<Map<String, dynamic>> login() async {
    if (_secret.isEmpty) {
      throw StateError(
        'Konfigurasi IAM belum tersedia. Jalankan '
        'salin config/native.example.json ke .local/native-config.json, isi konfigurasi yang sah, lalu gunakan '
        '--dart-define-from-file=.local/native-config.json saat flutter run.',
      );
    }
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirect,
          clientSecret: _secret,
          serviceConfiguration: _configuration,
          scopes: _scopes,
        ),
      );
      final session = await _save(result);
      return {'connected': true, 'username': session['username'] ?? ''};
    } on FlutterAppAuthUserCancelledException {
      throw StateError('Proses masuk dibatalkan.');
    } on PlatformException {
      throw StateError(
        'IAM UB belum menyelesaikan proses masuk. Coba kembali.',
      );
    }
  }

  Future<Map<String, dynamic>?> _session() async {
    final value = await _store.read();
    if (value == null) return null;
    if (value['accessToken'] is String && value['expiresAt'] is int) {
      return value;
    }
    // An unreadable local record is discarded; it never initiates login.
    await _store.clear();
    return null;
  }

  Future<Map<String, dynamic>> _freshSession(
    Map<String, dynamic> session,
  ) async {
    final cutoff = DateTime.now()
        .add(const Duration(seconds: 60))
        .millisecondsSinceEpoch;
    if ((session['expiresAt'] as int) > cutoff) return session;
    final refresh = session['refreshToken'];
    if (refresh is! String || refresh.isEmpty) {
      await _store.clear();
      throw StateError('Sesi UB kedaluwarsa. Silakan masuk kembali.');
    }
    return _refreshing ??= _refresh(
      session,
    ).whenComplete(() => _refreshing = null);
  }

  Future<Map<String, dynamic>> _refresh(Map<String, dynamic> previous) async {
    try {
      final result = await _appAuth.token(
        TokenRequest(
          _clientId,
          _redirect,
          clientSecret: _secret.isEmpty ? null : _secret,
          refreshToken: previous['refreshToken'] as String,
          serviceConfiguration: _configuration,
          scopes: _scopes,
        ),
      );
      return await _save(result, previous: previous);
    } on PlatformException {
      throw StateError(
        'Sesi UB tidak dapat diperbarui. Periksa jaringan atau masuk kembali.',
      );
    }
  }

  Future<Map<String, dynamic>> _save(
    TokenResponse result, {
    Map<String, dynamic>? previous,
  }) async {
    final token = result.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('IAM UB tidak mengembalikan sesi yang valid.');
    }
    final claims = _claims(token);
    final expiry =
        result.accessTokenExpirationDateTime?.millisecondsSinceEpoch ??
        (claims['exp'] is num ? ((claims['exp'] as num) * 1000).toInt() : 0);
    if (expiry <= DateTime.now().millisecondsSinceEpoch) {
      throw StateError('IAM UB mengembalikan sesi yang sudah kedaluwarsa.');
    }
    final record = <String, dynamic>{
      'accessToken': token,
      'refreshToken': result.refreshToken ?? previous?['refreshToken'],
      'idToken': result.idToken ?? previous?['idToken'],
      'expiresAt': expiry,
      'username':
          claims['preferred_username']?.toString() ??
          previous?['username'] ??
          '',
    };
    await _store.write(record);
    return record;
  }

  Map<String, dynamic> _claims(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final value = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return value is Map ? Map<String, dynamic>.from(value) : {};
    } on FormatException {
      return {};
    }
  }

  Future<Map<String, dynamic>> _readAccount(
    String path,
    Map<String, String>? query,
    String token, {
    String method = 'GET',
  }) async {
    try {
      final request =
          http.Request(method, Uri.https('api.ub.ac.id', path, query))
            ..followRedirects = false
            ..headers.addAll({'Authorization': 'Bearer $token'});
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw StateError(
          'Pembacaan akun ditolak UB (HTTP ${response.statusCode}).',
        );
      }
      final chunks = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 15),
      )) {
        chunks.addAll(chunk);
        if (chunks.length > 2000000) {
          throw StateError('Respons akun terlalu besar.');
        }
      }
      final payload = jsonDecode(utf8.decode(chunks));
      if (payload is! Map) throw const FormatException();
      return Map<String, dynamic>.from(payload);
    } on TimeoutException {
      throw StateError('Layanan akun UB terlalu lama merespons. Coba kembali.');
    } on http.ClientException {
      throw StateError(
        'Jaringan UB tidak dapat dihubungi. Periksa koneksi Anda.',
      );
    } on FormatException {
      throw StateError('UB belum mengembalikan data akun yang dapat dibaca.');
    }
  }
}
