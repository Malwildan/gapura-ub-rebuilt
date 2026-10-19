import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

import 'account_bridge.dart';
import 'services.dart';
import 'ui/home.dart';
import 'service/general_announcements.dart';

class GapuraApp extends StatefulWidget {
  const GapuraApp({
    super.key,
    this.service,
    this.account,
    this.announcements,
    this.syntheticGuestPreview = false,
    this.previewRevision = 0,
    this.previewControls,
    this.initialThemeMode = ThemeMode.system,
    this.onThemeChanged,
  });
  final GapuraService? service;
  final AccountBridge? account;
  final GeneralAnnouncementsSource? announcements;
  final bool syntheticGuestPreview;
  final int previewRevision;
  final Widget? previewControls;
  final ThemeMode initialThemeMode;
  final Future<void> Function(ThemeMode)? onThemeChanged;
  @override
  State<GapuraApp> createState() => _GapuraAppState();
}

class _GapuraAppState extends State<GapuraApp> {
  late ThemeMode mode = widget.initialThemeMode;

  // These scheme selections, Material3 and light overrides are recovered from
  // the original main.dart AOT calls. The package version is compatibility-pinned.
  ThemeData theme(Brightness brightness) => brightness == Brightness.light
      ? FlexThemeData.light(
          scheme: FlexScheme.bahamaBlue,
          useMaterial3: true,
        ).copyWith(
          cardColor: const Color(0xffececec),
          appBarTheme: const AppBarTheme(
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        )
      : FlexThemeData.dark(scheme: FlexScheme.deepBlue, useMaterial3: true);

  Future<void> selectTheme(ThemeMode selected) async {
    if (selected == mode) return;
    setState(() => mode = selected);
    try {
      await widget.onThemeChanged?.call(selected);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          context: ErrorDescription('saving the selected theme'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Gapura UB',
    debugShowCheckedModeBanner: false,
    theme: theme(Brightness.light),
    darkTheme: theme(Brightness.dark),
    themeMode: mode,
    home: GapuraHome(
      key: ValueKey('guest-preview-${widget.previewRevision}'),
      service: widget.service,
      account: widget.account,
      announcements: widget.announcements,
      syntheticGuestPreview: widget.syntheticGuestPreview,
      previewControls: widget.previewControls,
      themeMode: mode,
      onTheme: selectTheme,
    ),
  );
}
