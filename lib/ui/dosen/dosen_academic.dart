import 'package:flutter/material.dart';

import '../../common/colors.dart';
import '../../demo/dosen_data.dart';
import '../../model/records.dart';
import '../../widget/page_header.dart';

/// Recovered academic lecturer routes. Mutations are confined to [data].
class DosenAcademicScreen extends StatelessWidget {
  const DosenAcademicScreen({
    super.key,
    required this.data,
    required this.route,
  });

  final DosenDemoData data;
  final String route;

  @override
  Widget build(BuildContext context) {
    final title = switch (route) {
      'jadwal_dosen' => 'Jadwal Mengajar',
      'student_pa' => 'Bimbingan Akademik',
      _ => 'Statistik Publikasi',
    };
    return Scaffold(
      body: Column(
        children: [
          PageHeader(title: title),
          Expanded(
            child: switch (route) {
              'jadwal_dosen' => _Schedule(data: data),
              'student_pa' => _Advisees(data: data),
              _ => _Publications(data: data),
            },
          ),
        ],
      ),
    );
  }
}

const _days = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];
const _degrees = [
  'Semua Jenjang',
  'S1',
  'S2',
  'S3',
  'D3',
  'D4',
  'Profesi',
  'Sp1',
  'Sp2',
];
const _statuses = [
  'Semua Status',
  'Aktif',
  'Tidak daftar ulang',
  'Pindah program studi',
  'Tidak terdaftar',
  'Terminal kuliah',
  'Lain-lain',
  'Perpanjangan kuliah',
  'Mengundurkan diri',
  'Drop out',
  'Lulus kuliah',
  'Evaluasi studi',
  'Status belum tersedia',
  'Terdaftar',
  'Meninggal',
  'Blokir',
  'Selesai',
  'Cuti',
  'Double degree',
  'Merdeka belajar',
  'Menunggu uji kompetensi',
];

String _v(Record r, List<String> keys, [String fallback = '—']) {
  for (final key in keys) {
    final value = r[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return fallback;
}

String _dayText(Record row) {
  final raw = _v(row, ['HARI_KE', 'day'], '1');
  final n = int.tryParse(raw);
  if (n != null && n >= 1 && n <= 7) return _days[n - 1];
  const names = {
    'senin': 'SEN',
    'selasa': 'SEL',
    'rabu': 'RAB',
    'kamis': 'KAM',
    'jumat': 'JUM',
    'sabtu': 'SAB',
    'minggu': 'MIN',
  };
  return names[raw.toLowerCase()] ?? raw.toUpperCase();
}

Widget _empty(String text) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Text(text, textAlign: TextAlign.center),
  ),
);
Widget _error(Object error, VoidCallback retry) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Data tidak dapat dimuat.\n$error', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: retry, child: const Text('Coba lagi')),
      ],
    ),
  ),
);

void _reportFailure(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Data demo tidak dapat diproses: $error')),
  );
}
Widget _section(String title, Widget child) => Card(
  margin: const EdgeInsets.fromLTRB(12, 7, 12, 5),
  child: Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: blue,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  ),
);
Widget _field(String label, String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 145, child: Text(label)),
      Expanded(child: Text(text)),
    ],
  ),
);

class _Schedule extends StatefulWidget {
  const _Schedule({required this.data});
  final DosenDemoData data;
  @override
  State<_Schedule> createState() => _ScheduleState();
}

class _ScheduleState extends State<_Schedule> {
  int revision = 0;
  String faculty = 'Semua Fakultas',
      degree = 'Semua Jenjang',
      semester = 'Semua Semester',
      category = 'Semua';
  String appliedFaculty = 'Semua Fakultas',
      appliedDegree = 'Semua Jenjang',
      appliedSemester = 'Semua Semester',
      appliedCategory = 'Semua';

