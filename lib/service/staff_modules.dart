import '../model/records.dart';

/// Presentation records are normalized by the source; resource names are local
/// reader identifiers, never interpolated into service URLs.
typedef StaffRead =
    Future<List<Record>> Function(
      String resource, {
      int? year,
      int? month,
      String? category,
      Record? item,
    });

typedef StaffOpenDocument =
    Future<void> Function(Record document, {required bool download});
