import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../model/general_announcement.dart';

enum GeneralAnnouncementsPlatform { android, web, unsupported }

enum GeneralAnnouncementsFailure {
  unsupportedPlatform,
  missingConfiguration,
  initialization,
  fetch,
  parsing,
}

/// Deliberately excludes SDK error messages, raw config and response contents.
class GeneralAnnouncementsException implements Exception {
  const GeneralAnnouncementsException(this.failure);

  final GeneralAnnouncementsFailure failure;

  @override
  String toString() => 'General announcements unavailable: ${failure.name}';
}

/// Supply only hash-verified recovered values through ignored build defines.
/// Android options do not establish a web or Apple Firebase registration.
class GeneralAnnouncementsFirebaseConfig {
  const GeneralAnnouncementsFirebaseConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    required this.storageBucket,
  });

  const GeneralAnnouncementsFirebaseConfig.fromEnvironment()
    : apiKey = const String.fromEnvironment('GAPURA_FIREBASE_API_KEY'),
      appId = const String.fromEnvironment('GAPURA_FIREBASE_APP_ID'),
      messagingSenderId = const String.fromEnvironment(
        'GAPURA_FIREBASE_MESSAGING_SENDER_ID',
      ),
      projectId = const String.fromEnvironment('GAPURA_FIREBASE_PROJECT_ID'),
      storageBucket = const String.fromEnvironment(
        'GAPURA_FIREBASE_STORAGE_BUCKET',
      );

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String storageBucket;

  void validate() {
    if ([
      apiKey,
      appId,
      messagingSenderId,
      projectId,
      storageBucket,
    ].any((value) => value.trim().isEmpty)) {
      throw const GeneralAnnouncementsException(
        GeneralAnnouncementsFailure.missingConfiguration,
      );
    }
  }
}

/// Fake this boundary in tests; no Firebase instance is needed by the model or
/// orchestration tests. Methods are invoked only by initialize()/fetch().
abstract interface class GeneralAnnouncementsSdk {
  Future<void> initialize(GeneralAnnouncementsFirebaseConfig config);
  Future<void> setConfigSettings({
    required Duration fetchTimeout,
    required Duration minimumFetchInterval,
  });
  Future<bool> fetchAndActivate();
  String getString(String key);
}

/// Explicit runtime adapter for shipped core 4.0.0 / remote_config 6.0.0 APIs.
/// The SDK supplies the actual rebuilt package/certificate and owns transport,
/// Installations and SDK cache. No original publisher identity is spoofed.
class FlutterFireGeneralAnnouncementsSdk implements GeneralAnnouncementsSdk {
  FirebaseRemoteConfig? _remoteConfig;

  @override
  Future<void> initialize(GeneralAnnouncementsFirebaseConfig config) async {
    final app = await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: config.apiKey,
        appId: config.appId,
        messagingSenderId: config.messagingSenderId,
        projectId: config.projectId,
        storageBucket: config.storageBucket,
      ),
    );
    _remoteConfig = FirebaseRemoteConfig.instanceFor(app: app);
  }

  FirebaseRemoteConfig get _config =>
      _remoteConfig ?? (throw StateError('Initialize announcements first'));

  @override
  Future<void> setConfigSettings({
    required Duration fetchTimeout,
    required Duration minimumFetchInterval,
  }) => _config.setConfigSettings(
    RemoteConfigSettings(
      fetchTimeout: fetchTimeout,
      minimumFetchInterval: minimumFetchInterval,
    ),
  );

  @override
  Future<bool> fetchAndActivate() => _config.fetchAndActivate();

  @override
  String getString(String key) => _config.getString(key);
}

/// Native source shared by startup and Home, with explicit initialization/fetch.
/// The original SDK sequence/settings/key are preserved. Sharing pending work,
/// typed failures and an immutable last-success cache are reconstruction
/// adaptations; original concurrency behavior was not recovered.
class GeneralAnnouncementsSource {
  GeneralAnnouncementsSource({
    GeneralAnnouncementsSdk? sdk,
    this.config = const GeneralAnnouncementsFirebaseConfig.fromEnvironment(),
    GeneralAnnouncementsPlatform? platform,
  }) : _sdk = sdk ?? FlutterFireGeneralAnnouncementsSdk(),
       platform = platform ?? _runtimePlatform;

  final GeneralAnnouncementsSdk _sdk;
  final GeneralAnnouncementsFirebaseConfig config;
  final GeneralAnnouncementsPlatform platform;

  static GeneralAnnouncementsPlatform get _runtimePlatform => kIsWeb
      ? GeneralAnnouncementsPlatform.web
      : defaultTargetPlatform == TargetPlatform.android
      ? GeneralAnnouncementsPlatform.android
      : GeneralAnnouncementsPlatform.unsupported;

  bool _initialized = false;
  Future<void>? _initializing;
  Future<List<GeneralAnnouncement>>? _fetching;
  List<GeneralAnnouncement>? _cached;

  /// Null until the first successful fetch AND full parse, including empty [].
  List<GeneralAnnouncement>? get cached => _cached;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
    // Check before config validation and before any SDK call, even for fakes.
    if (platform != GeneralAnnouncementsPlatform.android) {
      throw const GeneralAnnouncementsException(
        GeneralAnnouncementsFailure.unsupportedPlatform,
      );
    }
    config.validate();
    try {
      await _sdk.initialize(config);
      await _sdk.setConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      );
      _initialized = true;
    } catch (_) {
      throw const GeneralAnnouncementsException(
        GeneralAnnouncementsFailure.initialization,
      );
    }
  }

  Future<List<GeneralAnnouncement>> fetch() =>
      _fetching ??= _fetch().whenComplete(() {
        _fetching = null;
      });

  Future<List<GeneralAnnouncement>> _fetch() async {
    await initialize();
    final String value;
    try {
      // false means already activated, not failure: still read the SDK value.
      await _sdk.fetchAndActivate();
      value = _sdk.getString('global_pengumuman');
    } catch (_) {
      throw const GeneralAnnouncementsException(
        GeneralAnnouncementsFailure.fetch,
      );
    }
    final List<GeneralAnnouncement> parsed;
    try {
      parsed = GeneralAnnouncement.parseList(value);
    } catch (_) {
      throw const GeneralAnnouncementsException(
        GeneralAnnouncementsFailure.parsing,
      );
    }
    _cached = parsed;
    return parsed;
  }
}