  Future<List<Record>> _read() => widget.data.read('schedule');
  Future<void> _refresh() async {
    if (mounted) setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 7,
    child: Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'Filter Jadwal Mengajar',
            onPressed: _filter,
            icon: const Icon(Icons.filter_alt, color: blue),
          ),
        ),
        const TabBar(
          isScrollable: true,
          labelColor: blue,
          tabs: [
            Tab(text: 'SEN'),
            Tab(text: 'SEL'),
            Tab(text: 'RAB'),
            Tab(text: 'KAM'),
            Tab(text: 'JUM'),
            Tab(text: 'SAB'),
            Tab(text: 'MIN'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [for (var i = 1; i <= 7; i++) _dayPane(i)],
          ),
        ),
      ],
    ),
  );

  Widget _dayPane(int day) => _AsyncPane(
    key: ValueKey('schedule-$day-$revision'),
    load: _read,
    emptyText: 'Tidak ada Jadwal Mengajar untuk hari ini.',
    refresh: _refresh,
    builder: (context, rows) {
      final filtered = rows.where((r) {
        final d = int.tryParse(_v(r, ['HARI_KE'], '0'));
        final dayMatch = d == day || _dayText(r) == _days[day - 1];
        final f = _v(r, ['FAKULTAS', 'faculty'], '');
        final j = _v(r, ['JENJANG', 'K_JENJANG'], '');
        final sm = _v(r, ['SEMESTER', 'semester'], '');
        final cat = _v(r, ['KATEGORI', 'IS_PENDEK'], '');
        final catLabel = cat == '1'
            ? 'Pendek'
            : cat == '0'
            ? 'Reguler'
            : cat;
        return dayMatch &&
            (appliedFaculty == 'Semua Fakultas' || f == appliedFaculty) &&
            (appliedDegree == 'Semua Jenjang' || j == appliedDegree) &&
            (appliedSemester == 'Semua Semester' || sm == appliedSemester) &&
            (appliedCategory == 'Semua' || catLabel == appliedCategory);
      }).toList();
      if (filtered.isEmpty) {
        return _empty('Tidak ada Jadwal Mengajar untuk hari ini.');
      }
      return ListView(
        children: [for (final row in filtered) _courseCard(context, row)],
      );
    },
  );

  Widget _courseCard(BuildContext context, Record row) {
    final name = _v(row, ['NAMA', 'course', 'title'], 'Mata kuliah');
    final start = _v(row, ['JAM_MULAI'], '—');
    final end = _v(row, ['JAM_SELESAI'], '—');
    final room = _v(row, ['RUANG_KULIAH', 'room']);
    final building = _v(row, ['K_GEDUNG_KULIAH', 'gedung']);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name · Kelas ${_v(row, ['KELAS', 'class'])}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              '${_v(row, ['K_MK'])}  ·  ${_v(row, ['PROG_STUDI', 'JENJANG'])}',
            ),
            Text('Tahun: ${_v(row, ['TAHUN', 'THN_MK', 'year'])}'),
            Text('$start–$end WIB  ·  Ruang $room  ·  Gedung $building'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _courseAction(
                  context,
                  'Kuliah',
                  Icons.menu_book,
                  () => _openTeaching(context, row),
                ),
                _courseAction(
                  context,
                  'Presensi',
                  Icons.fact_check,
                  () => _openRecap(context, row),
                ),
                _courseAction(
                  context,
                  'Pengumuman',
                  Icons.campaign,
                  () => _openAnnouncements(context, row),
                ),
                _courseAction(
                  context,
                  'Ingatkan',
                  Icons.event,
                  () => _openReminder(context, row),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _courseAction(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback action,
  ) => OutlinedButton.icon(
    onPressed: action,
    icon: Icon(icon, size: 17),
    label: Text(label),
  );

  Future<void> _filter() async {
    late final List<Record> rows;
    try {
      rows = await _read();
    } catch (error) {
      if (mounted) _reportFailure(context, error);
      return;
    }
    if (!mounted) return;
    final faculties = [
      'Semua Fakultas',
      ...{
        for (final r in rows) _v(r, ['FAKULTAS', 'faculty'], ''),
      }.where((x) => x.isNotEmpty),
    ];
    final semesters = [
      'Semua Semester',
      ...{
        for (final r in rows) _v(r, ['SEMESTER', 'semester'], ''),
      }.where((x) => x.isNotEmpty),
    ];
    String f = appliedFaculty,
        d = appliedDegree,
        s = appliedSemester,
        c = appliedCategory;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Filter Jadwal Mengajar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _drop(
                  'Pilih Fakultas',
                  f,
                  faculties,
                  (v) => setDialog(() => f = v),
                ),
                _drop(
                  'Pilih Jenjang',
                  d,
                  _degrees,
                  (v) => setDialog(() => d = v),
                ),
                _drop(
                  'Pilih Semester',
                  s,
                  semesters,
                  (v) => setDialog(() => s = v),
                ),
                _drop('Kategori Semester', c, const [
                  'Semua',
                  'Reguler',
                  'Pendek',
                ], (v) => setDialog(() => c = v)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  appliedFaculty = f;
                  appliedDegree = d;
                  appliedSemester = s;
                  appliedCategory = c;
                  revision++;
                });
                Navigator.pop(context);
              },
              child: const Text('Filter'),
            ),
          ],
        ),
      ),
    );
  }

  void _openTeaching(BuildContext context, Record row) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => _Teaching(data: widget.data, course: row),
    ),
  );
  void _openRecap(BuildContext context, Record row) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => _Recap(data: widget.data, course: row),
    ),
  );
  void _openAnnouncements(BuildContext context, Record row) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => _Announcements(data: widget.data, course: row),
    ),
  );
  void _openReminder(BuildContext context, Record row) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => _Reminder(data: widget.data, course: row),
    ),
  );
}

