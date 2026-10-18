import 'dart:convert';

/// The five fields recovered from Announcement.fromJson (ci17467).
/// Missing/null dates stay null. Non-null dates use DateTime.parse, including
/// its timezone and overflow semantics; display/gating belong to the caller.
class GeneralAnnouncement {
  const GeneralAnnouncement({
    this.id,
    this.startDate,
    this.endDate,
    this.title,
    this.content,
  });

  final String? id;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? title;
  final String? content;

  factory GeneralAnnouncement.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) {
      final value = json[key];
      return value == null ? null : DateTime.parse(value as String);
    }

    return GeneralAnnouncement(
      id: json['id'] as String?,
      startDate: date('start_date'),
      endDate: date('end_date'),
      title: json['title'] as String?,
      content: json['content'] as String?,
    );
  }

  /// Preserves every row and its order. No date/role filtering or fallback data.
  static List<GeneralAnnouncement> parseList(String value) {
    final rows = jsonDecode(value) as List<dynamic>;
    return List<GeneralAnnouncement>.unmodifiable(
      rows.map(
        (row) => GeneralAnnouncement.fromJson(row as Map<String, dynamic>),
      ),
    );
  }
}
