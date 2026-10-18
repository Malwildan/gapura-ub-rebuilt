import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../model/general_announcement.dart';

/// Literal original predicate: start >= now AND end <= now, with fresh clocks.
/// Null-date adaptation: hide the banner instead of failing the whole Home.
int announcementVisibilityCount(
  List<GeneralAnnouncement> rows, {
  DateTime Function()? clock,
}) {
  if (rows.any((row) => row.startDate == null || row.endDate == null)) return 0;
  final now = clock ?? DateTime.now;
  var count = 0;
  for (final row in rows) {
    final start = row.startDate!, end = row.endDate!;
    if ((start.isAfter(now()) || start.isAtSameMomentAs(now())) &&
        (end.isBefore(now()) || end.isAtSameMomentAs(now()))) {
      count++;
    }
  }
  return count;
}

class GeneralAnnouncementBanner extends StatelessWidget {
  const GeneralAnnouncementBanner({
    super.key,
    required this.announcements,
    this.clock,
  });

  final List<GeneralAnnouncement>? announcements;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final rows = announcements;
    if (rows == null || announcementVisibilityCount(rows, clock: clock) == 0) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          content: SizedBox(
            // Explicit width is a web/lazy-list layout accommodation.
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: rows.length,
              itemBuilder: (context, index) => _AnnouncementRow(
                announcement: rows[index],
                clock: clock ?? DateTime.now,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Tutup',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff004f86),
                ),
              ),
            ),
          ],
        ),
      ),
      child: Container(
        margin: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width / 20,
          0,
          MediaQuery.sizeOf(context).width / 20,
          15,
        ),
        decoration: BoxDecoration(
          color: const Color(0xffffaa32),
          borderRadius: BorderRadius.circular(13),
        ),
        child: ListTile(
          leading: const Icon(Icons.warning, color: Color(0xfffff5e7)),
          title: Text(
            '${rows.length} pengumuman penting',
            style: const TextStyle(
              color: Color(0xb3ffffff),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow({required this.announcement, required this.clock});
  final GeneralAnnouncement announcement;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('d MMMM y');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xfffdeddc),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            announcement.title ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xb3ffffff),
            ),
          ),
          const Padding(padding: EdgeInsets.all(5)),
          Text(
            '${formatter.format(announcement.startDate ?? clock())} - '
            '${formatter.format(announcement.endDate ?? clock())}',
            style: const TextStyle(fontSize: 10, color: Color(0xb3ffffff)),
          ),
          const Padding(padding: EdgeInsets.all(5)),
          Text(
            announcement.content ?? '',
            style: const TextStyle(fontSize: 14, color: Color(0x8affffff)),
          ),
        ],
      ),
    );
  }
}
