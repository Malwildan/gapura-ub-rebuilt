part of '../home.dart';

extension _AcademicViews on _GapuraHomeState {
  List<Widget> studentView() {
    if (!connected) return [loginCard()];
    if (page == 'attendance') {
      return [
        StudentAttendance(
          key: attendanceKey,
          request: (action, parameters) =>
              account.request(action, parameters: parameters),
        ),
      ];
    }
    if (page == 'library') {
      return [UniversityLibraryView(key: libraryKey)];
    }
    if (page == 'schedule') return scheduleView();
    final rows = cache[page] ?? [];
    return [
      if (['krs', 'grades', 'transcript'].contains(page)) ...[
        AcademicPeriodPicker(
          key: ValueKey('academic-period-$page'),
          period: periods[page] ?? const AcademicTerm(),
          currentYear: regularCourses.isEmpty
              ? null
              : regularCourses.first['TAHUN']?.toString(),
          currentOdd: regularCourses.isEmpty
              ? null
              : switch (regularCourses.first['IS_GANJIL']?.toString()) {
                  '1' => true,
                  '0' => false,
                  _ => null,
                },
          allTermsByDefault: page == 'transcript',
          enabled: !loading.contains(page),
          onChanged: (period) => selectPeriod(page, period),
        ),
        const SizedBox(height: 14),
        message(academicPeriodLabel()),
        const SizedBox(height: 18),
      ],
      if (page == 'materials') ...[
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Aktif')),
            ButtonSegment(value: false, label: Text('Tidak aktif')),
          ],
          selected: {active},
          onSelectionChanged: (v) {
            update(() => active = v.first);
            loadStudent('materials', force: true);
          },
        ),
        const SizedBox(height: 20),
      ],
      if (page == 'history') ...[
        if (regularCourses.isEmpty) message('Tidak ada Jadwal Kuliah'),
        if (regularCourses.isNotEmpty)
          DropdownButtonFormField<int>(
            key: ValueKey(
              'history-course-${selectedCourse?['K_MK']}-${selectedCourse?['KELAS']}',
            ),
            initialValue: historyCourseIndex(),
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Mata kuliah'),
            items: [
              for (var i = 0; i < regularCourses.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    '${value(regularCourses[i]['KULIAH'])} · ${value(regularCourses[i]['KELAS'])}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (i) {
              if (i == null) return;
              update(() => selectedCourse = regularCourses[i]);
              loadStudent('history', force: true);
            },
          ),
        const SizedBox(height: 18),
      ],
      if (['grades', 'transcript'].contains(page) && summaries.isNotEmpty) ...[
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final m in [
              ('IPK', 'IPK_LULUS'),
              ('IP Semester', 'IP_LULUS'),
              ('SKS Kumulatif', 'SKSK_LULUS'),
            ])
              card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value(summaries.last[m.$2]),
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(m.$1),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
      ],
      ...status(page),
      if (rows.isEmpty && !loading.contains(page) && !errors.containsKey(page))
        empty('Belum ada data ${title.toLowerCase()}.'),
      if (rows.isNotEmpty) ...[
        Text(
          '${rows.length} catatan',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final row in rows) ...[
          studentRecord(row),
          const SizedBox(height: 12),
        ],
      ],
    ];
  }

  List<Widget> scheduleView() {
    final filtered = courses
        .where(
          (r) =>
              (day == 0 || value(r['HARI_KE']) == '$day') &&
              '${r['KULIAH']} ${r['K_MK']} ${r['KELAS']}'
                  .toLowerCase()
                  .contains(search.toLowerCase()),
        )
        .toList();
    return [
      Wrap(
        spacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Jenis semester:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(
            width: 146,
            child: DropdownButtonFormField<bool>(
              key: ValueKey('schedule-semester-$scheduleShort'),
              initialValue: scheduleShort,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: false, child: Text('Reguler')),
                DropdownMenuItem(value: true, child: Text('Pendek')),
              ],
              onChanged: (v) {
                if (v != null) selectSchedule(v);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text(term(), style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 16),
      TextField(
        key: const ValueKey('schedule-search'),
        decoration: const InputDecoration(
          hintText: 'Cari mata kuliah',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => update(() => search = v),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 7,
        runSpacing: 5,
        children: [
          for (var i = 0; i < 7; i++)
            ChoiceChip(
              label: Text(
                ['Semua', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'][i],
              ),
              selected: day == i,
              onSelected: (_) => update(() => day = i),
            ),
        ],
      ),
      const SizedBox(height: 20),
      ...status('schedule'),
      if (filtered.isEmpty &&
          !loading.contains('schedule') &&
          !errors.containsKey('schedule'))
        empty(
          search.isEmpty
              ? 'Tidak ada Jadwal Kuliah'
              : 'Mata kuliah tidak ditemukan.',
        ),
      for (final row in filtered) ...[
        courseCard(row),
        const SizedBox(height: 14),
      ],
    ];
  }

  Widget courseCard(Record row) {
    const days = [
      '',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final d = int.tryParse(value(row['HARI_KE'])) ?? 0;
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 47,
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: Color(0xff86caff),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value(row['KULIAH'], value(row['K_MK'])),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${value(row['K_MK'])} · Kelas ${value(row['KELAS'])} · ${value(row['JML_SKS'])} SKS',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${d >= 0 && d < days.length ? days[d] : 'Hari $d'} · ${value(row['JAM_MULAI'])} – ${value(row['JAM_SELESAI'])}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 7),
          Text(
            '${value(row['GEDUNG'], '')} ${value(row['RUANG'], '')}'.trim(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (!scheduleShort)
            TextButton.icon(
              onPressed: () {
                update(() => selectedCourse = row);
                cache.remove('history');
                loadStudent('history', force: true);
                go('history');
              },
              icon: const Icon(Icons.history, size: 17),
              label: const Text('Riwayat Pertemuan'),
            ),
        ],
      ),
    );
  }

  Widget studentRecord(Record row) {
    String name = '', body = '', meta = '', amount = '';
    switch (page) {
      case 'krs':
        name = value(row['NAMA_MK'], value(row['K_MK']));
        meta = '${value(row['K_MK'])} · Kelas ${value(row['KELAS'])}';
        amount = '${value(row['JML_SKS'])} SKS';
      case 'grades':
      case 'transcript':
        name = value(row['NAMA'] ?? row['NAME'], value(row['K_MK']));
        meta =
            '${value(row['K_MK'])} · ${value(row['JML_SKS'])} SKS · ${value(row['TAHUN'])}';
        amount = publishedGrade(row);
        body = value(row['IS_PUBLISH_NILAI']) == '1'
            ? 'Bobot nilai: ${value(row['NILAI_ANGKA'])}'
            : 'Nilai belum diterbitkan oleh UB.';
      case 'finance':
        name = value(row['JENIS_BAYAR'], value(row['JENIS_TRANSAKSI']));
        meta = '${value(row['SEMESTER'])} · ${value(row['TGL_BAYAR'])}';
        body =
            'Tagihan: ${value(row['JML_TAGIH'])}\nSetoran: ${value(row['JML_SETOR'])}\nMata uang: ${value(row['MATA_UANG'])}';
      case 'announcements':
        name = value(row['NAMA_MK'], 'Pengumuman');
        body = plain(row['PENGUMUMAN']);
        meta = '${value(row['TGL_AWAL'])} · Kelas ${value(row['KELAS'])}';
      case 'materials':
      case 'history':
        name = value(
          row['MATA_KULIAH'],
          value(row['K_MK'], 'Pertemuan kuliah'),
        );
        meta =
            '${value(row['TGL_ABSENSI'])} · ${value(row['JAM_MULAI'])} – ${value(row['JAM_SELESAI'])}';
        body = [row['MATERI'], row['CATATAN'], row['KETERANGAN']]
            .where((v) => v != null && v.toString().isNotEmpty)
            .map(plain)
            .join('\n');
      default:
        name = value(row['title'], 'Notifikasi');
        body = plain(row['body']);
        meta = value(row['sentdatetime'], '');
    }
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(meta, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (amount.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              amount,
              style: TextStyle(
                fontSize: amount.length > 8 ? 16 : 27,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(body, style: const TextStyle(height: 1.65)),
          ],
        ],
      ),
    );
  }
}
