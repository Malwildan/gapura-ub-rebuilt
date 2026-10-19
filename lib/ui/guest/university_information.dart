import 'package:flutter/material.dart';

import '../../model/university_information.dart';

/// Null means this page belongs to another guest view.
String? universityInformationTitle(String page) => switch (page) {
  'overview' => universityOverviewTitle,
  'faculty' => universityFacultyTitle,
  'officials' => universityOfficialsTitle,
  'facility' => universityFacilityTitle,
  'university_history' => universityHistoryTitle,
  'lambang' => universityEmblemTitle,
  _ => null,
};

/// Content for the existing guest ListView; no Scaffold or nested scrolling.
///
/// Composition and content follow the recovered builders. Exact original
/// dimensions and inherited typography were not recovered; spacing uses Material
/// defaults. [onTitleChanged] lets a host reflect the original openFeed status.
class UniversityInformationView extends StatefulWidget {
  const UniversityInformationView({
    super.key,
    required this.page,
    this.onTitleChanged,
    this.localPreview = false,
  });

  final String page;
  final ValueChanged<String>? onTitleChanged;
  final bool localPreview;

  @override
  State<UniversityInformationView> createState() =>
      _UniversityInformationViewState();
}

class _UniversityInformationViewState extends State<UniversityInformationView> {
  bool _feedError = false;

  @override
  void didUpdateWidget(UniversityInformationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) _feedError = false;
  }

  void _openFeed() {
    // Both recovered openFeed implementations unconditionally update the title.
    // The bundled website field is never used as a navigation target.
    setState(() => _feedError = true);
    widget.onTitleChanged?.call(universityFeedError);
  }

  @override
  Widget build(BuildContext context) {
    final children = switch (widget.page) {
      'overview' => <Widget>[
        for (final section in universityOverviewSections)
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(title: Text(section.title)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final paragraph in section.paragraphs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: section.bulleted
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('•  '),
                                    Flexible(child: Text(paragraph)),
                                  ],
                                )
                              : Text(paragraph),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      'university_history' => <Widget>[
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ListTile(title: Text(universityHistoryHeading)),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(universityHistoryText),
              ),
            ],
          ),
        ),
      ],
      'lambang' => <Widget>[
        Image.asset(universityLogoAsset, height: 180),
        Card(
          child: Column(
            children: [
              const ListTile(title: Text(universityEmblemHeading)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Table(
                  columnWidths: const {0: IntrinsicColumnWidth()},
                  defaultVerticalAlignment: TableCellVerticalAlignment.top,
                  children: [
                    for (final row in universityEmblemRows)
                      TableRow(
                        children: [
                          for (final cell in row.split('*'))
                            Padding(
                              padding: const EdgeInsets.only(
                                right: 8,
                                bottom: 8,
                              ),
                              child: Text(cell),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      'faculty' => <Widget>[
        for (final faculty in universityFaculties)
          Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: Color(faculty.colorArgb)),
              title: Text(faculty.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openFeed,
            ),
          ),
      ],
      'facility' => <Widget>[
        for (final facility in universityFacilities)
          Card(
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _remoteImage(
                  facility.thumbnailUrl,
                  width: 64,
                  height: 56,
                  fit: BoxFit.cover,
                  localPreview: widget.localPreview,
                ),
              ),
              title: Text(facility.title),
              subtitle: Text(facility.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openFeed,
            ),
          ),
      ],
      'officials' => <Widget>[
        _remoteImage(
          universityOfficialsHeroUrl,
          height: 220,
          localPreview: widget.localPreview,
        ),
        for (final official in universityOfficials)
          Card(
            child: InkWell(
              onTap: () => _showOfficial(
                context,
                official,
                localPreview: widget.localPreview,
              ),
              child: ListTile(
                leading: Text('${official.ordinal}'),
                title: Text(official.role.toUpperCase()),
                subtitle: Text(official.name),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
      ],
      _ => <Widget>[],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_feedError)
          const ListTile(
            title: Text(universityFeedError),
            leading: Icon(Icons.error_outline),
          ),
        ...children,
      ],
    );
  }
}

// Original schemes are intentional. On HTTPS web pages, HTTP images can be
// blocked by mixed-content policy; native platforms may block cleartext HTTP.
// This component changes neither schemes nor platform policy and has no fallback
// origin. Availability has not been verified. Flutter performs the image GET
// without custom credentials, request headers or body. The HTML strategy permits
// browser image display where cross-origin canvas loading is unavailable.
Widget _remoteImage(
  String url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  bool localPreview = false,
}) => localPreview
    ? SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: Icon(Icons.image_outlined, semanticLabel: 'Gambar demo lokal'),
        ),
      )
    : Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (context, error, stackTrace) => SizedBox(
          width: width,
          height: height,
          child: const Center(
            child: Tooltip(
              message: 'Gambar gagal dimuat.',
              child: Icon(
                Icons.broken_image_outlined,
                semanticLabel: 'Gambar gagal dimuat.',
              ),
            ),
          ),
        ),
      );

Future<void> _showOfficial(
  BuildContext context,
  UniversityOfficial official, {
  bool localPreview = false,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(official.name),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _remoteImage(
              official.portraitUrl,
              height: 180,
              localPreview: localPreview,
            ),
          ),
          _informationRow(Icons.work_outline, official.role),
          _informationRow(Icons.phone_outlined, official.phone),
          _informationRow(Icons.business_outlined, 'Rektorat UB'),
          _informationRow(Icons.location_on_outlined, official.address),
          _informationRow(Icons.school_outlined, official.education),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Kembali'),
      ),
    ],
  ),
);

Widget _informationRow(IconData icon, String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon),
      const SizedBox(width: 8),
      Flexible(child: Text(text)),
    ],
  ),
);
