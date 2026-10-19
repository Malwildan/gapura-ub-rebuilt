import 'package:flutter/material.dart';

import '../../model/records.dart';
import '../../widget/page_header.dart';

String dosenText(Record row, List<String> keys, [String fallback = '—']) {
  for (final key in keys) {
    final text = row[key]?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return fallback;
}

class DosenHeading extends StatelessWidget {
  const DosenHeading(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => PageHeader(title: title);
}

class DosenFields extends StatelessWidget {
  const DosenFields({super.key, required this.title, required this.fields});
  final String title;
  final Map<String, String> fields;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xffed8b00),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Divider(),
          for (final field in fields.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.key,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(field.value),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// Reloads on source/selection/revision changes; failed refreshes stay visible.
class DosenLoad extends StatefulWidget {
  const DosenLoad({
    super.key,
    required this.load,
    required this.builder,
    required this.identity,
    this.revision = 0,
    this.emptyText = 'Tidak ada data.',
  });
  final Future<List<Record>> Function() load;
  final Widget Function(BuildContext, List<Record>) builder;
  final Object identity;
  final int revision;
  final String emptyText;
  @override
  State<DosenLoad> createState() => _DosenLoadState();
}

class _DosenLoadState extends State<DosenLoad> {
  late Future<List<Record>> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  @override
  void didUpdateWidget(covariant DosenLoad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        oldWidget.revision != widget.revision) {
      future = widget.load();
    }
  }

  Future<void> reload() async {
    setState(() => future = widget.load());
    try {
      await future;
    } catch (_) {
      // FutureBuilder displays the failure and offers a fresh read.
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          tooltip: 'Muat ulang',
          onPressed: reload,
          icon: const Icon(Icons.refresh),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Record>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline),
                      const Text('Data gagal dimuat'),
                      TextButton(
                        onPressed: reload,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final rows = snapshot.data ?? const <Record>[];
            return RefreshIndicator(
              onRefresh: reload,
              child: rows.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        Center(child: Text(widget.emptyText)),
                      ],
                    )
                  : widget.builder(context, rows),
            );
          },
        ),
      ),
    ],
  );
}

Future<bool> dosenConfirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yakin'),
          ),
        ],
      ),
    ) ??
    false;
