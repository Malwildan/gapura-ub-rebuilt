import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'guest_demo/guest_demo_app.dart';

/// Local guest-only preview. It does not initialize Firebase or restore an account.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(const GapuraGuestDemoApp());
}
