import 'package:flutter/material.dart';

import '../app.dart';
import 'guest_demo_adapters.dart';
import 'guest_demo_session.dart';

/// Standalone public preview controls; changing state resets navigation and caches.
class GapuraGuestDemoApp extends StatefulWidget {
  const GapuraGuestDemoApp({super.key});

  @override
  State<GapuraGuestDemoApp> createState() => _GapuraGuestDemoAppState();
}

class _GapuraGuestDemoAppState extends State<GapuraGuestDemoApp> {
  GuestDemoScenario scenario = GuestDemoScenario.populated;
  late GuestDemoSession session;
  late GuestDemoService service;
  var revision = 0;
  ThemeMode theme = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  void _createSession() {
    session = GuestDemoSession(scenario);
    service = GuestDemoService(session);
  }

  void _select(GuestDemoScenario next) {
    if (next == scenario) return;
    service.close();
    setState(() {
      scenario = next;
      _createSession();
      revision++;
    });
  }

  @override
  void dispose() {
    service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GapuraApp(
    service: service,
    announcements: GuestDemoAnnouncements(session),
    syntheticGuestPreview: true,
    previewRevision: revision,
    initialThemeMode: theme,
    onThemeChanged: (next) async => theme = next,
    previewControls: Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Demo lokal · data sintetis',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          DropdownButtonFormField<GuestDemoScenario>(
            key: ValueKey('guest-preview-${scenario.name}'),
            initialValue: scenario,
            decoration: const InputDecoration(
              labelText: 'Data pratinjau',
              isDense: true,
              filled: true,
            ),
            items: [
              for (final state in GuestDemoScenario.values)
                DropdownMenuItem(value: state, child: Text(state.label)),
            ],
            onChanged: (next) {
              if (next != null) _select(next);
            },
          ),
        ],
      ),
    ),
  );
}
