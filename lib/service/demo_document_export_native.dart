import 'package:flutter/services.dart';

/// Android's document picker saves only after the user chooses a destination.
Future<void> saveDemoDocument(Uint8List bytes, String filename) async {
  try {
    final saved = await const MethodChannel(
      'gapura_ub/demo_documents',
    ).invokeMethod<bool>('savePdf', {'bytes': bytes, 'filename': filename});
    if (saved != true) throw StateError('Penyimpanan dokumen dibatalkan.');
  } on MissingPluginException {
    throw UnsupportedError('Penyimpanan PDF tersedia di browser dan Android.');
  }
}
