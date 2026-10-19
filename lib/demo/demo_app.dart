import 'package:flutter/material.dart';

import '../app.dart';
import 'demo_adapters.dart';
import 'demo_session.dart';

/// An explicit preview application. Changing controls remounts the entire app
/// session, so pending readers, navigation and local writes cannot cross roles.
class GapuraDemoApp extends StatefulWidget {
  const GapuraDemoApp({
    super.key,
    this.initialRole = DemoRole.student,
    this.initialScenario = DemoScenario.populated,
    this.delay = const Duration(milliseconds: 180),
  });
  final DemoRole initialRole;
  final DemoScenario initialScenario;
  final Duration delay;
  @override
  State<GapuraDemoApp> createState() => _GapuraDemoAppState();
}

class _GapuraDemoAppState extends State<GapuraDemoApp> {
  late DemoSession session;
  late DemoService service;
  late DemoAccount account;
  ThemeMode theme = ThemeMode.system;
  var revision = 0;

  @override
  void initState() {
    super.initState();
    create(widget.initialRole, widget.initialScenario);
  }

  void create(DemoRole role, DemoScenario scenario) {
    session = DemoSession(role: role, scenario: scenario, delay: widget.delay);
    service = DemoService(session);
    account = DemoAccount(session);
  }

  void select(DemoRole role, DemoScenario scenario) {
    if (role == session.role && scenario == session.scenario) return;
    setState(() {
      service.close();
      create(role, scenario);
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
    key: ValueKey('demo-session-$revision'),
    service: service,
    account: account,
    announcements: DemoAnnouncements(session),
    demo: session,
    initialThemeMode: theme,
    onThemeChanged: (next) async => theme = next,
    demoControls: Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<DemoRole>(
                  key: ValueKey('demo-role-${session.role.name}'),
                  initialValue: session.role,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Peran',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                  dropdownColor: Colors.white,
                  items: [
                    for (final role in DemoRole.values)
                      DropdownMenuItem(value: role, child: Text(role.label)),
                  ],
                  onChanged: (role) {
                    if (role != null) select(role, session.scenario);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<DemoScenario>(
                  key: ValueKey('demo-scenario-${session.scenario.name}'),
                  initialValue: session.scenario,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Data',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                  dropdownColor: Colors.white,
                  items: [
                    for (final mode in DemoScenario.values)
                      DropdownMenuItem(value: mode, child: Text(mode.label)),
                  ],
                  onChanged: (mode) {
                    if (mode != null) select(session.role, mode);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
