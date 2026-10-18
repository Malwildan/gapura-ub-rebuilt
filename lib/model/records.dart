typedef Record = Map<String, dynamic>;
String value(dynamic v, [String fallback = '—']) =>
    v == null || v.toString().trim().isEmpty ? fallback : v.toString();
String plain(dynamic v) => value(v, '')
    .replaceAll(RegExp(r'<[^>]*>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
List<Record> records(Record data, String key) {
  final wrapper = data[key];
  if (wrapper is! Map || wrapper['data'] is! List) {
    throw const FormatException('Format respons UB belum dapat dibaca.');
  }
  return (wrapper['data'] as List)
      .whereType<Map>()
      .map((r) => Map<String, dynamic>.from(r))
      .toList();
}

String publishedGrade(Record row) => value(row['IS_PUBLISH_NILAI']) == '1'
    ? value(row['K_NILAI'], 'Belum tersedia')
    : 'Belum diterbitkan';