Widget _drop(
  String label,
  String value,
  List<String> options,
  ValueChanged<String> change,
) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: DropdownButtonFormField<String>(
    initialValue: options.contains(value) ? value : options.first,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: options
        .map(
          (x) => DropdownMenuItem(
            value: x,
            child: Text(x, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (v) {
      if (v != null) change(v);
    },
  ),
);

class _Teaching extends StatefulWidget {
  const _Teaching({required this.data, required this.course});
  final DosenDemoData data;
  final Record course;
  @override
  State<_Teaching> createState() => _TeachingState();
}

class _TeachingState extends State<_Teaching> {
  int revision = 0;
  Future<void> _reload() async {
    if (mounted) setState(() => revision++);
  }

  Future<List<Record>> _read(String resource) =>
      widget.data.read(resource, item: widget.course);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sub Capaian Pembelajaran')),
    body: DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            labelColor: blue,
            tabs: [
              Tab(text: 'Draft'),
              Tab(text: 'Aktif'),
              Tab(text: 'Riwayat'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AsyncPane(
                  key: ValueKey('draft$revision'),
                  load: () => _read('teaching_drafts'),
                  emptyText: 'Mohon maaf tidak ada data untuk ditampilkan.',
                  refresh: _reload,
                  builder: (c, rows) => ListView(
                    children: [
                      for (final r in rows) _teachingCard(context, r, 'draft'),
                    ],
                  ),
                ),
                _AsyncPane(
                  key: ValueKey('active$revision'),
                  load: () => _read('teaching_active'),
                  emptyText: 'Mohon maaf tidak ada data untuk ditampilkan.',
                  refresh: _reload,
                  builder: (c, rows) => ListView(
                    children: [
                      for (final r in rows) _teachingCard(context, r, 'active'),
                    ],
                  ),
                ),
                _AsyncPane(
                  key: ValueKey('history$revision'),
                  load: () => _read('teaching_history'),
                  emptyText: 'Mohon maaf tidak ada data untuk ditampilkan.',
                  refresh: _reload,
                  builder: (c, rows) => ListView(
                    children: [
                      for (final r in rows)
                        _teachingCard(context, r, 'history'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _create,
      backgroundColor: navigationSelected,
      child: const Icon(Icons.add, color: navigationBackground),
    ),
  );
  Widget _teachingCard(BuildContext context, Record row, String kind) => Card(
    margin: const EdgeInsets.all(10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _v(row, ['MATERI', 'title'], 'Materi'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          _field('Tanggal ajar', _v(row, ['TANGGAL', 'TGL_ABSENSI'])),
          _field(
            'Jam',
            '${_v(row, ['JAM_MULAI'])}–${_v(row, ['JAM_SELESAI'])}',
          ),
          _field(
            'Batas presensi mahasiswa',
            _v(row, ['Batas presensi', 'BATAS_PRESENSI']),
          ),
          _field('Keterangan', _v(row, ['KETERANGAN'])),
          Wrap(
            spacing: 6,
            children: [
              if (kind == 'draft') ...[
                OutlinedButton(
                  onPressed: () => _confirm(
                    context,
                    'Hapus Draft',
                    'Apakah Anda yakin menghapus draft ini?',
                    () async {
                      await widget.data.remove(
                        'teaching_drafts',
                        _v(row, ['id']),
                      );
                      await _reload();
                    },
                  ),
                  child: const Text('Hapus Draft'),
                ),
                FilledButton(
                  onPressed: () => _confirm(
                    context,
                    'Mulai Presensi',
                    'Yakin mengaktifkan perkuliahan ini?',
                    () async {
                      await widget.data.save('teaching_active', {
                        ...row,
                        'id': null,
                        'status': 'Aktif',
                      });
                      await widget.data.remove(
                        'teaching_drafts',
                        _v(row, ['id']),
                      );
                      await _reload();
                    },
                  ),
                  child: const Text('Mulai Presensi'),
                ),
              ],
              if (kind == 'active') ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _Roster(data: widget.data, material: row),
                    ),
                  ),
                  icon: const Icon(Icons.people),
                  label: const Text('Daftar Mahasiswa'),
                ),
                FilledButton(
                  onPressed: () => _confirm(
                    context,
                    'Akhiri Presensi',
                    'Apakah anda yakin mengakhiri perkuliahan ini?',
                    () async {
                      await widget.data.save('teaching_history', {
                        ...row,
                        'id': null,
                        'status': 'Riwayat',
                      });
                      await widget.data.remove(
                        'teaching_active',
                        _v(row, ['id']),
                      );
                      await _reload();
                    },
                  ),
                  child: const Text('Akhiri Presensi'),
                ),
              ],
              if (kind == 'history')
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _Roster(data: widget.data, material: row),
                    ),
                  ),
                  icon: const Icon(Icons.people),
                  label: const Text('Daftar'),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _create() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TeachingForm(
        onSave: (values, active) async {
          await widget.data.save(
            active ? 'teaching_active' : 'teaching_drafts',
            {
              ...values,
              'class_id': widget.course['id'],
              'parent_id': widget.course['id'],
              'MATA_KULIAH': _v(widget.course, ['NAMA', 'course', 'title']),
              'KELAS': _v(widget.course, ['KELAS', 'class']),
              'status': active ? 'Aktif' : 'Draft',
            },
          );
          await _reload();
        },
      ),
    );
  }
}

class _TeachingForm extends StatefulWidget {
  const _TeachingForm({required this.onSave});
  final Future<void> Function(Record, bool) onSave;
  @override
  State<_TeachingForm> createState() => _TeachingFormState();
}

class _TeachingFormState extends State<_TeachingForm> {
  final _form = GlobalKey<FormState>();
  final _materi = TextEditingController();
  final _date = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _duration = TextEditingController(text: '15');
  final _notes = TextEditingController();
  bool saving = false;
  @override
  void dispose() {
    for (final c in [_materi, _date, _start, _end, _duration, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sub Capaian Pembelajaran'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _input(_materi, 'Sub Capaian Pembelajaran'),
              _input(_date, 'Tanggal Perkuliahan', hint: 'YYYY-MM-DD'),
              _input(_start, 'Jam Mulai Perkuliahan', hint: 'HH:MM'),
              _input(_end, 'Jam Akhir Perkuliahan', hint: 'HH:MM'),
              _input(
                _duration,
                'Batas Presensi Mahasiswa',
                keyboard: TextInputType.number,
              ),
              _input(
                _notes,
                'Keterangan',
                hint: 'Catatan materi (sertakan "http://" jika berupa link)',
                lines: 3,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      OutlinedButton(
        onPressed: saving ? null : () => _submit(false),
        child: const Text('Simpan Sebagai Draft'),
      ),
      FilledButton(
        onPressed: saving ? null : () => _submit(true),
        child: const Text('Simpan dan Aktifkan'),
      ),
    ],
  );
  Widget _input(
    TextEditingController c,
    String label, {
    String? hint,
    TextInputType? keyboard,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: TextFormField(
      controller: c,
      keyboardType: keyboard,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: (v) => (v == null || v.trim().isEmpty)
          ? 'Lengkapi data terlebih dahulu.'
          : null,
    ),
  );
  Future<void> _submit(bool active) async {
    if (!_form.currentState!.validate()) return;
    if (int.tryParse(_duration.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Durasi presensi harus integer.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await widget.onSave({
        'MATERI': _materi.text.trim(),
        'TANGGAL': _date.text.trim(),
        'JAM_MULAI': _start.text.trim(),
        'JAM_SELESAI': _end.text.trim(),
        'Batas presensi': _duration.text.trim(),
        'KETERANGAN': _notes.text.trim(),
      }, active);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        _reportFailure(context, error);
      }
    }
  }
}

Widget _input(
  TextEditingController c,
  String label, {
  String? hint,
  TextInputType? keyboard,
  int lines = 1,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: TextField(
    controller: c,
    keyboardType: keyboard,
    maxLines: lines,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
  ),
);

Future<void> _confirm(
  BuildContext context,
  String title,
  String prompt,
  Future<void> Function() action,
) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(prompt),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Konfirmasi'),
        ),
      ],
    ),
  );
  if (yes == true) {
    try {
      await action();
    } catch (error) {
      if (context.mounted) _reportFailure(context, error);
    }
  }
}

class _Roster extends StatelessWidget {
  const _Roster({required this.data, required this.material});
  final DosenDemoData data;
  final Record material;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Daftar Mahasiswa')),
    body: _AsyncPane(
      load: () => data.read('student_attendance', item: material),
      emptyText: 'Mohon maaf tidak ada data untuk ditampilkan.',
      refresh: () async {},
      builder: (context, rows) => ListView(
        children: [
          for (final r in rows)
            _section(
              _v(r, ['NAMA', 'nama'], 'Mahasiswa'),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field('NIM', _v(r, ['NIM'])),
                  _field(
                    'Presensi',
                    _attendanceLabel(_v(r, ['K_ABSENSI', 'STATUS'], 'A')),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

String _attendanceLabel(String code) => switch (code.toUpperCase()) {
  'H' || 'HADIR' => 'Hadir',
  'I' || 'IJIN' || 'IZIN' => 'Ijin',
  'S' || 'SAKIT' => 'Sakit',
  _ =>
    code.toUpperCase() == 'A' || code.toUpperCase() == 'ALPHA' ? 'Alpha' : code,
};

class _Recap extends StatelessWidget {
  const _Recap({required this.data, required this.course});
  final DosenDemoData data;
  final Record course;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rekap Presensi')),
    body: _AsyncPane(
      load: () => data.read('attendance_recap', item: course),
      emptyText: 'Mohon maaf tidak ada data untuk ditampilkan.',
      refresh: () async {},
      builder: (context, rows) => ListView(
        children: [
          for (final r in rows)
            _section(
              'Rekap Presensi',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field('Pertemuan :', _v(r, ['PERTEMUAN', 'pertemuan'])),
                  _field('Hadir :', _v(r, ['HADIR', 'hadir'])),
                  _field('Ijin :', _v(r, ['IJIN', 'ijin'])),
                  _field('Sakit :', _v(r, ['SAKIT', 'sakit'])),
                  _field('Alpha :', _v(r, ['ALPHA', 'alpha'])),
                  _field('Rekap :', _v(r, ['REKAP', 'rekap'])),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _Announcements extends StatefulWidget {
  const _Announcements({required this.data, required this.course});
  final DosenDemoData data;
  final Record course;
  @override
  State<_Announcements> createState() => _AnnouncementsState();
}

class _AnnouncementsState extends State<_Announcements> {
  int revision = 0;
  Future<void> reload() async {
    setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengumuman')),
    body: _AsyncPane(
      key: ValueKey(revision),
      load: () => widget.data.read('class_announcements', item: widget.course),
      emptyText: 'Belum ada pengumuman',
      refresh: reload,
      builder: (context, rows) => ListView(
        children: [
          for (final row in rows)
            Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                title: Text(_v(row, ['PENGUMUMAN', 'title'])),
                subtitle: Text(
                  '${_v(row, ['TGL_AWAL'])} – ${_v(row, ['TGL_AKHIR'])}',
                ),
                trailing: IconButton(
                  tooltip: 'Hapus',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirm(
                    context,
                    'Hapus data tugas',
                    'Anda yakin ingin menghapus data ini?',
                    () async {
                      await widget.data.remove(
                        'class_announcements',
                        _v(row, ['id']),
                      );
                      await reload();
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _create,
      child: const Icon(Icons.add),
    ),
  );
  Future<void> _create() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AnnouncementForm(
        onSave: (values) async {
          await widget.data.save('class_announcements', {
            ...values,
            'parent_id': widget.course['id'],
            'MATA_KULIAH': _v(widget.course, ['NAMA', 'course']),
            'KELAS': _v(widget.course, ['KELAS', 'class']),
          });
          await reload();
        },
      ),
    );
  }
}

class _AnnouncementForm extends StatefulWidget {
  const _AnnouncementForm({required this.onSave});
  final Future<void> Function(Record) onSave;
  @override
  State<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends State<_AnnouncementForm> {
  final _content = TextEditingController(),
      _start = TextEditingController(),
      _end = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    _content.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pengumuman'),
    content: SizedBox(
      width: 450,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _input(_content, 'Ketikkan pengumuman', lines: 4),
            _input(_start, 'Tanggal mulai pengumuman', hint: 'YYYY-MM-DD'),
            _input(_end, 'Tanggal selesai pengumuman', hint: 'YYYY-MM-DD'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(onPressed: busy ? null : _save, child: const Text('Simpan')),
    ],
  );
  Future<void> _save() async {
    if (_content.text.trim().isEmpty ||
        _start.text.trim().isEmpty ||
        _end.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _content.text.trim().isEmpty
                ? 'Isi pengumuman wajib diisi'
                : 'Tanggal mulai dan selesai wajib diisi',
          ),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await widget.onSave({
        'PENGUMUMAN': _content.text.trim(),
        'TGL_AWAL': _start.text.trim(),
        'TGL_AKHIR': _end.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => busy = false);
        _reportFailure(context, error);
      }
    }
  }
}

class _Reminder extends StatefulWidget {
  const _Reminder({required this.data, required this.course});
  final DosenDemoData data;
  final Record course;
  @override
  State<_Reminder> createState() => _ReminderState();
}

class _ReminderState extends State<_Reminder> {
  String? selected;
  bool loaded = false;
  Object? error;
  late Future<List<Record>> future;
  @override
  void initState() {
    super.initState();
    future = widget.data.read('calendars');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Atur Pengingat Jadwal')),
    body: FutureBuilder<List<Record>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _error(
            snap.error!,
            () => setState(() {
              future = widget.data.read('calendars');
            }),
          );
        }
        final rows = snap.data ?? [];
        if (rows.isEmpty) {
          return _empty('Tidak ada akun kalender.');
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(
              '${_v(widget.course, ['NAMA', 'course'])} · ${_v(widget.course, ['JAM_MULAI'])}–${_v(widget.course, ['JAM_SELESAI'])} WIB',
            ),
            const SizedBox(height: 12),
            const Text('Pilih Akun Anda untuk menambahkan jadwal :'),
            for (final r in rows)
              // ignore: deprecated_member_use
              RadioListTile<String>(
                title: Text('Akun Kalender ke ${rows.indexOf(r) + 1}'),
                subtitle: Text(_v(r, ['name', 'account_name', 'title'])),
                value: _v(r, ['calendar_id', 'id']),
                // ignore: deprecated_member_use
                groupValue: selected,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => selected = v),
              ),
            if (loaded)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Jadwal demo dipilih secara lokal. Tidak ada acara perangkat yang dibuat.',
                  ),
                ),
              ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => setState(() => loaded = true),
              child: const Text('Tambah Jadwal'),
            ),
          ],
        );
      },
    ),
  );
}

class _Advisees extends StatefulWidget {
  const _Advisees({required this.data});
  final DosenDemoData data;
  @override
  State<_Advisees> createState() => _AdviseesState();
}

class _AdviseesState extends State<_Advisees> {
  final _search = TextEditingController();
  int revision = 0;
  String faculty = 'Semua Fakultas',
      degree = 'Semua Jenjang',
      status = 'Semua Status';
  String appliedFaculty = 'Semua Fakultas',
      appliedDegree = 'Semua Jenjang',
      appliedStatus = 'Semua Status';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 2),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Nama/NIM',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Filter Daftar Mahasiswa',
              onPressed: _filter,
              icon: const Icon(Icons.filter_alt, color: blue),
            ),
          ],
        ),
      ),
      Expanded(
        child: _AsyncPane(
          key: ValueKey(revision),
          load: () => widget.data.read('advisees'),
          emptyText: 'Mohon maaf tidak ada data untuk ditampilkan.',
          refresh: refresh,
          builder: (context, rows) {
            final q = _search.text.trim().toLowerCase();
            final matched = rows
                .where(
                  (r) =>
                      (q.isEmpty ||
                          _v(r, [
                            'NAMA',
                            'name',
                          ], '').toLowerCase().contains(q) ||
                          _v(r, [
                            'NIM',
                            'nim',
                          ], '').toLowerCase().contains(q)) &&
                      (appliedFaculty == 'Semua Fakultas' ||
                          _v(r, ['FAKULTAS']) == appliedFaculty) &&
                      (appliedDegree == 'Semua Jenjang' ||
                          _v(r, ['JENJANG']) == appliedDegree) &&
                      (appliedStatus == 'Semua Status' ||
                          _v(r, ['STATUS']) == appliedStatus),
                )
                .toList();
            if (matched.isEmpty) {
              return _empty('Mohon maaf tidak ada data untuk ditampilkan.');
            }
            return ListView(
              children: [
                for (final r in matched)
                  _section(
                    'Daftar Mahasiswa Bimbingan ${_v(r, ['NAMA', 'name'])}',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field('NIM', _v(r, ['NIM', 'nim'])),
                        _field('Jenjang', _v(r, ['JENJANG'])),
                        _field('Fakultas', _v(r, ['FAKULTAS'])),
                        _field('Prodi', _v(r, ['PRODI'])),
                        _field('Status :', _v(r, ['STATUS'])),
                        _field('Semester :', _v(r, ['SEMESTER'])),
                        _field('IPK :', _v(r, ['IPK'])),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );
  Future<void> _filter() async {
    late final List<Record> rows;
    try {
      rows = await widget.data.read('advisees');
    } catch (error) {
      if (mounted) _reportFailure(context, error);
      return;
    }
    if (!mounted) return;
    final faculties = [
      'Semua Fakultas',
      ...{
        for (final r in rows) _v(r, ['FAKULTAS'], ''),
      }.where((x) => x.isNotEmpty),
    ];
    String f = appliedFaculty, d = appliedDegree, s = appliedStatus;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Filter Daftar Mahasiswa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _drop(
                'Pilih Fakultas',
                f,
                faculties,
                (v) => setDialog(() => f = v),
              ),
              _drop(
                'Pilih Jenjang',
                d,
                _degrees,
                (v) => setDialog(() => d = v),
              ),
              _drop(
                'Pilih Status Aktif',
                s,
                _statuses,
                (v) => setDialog(() => s = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  appliedFaculty = f;
                  appliedDegree = d;
                  appliedStatus = s;
                });
                Navigator.pop(context);
              },
              child: const Text('Filter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Publications extends StatelessWidget {
  const _Publications({required this.data});
  final DosenDemoData data;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Column(
      children: [
        const TabBar(
          isScrollable: true,
          labelColor: blue,
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Output'),
            Tab(text: 'Rank in Affiliation'),
            Tab(text: 'Affiliation Rank'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              _publicationPane(
                'publication_overview',
                'Data publikasi belum tersedia.',
                _overview,
              ),
              _publicationPane(
                'publication_output',
                'Data publikasi belum tersedia.',
                _output,
              ),
              _publicationPane(
                'publication_people',
                'Tidak ada data.',
                _personRank,
              ),
              _publicationPane(
                'publication_affiliations',
                'Tidak ada data.',
                _affiliationRank,
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _publicationPane(
    String resource,
    String empty,
    Widget Function(Record) render,
  ) => _AsyncPane(
    load: () => data.read(resource),
    emptyText: empty,
    refresh: () async {},
    builder: (context, rows) =>
        ListView(children: [for (final row in rows) render(row)]),
  );
  Widget _overview(Record r) => Column(
    children: [
      _section(
        _v(r, ['name', 'NAMA'], 'Peneliti'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('', 'Universitas Brawijaya'),
            _field('SINTA ID :', _v(r, ['sinta_id'])),
            _field('Overall Score', _v(r, ['sinta_score'])),
            _field('3 Years Score', _v(r, ['sinta_score_3yr'])),
            _field('Rank in National', _v(r, ['sinta_national_rank'])),
            _field('Rank in Affiliation', _v(r, ['sinta_affiliation_rank'])),
          ],
        ),
      ),
    ],
  );
  Widget _output(Record r) {
    final groups = <String, List<(String, String)>>{
      'Scopus': [
        ('Score', 'scopus_score'),
        ('Documents', 'scopus_doc'),
        ('Citations', 'scopus_citation'),
        ('H-Index', 'scopus_h_index'),
        ('i10-Index', 'scopus_i_index'),
        ('G-Index', 'scopus_g_index'),
      ],
      'WoS': [
        ('Score', 'wos_score'),
        ('Documents', 'wos_doc'),
        ('Citations', 'wos_citation'),
        ('H-Index', 'wos_h_index'),
        ('i10-Index', 'wos_i_index'),
        ('G-Index', 'wos_g_index'),
      ],
      'Google Scholar': [
        ('Score', 'google_score'),
        ('Documents', 'google_doc'),
        ('Citations', 'google_cited_doc'),
        ('H-Index', 'google_h_index'),
        ('i10-Index', 'google_i_index'),
        ('G-Index', 'google_g_index'),
      ],
      'Garuda': [
        ('Score', 'garuda_score'),
        ('Documents', 'garuda_doc'),
        ('Citations', 'garuda_citation'),
        ('H-Index', 'garuda_h_index'),
        ('i10-Index', 'garuda_i_index'),
        ('G-Index', 'garuda_g_index'),
      ],
    };
    return Column(
      children: [
        _section(
          'Citations per Year',
          Text(
            'Tahun: ${_v(r, ['tahun'])}   ·   Score: ${_v(r, ['status_value'])}',
          ),
        ),
        for (final entry in groups.entries)
          _section(
            entry.key,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final metric in entry.value)
                  _field(metric.$1, _v(r, [metric.$2])),
              ],
            ),
          ),
        _section('Books', _field('Books', _v(r, ['sinta_books']))),
      ],
    );
  }

  Widget _personRank(Record r) => _section(
    _v(r, ['NAMA', 'name'], 'Peneliti'),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field('NIDN :', _v(r, ['NIDN'])),
        _field('Overall Score V2', _v(r, ['Overall Score V2'])),
        _field('Score', _v(r, ['Score'])),
      ],
    ),
  );
  Widget _affiliationRank(Record r) => _section(
    _v(r, ['Code', 'name'], 'Afiliasi'),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field('Code :', _v(r, ['Code'])),
        _field('All Year Score V2', _v(r, ['All Year Score V2'])),
        _field('All Year Score', _v(r, ['All Year Score'])),
      ],
    ),
  );
}

class _AsyncPane extends StatefulWidget {
  const _AsyncPane({
    super.key,
    required this.load,
    required this.emptyText,
    required this.refresh,
    required this.builder,
  });
  final Future<List<Record>> Function() load;
  final String emptyText;
  final Future<void> Function() refresh;
  final Widget Function(BuildContext, List<Record>) builder;
  @override
  State<_AsyncPane> createState() => _AsyncPaneState();
}

class _AsyncPaneState extends State<_AsyncPane> {
  late Future<List<Record>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  void didUpdateWidget(covariant _AsyncPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.load != widget.load) _future = widget.load();
  }

  Future<void> _refresh() async {
    try {
      await widget.refresh();
    } catch (_) {
      // The replacement future below owns displaying any failed read.
    } finally {
      if (mounted) setState(() => _future = widget.load());
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Record>>(
    future: _future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snap.hasError) {
        return _error(
          snap.error!,
          () => setState(() => _future = widget.load()),
        );
      }
      final rows = snap.data ?? [];
      if (rows.isEmpty) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * .55,
                child: _empty(widget.emptyText),
              ),
            ],
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: _refresh,
        child: widget.builder(context, rows),
      );
    },
  );
}
