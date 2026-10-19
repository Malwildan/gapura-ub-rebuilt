import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('Blob')
extension type _PdfBlob._(JSObject _) implements JSObject {
  external factory _PdfBlob(JSArray<JSUint8Array> parts, _BlobOptions options);
}
extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({JSString type});
}
@JS('URL.createObjectURL')
external JSString _createUrl(_PdfBlob blob);
@JS('URL.revokeObjectURL')
external void _revokeUrl(JSString url);
@JS('document')
external _Document get _document;
extension type _Document(JSObject _) implements JSObject {
  external _Anchor createElement(JSString tag);
}
extension type _Anchor(JSObject _) implements JSObject {
  external set href(JSString value);
  external set download(JSString value);
  external void click();
}

Future<void> saveDemoDocument(Uint8List bytes, String filename) async {
  final blob = _PdfBlob(
    [bytes.toJS].toJS,
    _BlobOptions(type: 'application/pdf'.toJS),
  );
  final url = _createUrl(blob);
  try {
    final anchor = _document.createElement('a'.toJS);
    anchor.href = url;
    anchor.download = filename.toJS;
    anchor.click();
  } finally {
    // Give the browser time to consume the object URL before releasing it.
    Timer(const Duration(seconds: 30), () => _revokeUrl(url));
  }
}
