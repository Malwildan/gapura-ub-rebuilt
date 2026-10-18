import 'dart:js_interop';

@JS('globalThis.localStorage')
external _ThemeStorage get _storage;

extension type _ThemeStorage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
}

/// Browser adaptation of the mobile themeCode preference; no session access.
class ThemePreferences {
  static const _key = 'themeCode';
  static const _codes = {'light', 'dark', 'system'};

  Future<String> read() async {
    try {
      final value = _storage.getItem(_key.toJS)?.toDart;
      if (value == null) {
        _storage.setItem(_key.toJS, 'system'.toJS);
        return 'system';
      }
      return _codes.contains(value) ? value : 'system';
    } catch (_) {
      throw StateError('Preferensi tema tidak dapat dibaca dari penyimpanan.');
    }
  }

  Future<void> write(String code) async {
    if (!_codes.contains(code)) {
      throw const FormatException(
        'Pilihan tema harus light, dark, atau system.',
      );
    }
    try {
      _storage.setItem(_key.toJS, code.toJS);
    } catch (_) {
      throw StateError('Preferensi tema tidak dapat disimpan.');
    }
  }
}
