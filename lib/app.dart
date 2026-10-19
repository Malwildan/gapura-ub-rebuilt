import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

import 'account_bridge.dart';
import 'services.dart';
import 'ui/home.dart';
import 'ui/welcome.dart';
import 'service/general_announcements.dart';
import 'demo/demo_session.dart';
import 'demo/demo_adapters.dart';

class GapuraApp extends StatefulWidget {
  const GapuraApp({
    super.key,
    this.service,
    this.account,
    this.announcements,
    this.initialThemeMode = ThemeMode.system,
    this.onThemeChanged,
    this.demo,
    this.demoControls,
    this.syntheticGuestPreview = false,
    this.previewRevision = 0,
    this.previewControls,
    this.showWelcome = false,
  });
  final GapuraService? service;
  final AccountBridge? account;
  final GeneralAnnouncementsSource? announcements;
  final ThemeMode initialThemeMode;
  final Future<void> Function(ThemeMode)? onThemeChanged;
  final DemoSession? demo;
  final Widget? demoControls;
  final bool syntheticGuestPreview;
  final int previewRevision;
  final Widget? previewControls;
  final bool showWelcome;
  @override
  State<GapuraApp> createState() => _GapuraAppState();
}

class _GapuraAppState extends State<GapuraApp> {
  late ThemeMode mode = widget.initialThemeMode;
  bool entered = false;
  bool startUbLogin = false;
  bool guestEntry = false;
  DemoSession? localSession;
  DemoService? localService;
  DemoAccount? localAccount;
  DemoAnnouncements? localAnnouncements;

  void openGuest() => setState(() {
    entered = true;
    localSession = null;
    startUbLogin = false;
    guestEntry = true;
  });

  void openUbAccount() => setState(() {
    entered = true;
    localSession = null;
    startUbLogin = true;
    guestEntry = false;
  });

  void openLocalAccount(DemoRole role) {
    final session = DemoSession(
      role: role,
      scenario: DemoScenario.populated,
      localAccount: true,
    );
    setState(() {
      entered = true;
      startUbLogin = false;
      guestEntry = false;
      localSession = session;
      localService = DemoService(session);
      localAccount = DemoAccount(session);
      localAnnouncements = DemoAnnouncements(session);
    });
  }

  void returnToWelcome() => setState(() {
    entered = false;
    startUbLogin = false;
    localSession = null;
    guestEntry = false;
    localService = null;
    localAccount = null;
    localAnnouncements = null;
  });

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
    builder: (context, child) =>
        (widget.demo == null || widget.demo!.localAccount)
        ? child!
        : SafeArea(
            bottom: false,
            child: Column(
              children: [
                Material(
                  color: const Color(0xff003153),
                  child: SizedBox(
                    width: double.infinity,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      child: Text(
                        'Demo lokal · data sintetis',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: child!),
              ],
            ),
          ),
    home: !entered && widget.showWelcome
        ? WelcomeScreen(
            onGuest: openGuest,
            onUbAccount: openUbAccount,
            onLocalRole: openLocalAccount,
          )
        : GapuraHome(
            key: widget.syntheticGuestPreview
                ? ValueKey('guest-preview-${widget.previewRevision}')
                : ValueKey(localSession?.role ?? widget.demo?.role ?? 'live'),
            service: localSession == null ? widget.service : localService,
            account: localSession == null ? widget.account : localAccount,
            announcements: localSession == null
                ? widget.announcements
                : localAnnouncements,
            themeMode: mode,
            onTheme: selectTheme,
            demo: localSession ?? widget.demo,
            demoControls: widget.demoControls,
            syntheticGuestPreview: widget.syntheticGuestPreview,
            previewControls: widget.previewControls,
            onWelcome: widget.showWelcome ? returnToWelcome : null,
            autoLogin: startUbLogin,
            allowSessionRestore: !guestEntry,
          ),
  );
}
