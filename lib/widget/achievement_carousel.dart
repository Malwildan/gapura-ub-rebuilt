import 'dart:async';

import 'package:flutter/material.dart';

import '../model/records.dart';
import '../services.dart';

/// Data-driven achievement banner. PageView is a reconstruction of the
/// recovered full-width 16:9 carousel with five-second autoplay.
class AchievementCarousel extends StatefulWidget {
  const AchievementCarousel({
    super.key,
    required this.service,
    required this.onOpen,
    this.localPreview = false,
    this.imageProvider,
  });
  final GapuraService service;
  final ValueChanged<String> onOpen;
  final bool localPreview;
  final ImageProvider<Object> Function(String)? imageProvider;

  @override
  State<AchievementCarousel> createState() => _AchievementCarouselState();
}

class _AchievementCarouselState extends State<AchievementCarousel> {
  static const initialPage = 10000;
  late Future<List<Record>> result = load();
  final controller = PageController(initialPage: initialPage);
  Timer? timer;
  int count = 0;
  int selected = 0;

  Future<List<Record>> load() async {
    timer?.cancel();
    final rows = await widget.service.achievements();
    if (mounted) {
      count = rows.length;
      selected = count == 0 || !controller.hasClients
          ? 0
          : ((controller.page ?? initialPage).round() - initialPage) % count;
      resume();
    }
    return rows;
  }

  void resume() {
    timer?.cancel();
    if (count < 2) return;
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted ||
          !controller.hasClients ||
          controller.position.isScrollingNotifier.value ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      move((controller.page ?? initialPage).round() + 1);
    });
  }

  void move(int page) => controller.animateToPage(
    page,
    duration: const Duration(milliseconds: 800),
    curve: const Cubic(0.4, 0, 0.2, 1),
  );

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Record>>(
    future: result,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: TextButton.icon(
            onPressed: () => setState(() {
              result = load();
            }),
            icon: const Icon(Icons.refresh),
            label: const Text('Muat ulang informasi penghargaan'),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 64,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final rows = snapshot.data!;
      if (rows.isEmpty) return const SizedBox.shrink();
      return Listener(
        onPointerDown: (_) => timer?.cancel(),
        onPointerUp: (_) => resume(),
        onPointerCancel: (_) => resume(),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: PageView.builder(
                controller: controller,
                onPageChanged: (index) => setState(
                  () => selected = (index - initialPage) % rows.length,
                ),
                itemBuilder: (context, page) {
                  final index = (page - initialPage) % rows.length;
                  final row = rows[index];
                  final image = Uri.tryParse(value(row['URL_FILE'], ''));
                  final validImage =
                      image != null &&
                      image.scheme == 'https' &&
                      image.userInfo.isEmpty &&
                      !image.hasPort &&
                      (image.host == 'ub.ac.id' ||
                          image.host.endsWith('.ub.ac.id'));
                  final link = Uri.tryParse(value(row['LINK'], ''));
                  return Semantics(
                    label: value(
                      row['JENIS_GAMBAR'],
                      'Penghargaan Universitas Brawijaya',
                    ),
                    child: GestureDetector(
                      onTap:
                          link != null &&
                              link.scheme == 'https' &&
                              link.host.isNotEmpty &&
                              link.userInfo.isEmpty
                          ? () => widget.onOpen(link.toString())
                          : null,
                      child: ColoredBox(
                        color: Colors.white,
                        child: widget.localPreview
                            ? const Center(
                                child: Icon(
                                  Icons.emoji_events_outlined,
                                  size: 56,
                                  color: Color(0xffed8b00),
                                ),
                              )
                            : widget.imageProvider != null
                            ? Image(
                                image: widget.imageProvider!(
                                  value(row['URL_FILE'], ''),
                                ),
                                fit: BoxFit.cover,
                              )
                            : validImage
                            ? Image.network(
                                image.toString(),
                                fit: BoxFit.cover,
                                // UB's image host does not return CORS headers.
                                // Flutter's HTML image strategy preserves the
                                // original URL; native rendering is unaffected.
                                webHtmlElementStrategy:
                                    WebHtmlElementStrategy.prefer,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Text('Gambar belum dapat dimuat.'),
                                ),
                              )
                            : const Center(
                                child: Text('Gambar belum dapat dimuat.'),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < rows.length; index++)
                  Semantics(
                    button: true,
                    selected: selected == index,
                    label: 'Penghargaan ${index + 1} dari ${rows.length}',
                    child: GestureDetector(
                      onTap: () => move(
                        (controller.page ?? initialPage).round() +
                            index -
                            selected,
                      ),
                      child: Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected == index
                              ? const Color(0xff004f86)
                              : const Color(0xffed8b00),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
