part of '../home.dart';

extension _UniversityViews on _GapuraHomeState {
  List<Widget> publicView({NewsFeed? feed}) {
    if (universityInformationTitle(page) != null) {
      return [
        UniversityInformationView(
          key: ValueKey('public-information-$page'),
          page: page,
          onTitleChanged: (title) => update(() => publicTitle = title),
        ),
      ];
    }
    if (!['news', 'calendar', 'statistics', 'images'].contains(page)) {
      return [empty('Konten layanan ini belum tersedia di aplikasi ini.')];
    }
    final newsFeed = feed ?? selectedNewsFeed;
    final key = publicCacheKey(page, feed: newsFeed);
    final query = page == 'news' ? newsSearch[newsFeed]!.text : search;
    var rows = cache[key] ?? [];
    final terms = rows
        .map((r) => value(r['THN_AKAD'], ''))
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (page == 'calendar' && calendarTerm != 'Semua') {
      rows = rows.where((r) => value(r['THN_AKAD']) == calendarTerm).toList();
    }
    if (query.isNotEmpty) {
      rows = rows
          .where(
            (r) =>
                r.values.join(' ').toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    }
    return [
      if (page == 'news') ...[
        TextField(
          controller: newsSearch[newsFeed],
          decoration: const InputDecoration(
            hintText: 'Cari berita',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => update(() {}),
        ),
        const SizedBox(height: 18),
      ],
      if (page == 'calendar' && terms.isNotEmpty) ...[
        DropdownButtonFormField<String>(
          initialValue: 'Semua',
          decoration: const InputDecoration(labelText: 'Tahun Akademik'),
          items: [
            for (final t in ['Semua', ...terms])
              DropdownMenuItem(value: t, child: Text(t)),
          ],
          onChanged: (v) => update(() => calendarTerm = v ?? 'Semua'),
        ),
        const SizedBox(height: 18),
      ],
      ...status(
        key,
        onRetry: () => loadPublic(page, force: true, feed: newsFeed),
      ),
      if (rows.isEmpty && !loading.contains(key) && !errors.containsKey(key))
        empty('Tidak ada data untuk pilihan ini.'),
      for (final row in rows) ...[
        switch (page) {
          'news' => newsCard(row),
          'statistics' => card(
            Row(
              children: [
                const Icon(Icons.bar_chart, size: 34, color: Color(0xff63b6fc)),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value(row['ITEM']),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        value(row['_group'], ''),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    value(row['JML']),
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          'calendar' => card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${value(row['THN_AKAD'])} · ${value(row['SEMESTER'], value(row['_group'], ''))}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  value(row['NAMA_KEGIATAN']),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${value(row['TGL_MULAI'])} – ${value(row['TGL_SELESAI'])}',
                ),
                if (plain(row['KETERANGAN']).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(plain(row['KETERANGAN'])),
                ],
              ],
            ),
          ),
          _ => imageCard(row),
        },
        const SizedBox(height: 14),
      ],
    ];
  }

  Widget newsCard(Record row) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => open(value(row['link'], '')),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value(row['date'], 'Prasetya UB').split('T').first,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              plain(row['title']),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                height: 1.4,
              ),
            ),
            if (page == 'news') ...[
              const SizedBox(height: 10),
              Text(
                plain(row['description']),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    ),
  );
  Widget imageCard(Record row) {
    final uri = Uri.tryParse(value(row['URL_FILE'], ''));
    final valid =
        uri != null &&
        uri.scheme == 'https' &&
        (uri.host == 'ub.ac.id' || uri.host.endsWith('.ub.ac.id'));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (valid)
            Image.network(
              uri.toString(),
              width: double.infinity,
              height: 240,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 100,
                child: Center(child: Text('Gambar belum dapat dimuat.')),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value(
                      row['JENIS_GAMBAR'],
                      value(row['_group'], 'Universitas Brawijaya'),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (value(row['LINK'], '').startsWith('https://'))
                  IconButton(
                    onPressed: () => open(row['LINK'].toString()),
                    tooltip: 'Buka tautan',
                    icon: const Icon(Icons.open_in_new, size: 18),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
