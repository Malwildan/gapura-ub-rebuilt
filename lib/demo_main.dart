import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'demo/demo_app.dart';

/// Standalone demo: no Firebase initialization, stored session, or UB transport.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(const GapuraDemoApp());
}
