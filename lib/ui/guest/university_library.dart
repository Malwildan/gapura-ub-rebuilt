import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../model/university_library.dart';

typedef LibraryLaunch =
    Future<bool> Function(
      Uri uri, {
      required LaunchMode mode,
      required String webOnlyWindowName,
    });

/// Allows only the nine exact bundled targets; never attaches Gapura credentials.
class LibraryExternalLauncher {
  const LibraryExternalLauncher({
    this.canLaunch = canLaunchUrl,
    this.launch = _launch,
  });

  final Future<bool> Function(Uri) canLaunch;
  final LibraryLaunch launch;

  static Future<bool> _launch(
    Uri uri, {
    required LaunchMode mode,
    required String webOnlyWindowName,
  }) => launchUrl(uri, mode: mode, webOnlyWindowName: webOnlyWindowName);

  Future<bool> open(Uri uri) async {
    if (!universityLibraryLinks.any((link) => link.url == uri.toString())) {
      return false;
    }
    try {
      if (!await canLaunch(uri)) return false;
      return await launch(
        uri,
        mode: LaunchMode.externalApplication,
        // Web compatibility adaptation; the recovered application was Android.
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      // Platform failures remain failures, without adding visible feedback or
      // binding the original hidden loading/error state to the fixed heading.
      return false;
    }
  }
}

/// Library content hosted by Home's existing scroll and RefreshIndicator.
class UniversityLibraryView extends StatefulWidget {
  const UniversityLibraryView({
    super.key,
    this.launcher = const LibraryExternalLauncher(),
  });

  final LibraryExternalLauncher launcher;

  @override
  UniversityLibraryViewState createState() => UniversityLibraryViewState();
}

class UniversityLibraryViewState extends State<UniversityLibraryView> {
  final _links = [...universityLibraryBaseLinks];

  @override
  void initState() {
    super.initState();
    _links.add(universityLibraryAndroidLink);
  }

  Future<void> reload() async {
    if (!mounted) return;
    // Intentional 1:1 quirk: each load appends, including repeated refreshes.
    setState(() => _links.add(universityLibraryAndroidLink));
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    shrinkWrap: true,
    primary: false,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(4),
    itemCount: _links.length,
    itemBuilder: (context, index) {
      final link = _links[index];
      final radius = BorderRadius.circular(13);
      return Card(
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          borderRadius: radius,
          onTap: () async {
            await widget.launcher.open(link.uri);
          },
          child: ListTile(
            // Marker dimensions and icon are compatibility choices; only the
            // structure, colors, radii and list padding are recovered here.
            leading: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Color(link.colorArgb),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            title: Text(link.title),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      );
    },
  );
}
