/// Recovered SQLite row shape. The original kategori values are unknown.
class ModelKeyValuePair {
  const ModelKeyValuePair({required this.key, this.value, this.kategori});

  final String key;
  final String? value;
  final String? kategori;

  factory ModelKeyValuePair.fromMap(Map<String, Object?> row) =>
      ModelKeyValuePair(
        key: row['key'] as String,
        value: row['value'] as String?,
        kategori: row['kategori'] as String?,
      );

  Map<String, Object?> toMap() => {
    'key': key,
    'value': value,
    'kategori': kategori,
  };
}
