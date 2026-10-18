import 'package:flutter/material.dart';

import '../../model/records.dart';

/// Student branch of the recovered profile content (ci22123/ci23627).
///
/// The host supplies PageHeader('Profil Saya'), its 2px gap, scrolling,
/// refresh/loading, and student-role gating. [user] is the original user map:
/// header identity comes from `nim` and `email`, never from profile fallbacks.
/// No account lookup, profile request, or identity-card action occurs here.
class StudentProfileView extends StatelessWidget {
  const StudentProfileView({
    super.key,
    required this.profile,
    this.user,
    this.portraitProvider = NetworkImage.new,
  });

  final Record profile;
  final Record? user;

  /// Compatibility seam: the APK used CachedNetworkImageProvider. The current
  /// dependency set uses NetworkImage; a host may supply its caching provider.
  /// Called only for a nonblank FILE_FOTO, with its original unprefixed value.
  final ImageProvider Function(String) portraitProvider;

  static String _text(dynamic value) => value == null ? '' : value.toString();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = EdgeInsets.fromLTRB(
      size.height / 50,
      size.height / 50,
      size.height / 50,
      0,
    );
    final photo = _text(profile['FILE_FOTO']);
    final rows = <(String, String)>[
      ('Nama', _text(profile['NAMA'])),
      ('Angkatan:', _text(profile['ANGKATAN'])),
      ('Status Akademik', _text(profile['STATUS'])),
      ('Fakultas', _text(profile['FAKULTAS'])),
      ('Jurusan', _text(profile['JURUSAN'])),
      (
        'Jenjang dan Program Studi',
        '${_text(profile['JENJANG'])} - ${_text(profile['PROGRAM'])}',
      ),
    ];
    // ColorThemes.primaryColorWhite: Theme.textTheme.bodyLarge.color, with
    // #B3FFFFFF only when the original nullable color is absent (ci5424).
    final valueColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white70;
    return Column(
      children: [
        Container(
          color: const Color(0xff004f86),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size.width,
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MAHASISWA UB',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      _text(user?['nim']),
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      _text(user?['email']),
                      textAlign: TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xffffaa32),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              Positioned(
                top: -60,
                // Responsive adaptation: anchor to the constrained parent.
                // At 390px this preserves the recovered left offset of 260px.
                right: 30,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                          colors: [Colors.white, Colors.white],
                          stops: [0.19, 0.81],
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // Missing-photo adaptation: no invented portrait or
                          // empty URL request. Original failure pixels unknown.
                          image: photo.trim().isEmpty
                              ? null
                              : DecorationImage(
                                  image: portraitProvider(photo),
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final row in rows) ...[
          Container(
            width: size.width,
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.$1,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: Color(0xff636363),
                    fontSize: 12,
                  ),
                ),
                Text(
                  row.$2,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
        ],
      ],
    );
  }
}
