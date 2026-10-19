import 'package:flutter/material.dart';

import '../../demo/dosen_data.dart';
import '../../model/records.dart';
import 'dosen_widgets.dart';

class DosenAttendanceScreen extends StatefulWidget {
  const DosenAttendanceScreen({super.key, required this.data});
  final DosenDemoData data;
  @override
  State<DosenAttendanceScreen> createState() => _DosenAttendanceScreenState();
}

class _DosenAttendanceScreenState extends State<DosenAttendanceScreen> {
  late Future<List<Record>> gate;
  bool passed = false, busy = false;
  String mode = 'Bekerja Reguler di Kantor';
  String shift = 'Jam 06:00 - 14:00';
  int revision = 0;
  int? year, month;
  final answers = <String, String>{};
  @override
  void initState() {
    super.initState();
    gate = widget.data.read('survey');
  }

  @override
  void didUpdateWidget(covariant DosenAttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      gate = widget.data.read('survey');
      passed = false;
      answers.clear();
    }
  }

  void notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> operation(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (mounted) setState(() => revision++);
    } catch (_) {
      notice('Perubahan demo gagal disimpan. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Record>>(
    future: gate,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Data gagal dimuat'),
              TextButton(
                onPressed: () =>
                    setState(() => gate = widget.data.read('survey')),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        );
      }
      final surveys = snapshot.data ?? [];
      // has_result is an explicitly synthetic fixture flag for the recovered
      // staff SurveyHasil presence branch, not the student's STAT_ISI rule.
      if (!passed &&
          surveys.isNotEmpty &&
          surveys.first['has_result'] != true) {
        return survey(surveys.first);
      }
      return DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const DosenHeading('Presensi'),
            const TabBar(
              tabs: [
                Tab(text: 'Presensi'),
                Tab(text: 'Tugas'),
                Tab(text: 'Riwayat'),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            Expanded(
              child: TabBarView(children: [attendance(), tasks(), history()]),
            ),
          ],
        ),
      );
    },
  );

  Widget survey(Record survey) => Column(
    children: [
      const DosenHeading('Survey'),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text(dosenText(survey, ['judul_survey', 'title'])),
      ),
      Expanded(
        child: DosenLoad(
          identity: widget.data,
          load: () => widget.data.read('survey_components'),
          builder: (context, rows) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows) surveyQuestion(row),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: busy
                    ? null
                    : () {
                        final required = rows.where(
                          (r) =>
                              r['is_required'] == '1' &&
                              !['info', 'html'].contains(r['tag']),
                        );
                        if (required.any(
                          (r) => (answers['${r['id']}'] ?? '').trim().isEmpty,
                        )) {
                          notice('Lengkapi jawaban yang wajib diisi.');
                          return;
                        }
                        operation(() async {
                          await widget.data.save('survey', {
                            ...survey,
                            'has_result': true,
                            'demo_answers': Map<String, String>.from(answers),
                          });
                          if (mounted) setState(() => passed = true);
                          notice('Jawaban tersimpan di demo lokal.');
                        });
                      },
                child: Text(busy ? 'Mengirim...' : 'Kirim Jawaban'),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget surveyQuestion(Record row) {
    final id = '${row['id']}';
    final tag = '${row['tag'] ?? 'input'}';
    final prompt = dosenText(row, ['komponen_survey', 'title']);
    final label = '$prompt${row['is_required'] == '1' ? ' *' : ''}';
    if (tag == 'info' || tag == 'html') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(plain(prompt)),
      );
    }
    if (tag == 'radio' || tag == 'select') {
      final options = row['options'] is List
          ? (row['options'] as List).whereType<Map>().toList()
          : [
              {
                'label': dosenText(row, ['label'], 'Pilihan demo'),
                'value': dosenText(row, ['value'], 'demo'),
              },
            ];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label),
            if (tag == 'select')
              DropdownButtonFormField<String>(
                initialValue: answers[id],
                isExpanded: true,
                items: [
                  for (final option in options)
                    DropdownMenuItem(
                      value: '${option['value']}',
                      child: Text('${option['label']}'),
                    ),
                ],
                onChanged: (value) => setState(() => answers[id] = value ?? ''),
              )
            else
              RadioGroup<String>(
                groupValue: answers[id],
                onChanged: (value) {
                  if (!busy) setState(() => answers[id] = value ?? '');
                },
                child: Column(
                  children: [
                    for (final option in options)
                      RadioListTile<String>(
                        title: Text('${option['label']}'),
                        value: '${option['value']}',
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        key: ValueKey(id),
        initialValue: answers[id],
        decoration: InputDecoration(
          labelText: label,
          hintText: tag == 'number'
              ? 'Masukkan angka di sini'
              : 'Ketikkan penjelasan di sini',
        ),
        keyboardType: tag == 'number'
            ? TextInputType.number
            : TextInputType.multiline,
        maxLines: tag == 'textarea' ? 4 : 1,
        onChanged: (value) => answers[id] = value,
      ),
    );
  }

  Widget attendance() => DosenLoad(
    identity: widget.data,
    revision: revision,
    load: () => widget.data.read('attendance'),
    builder: (context, rows) {
      final row = rows.first;
      final started = row['demo_started'] == true;
      final ended = row['demo_ended'] == true;
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          DosenFields(
            title: 'Info Presensi',
            fields: {
              'Pegawai': 'Demo Dosen',
              'Status': ended
                  ? 'Selesai bekerja'
                  : started
                  ? 'Sedang bekerja'
                  : 'Belum Melakukan Presensi',
              'Waktu Presensi': dosenText(row, ['WAKTU'], '08:00'),
              'Lokasi': 'Lokasi demo lokal',
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Mode Kerja'),
                  items: [
                    for (final value in [
                      'Bekerja Reguler di Kantor',
                      'Bekerja dari Rumah',
                      'Bekerja dari Mana Saja',
                      'Bekerja Shif',
                      'Dinas Luar',
                    ])
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value != null) setState(() => mode = value);
                        },
                ),
                if (mode == 'Bekerja Shif')
                  DropdownButtonFormField<String>(
                    initialValue: shift,
                    isExpanded: true,
                    items: [
                      for (final value in [
                        'Jam 06:00 - 14:00',
                        'Jam 14:00 - 22:00',
                      ])
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => shift = value);
                    },
                  ),
                if (mode == 'Dinas Luar') ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Jadwal presensi sesuai surat tugas'),
                  ),
                  OutlinedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const _DinasEditor(),
                    ),
                    child: const Text('Unggah Bukti Dukung'),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (!await dosenConfirm(
                            context,
                            ended
                                ? 'Perbarui jam selesai kerja di demo lokal?'
                                : started
                                ? 'Akhiri pekerjaan di demo lokal?'
                                : 'Mulai pekerjaan di demo lokal?',
                          )) {
                            return;
                          }
                          operation(() async {
                            await widget.data.save('attendance', {
                              ...row,
                              'demo_started': true,
                              'demo_ended': started,
                              'mode': mode,
                              'shift': shift,
                            });
                            notice('Presensi tersimpan di demo lokal.');
                          });
                        },
                  child: Text(
                    ended
                        ? 'Perbarui Jam Selesai Kerja'
                        : started
                        ? (mode == 'Bekerja Shif'
                              ? 'Akhiri Shift Sekarang'
                              : 'Akhiri Kerja Sekarang')
                        : (mode == 'Bekerja Shif'
                              ? 'Mulai Shift Sekarang'
                              : 'Mulai Kerja Sekarang'),
                  ),
                ),
                if (started)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => operation(() async {
                            await widget.data.save('attendance', {
                              ...row,
                              'mode': mode,
                              'shift': shift,
                            });
                            notice('Mode kerja diperbarui di demo lokal.');
                          }),
                    child: const Text('Ubah Mode Kerja'),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget tasks() => Column(
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Tambah Tugas'),
          onPressed: busy
              ? null
              : () async {
                  final text = await showDialog<String>(
                    context: context,
                    builder: (_) => const _TaskEditor(),
                  );
                  if (text == null || !mounted) return;
                  operation(() async {
                    await widget.data.save('tasks', {
                      'title': text,
                      'TUGAS': text,
                      'TANGGAL': '2026-10-19',
                    });
                  });
                },
        ),
      ),
      Expanded(
        child: DosenLoad(
          identity: widget.data,
          revision: revision,
          load: () => widget.data.read('tasks'),
          builder: (context, rows) => ListView(
            children: [
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text(dosenText(row, ['TUGAS', 'title'])),
                    subtitle: Text(dosenText(row, ['TANGGAL'])),
                    trailing: IconButton(
                      tooltip: 'Hapus tugas',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: busy
                          ? null
                          : () async {
                              if (!await dosenConfirm(
                                context,
                                'Hapus tugas harian ini?',
                              )) {
                                return;
                              }
                              operation(
                                () =>
                                    widget.data.remove('tasks', '${row['id']}'),
                              );
                            },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget history() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: year,
                decoration: const InputDecoration(labelText: 'Pilih Tahun'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Semua')),
                  for (final y in [2026, 2025, 2024])
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (value) => setState(() => year = value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: month,
                decoration: const InputDecoration(labelText: 'Pilih Bulan'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Semua')),
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(value: m, child: Text('$m')),
                ],
                onChanged: (value) => setState(() => month = value),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: DosenLoad(
          identity: Object.hash(widget.data, year, month),
          revision: revision,
          load: () =>
              widget.data.read('attendance_history', year: year, month: month),
          builder: (context, rows) => ListView(
            children: [
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text(dosenText(row, ['TANGGAL', 'title'])),
                    subtitle: Text(dosenText(row, ['STATUS'])),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Detil Informasi Presensi'),
                          ),
                          body: ListView(
                            children: [
                              DosenFields(
                                title: 'Informasi Presensi',
                                fields: {
                                  'Tanggal': dosenText(row, ['TANGGAL']),
                                  'Mode Kerja': dosenText(row, [
                                    'mode',
                                  ], 'WFO (demo)'),
                                  'Presensi Masuk': dosenText(row, [
                                    'start_time',
                                  ], '08:00 (demo)'),
                                  'Presensi Pulang': dosenText(row, [
                                    'end_time',
                                  ], '16:00 (demo)'),
                                  'Lokasi Masuk': 'Lokasi demo',
                                  'Lokasi Pulang': 'Lokasi demo',
                                  'Tugas Dilaksanakan': 'Tugas sintetis',
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor();
  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tambah Tugas'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: TextFormField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Tugas'),
          maxLines: 4,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Silakan mengisikan tugas yang dilaksanakan hari ini'
              : null,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, controller.text.trim());
          }
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

class _DinasEditor extends StatefulWidget {
  const _DinasEditor();
  @override
  State<_DinasEditor> createState() => _DinasEditorState();
}

class _DinasEditorState extends State<_DinasEditor> {
  bool file = false, photo = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Bukti Dukung Dinas Luar'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final field in [
            'Tanggal Mulai Dinas',
            'Tanggal Selesai Dinas',
            'Nomor Surat Tugas/Memo/Nota Dinas',
          ])
            TextFormField(decoration: InputDecoration(labelText: field)),
          TextButton(
            onPressed: () => setState(() => file = true),
            child: Text(
              file
                  ? 'Surat tugas demo dipilih'
                  : 'Pilih File Surat Tugas/Memo/Nota Dinas',
            ),
          ),
          TextButton(
            onPressed: () => setState(() => photo = true),
            child: Text(
              photo ? 'Foto kegiatan demo dipilih' : 'Ambil Foto Kegiatan',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: file && photo
            ? () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bukti dukung disimulasikan di demo lokal.'),
                  ),
                );
              }
            : null,
        child: const Text('Kirim'),
      ),
    ],
  );
}
