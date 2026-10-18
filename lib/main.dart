import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'service/theme_preferences.dart';
import 'service/general_announcements.dart';
export 'app.dart';
export 'model/records.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  final announcements = GeneralAnnouncementsSource();
  try {
    // Original main initializes Firebase before restoring theme. Unsupported
    // platforms/configuration stay unavailable; no replacement data is used.
    await announcements.initialize();
  } on GeneralAnnouncementsException {
    // Compatibility adaptation: keep the rest of the app runnable if the
    // recovered registration cannot initialize on this rebuilt installation.
  }
  final preferences = ThemePreferences();
  var themeCode = 'system';
  try {
    themeCode = await preferences.read();
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        context: ErrorDescription('loading the saved theme'),
      ),
    );
  }
  runApp(
    GapuraApp(
      announcements: announcements,
      initialThemeMode: switch (themeCode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      onThemeChanged: (mode) => preferences.write(mode.name),
    ),
  );
}
