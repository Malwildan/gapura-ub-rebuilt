import 'package:flutter/material.dart';

import '../../demo/dosen_data.dart';
import '../../demo/demo_session.dart';
import '../../model/records.dart';
import '../local_role_text.dart';

/// Offline, synthetic implementation of the lecturer Pendapa document flows.
class DosenPendapaView extends StatelessWidget {
  const DosenPendapaView({super.key, required this.data});
  final DosenDemoData data;

  static const destinations = <_Destination>[
    _Destination(
      'Kalender',
      Icons.calendar_month,
      'pendapa_calendar',
      _Flow.calendar,
    ),
    _Destination(
      'Surat Tugas',
      Icons.assignment_outlined,
      'pendapa_tasks',
      _Flow.tasks,
    ),
    _Destination(
      'Surat Masuk',
      Icons.inbox_outlined,
      'pendapa_incoming',
      _Flow.incoming,
    ),
    _Destination(
      'Paraf Surat Keluar',
      Icons.draw_outlined,
      'pendapa_paraf',
      _Flow.paraf,
    ),
    _Destination('Tanda tangan', Icons.edit_document, 'pendapa_tte', _Flow.tte),
    _Destination(
      'Riwayat Surat Masuk',
      Icons.history,
      'pendapa_incoming_history',
      _Flow.incomingHistory,
    ),
    _Destination(
      'Riwayat Surat Keluar',
      Icons.history,
      'pendapa_paraf_history',
      _Flow.outgoingHistory,
    ),
    _Destination(
      'Arsip',
      Icons.archive_outlined,
      'pendapa_archive',
      _Flow.archive,
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const _PageTitle(
          title: 'PENDAPA',
          subtitle: 'Perkantoran Digital Terpadu',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final d in destinations)
                Card(
                  child: ListTile(
                    leading: Icon(
                      d.icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(d.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(context, d),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  void _open(BuildContext context, _Destination d) {
    final Widget screen = switch (d.flow) {
      _Flow.calendar => _PendapaCalendar(data: data),
      _Flow.outgoingHistory => _OutgoingHistory(data: data),
      _ => _DocumentQueue(data: data, destination: d),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

enum _Flow {
  calendar,
  tasks,
  incoming,
  paraf,
  tte,
  incomingHistory,
  outgoingHistory,
  parafHistory,
  archive,
}

class _Destination {
  const _Destination(this.label, this.icon, this.resource, this.flow);
  final String label;
  final IconData icon;
  final String resource;
  final _Flow flow;
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(subtitle!),
            ),
        ],
      ),
    ),
  );
}

class _DocumentQueue extends StatefulWidget {
  const _DocumentQueue({
    required this.data,
    required this.destination,
    this.historyTab,
  });
  final DosenDemoData data;
  final _Destination destination;
  final String? historyTab;
  @override
  State<_DocumentQueue> createState() => _DocumentQueueState();
}

class _DocumentQueueState extends State<_DocumentQueue> {
  late Future<List<Record>> _future;
  final _search = TextEditingController();
  final Set<String> _selected = {};
  String _filter = 'Semua';
  static const _filters = [
    'Semua',
    'Menunggu',
    'Setuju',
    'Revisi',
    'Ditolak',
    'Selesai dan Arsipkan',
  ];
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Record>> _load() => widget.data.read(widget.destination.resource);
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _title => widget.historyTab == 'paraf'
      ? 'Riwayat Paraf'
      : widget.historyTab == 'tte'
      ? 'Riwayat Tanda tangan'
      : widget.destination.flow == _Flow.tte
      ? 'Perlu ditandatangani'
      : widget.destination.label;
  bool get _selectable => const {
    _Flow.tasks,
    _Flow.incoming,
    _Flow.paraf,
    _Flow.tte,
  }.contains(widget.destination.flow);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_title),
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: 'Cari surat',
              border: const OutlineInputBorder(),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Text('Status'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filter,
                items: [
                  for (final f in _filters)
                    DropdownMenuItem(value: f, child: Text(f)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _filter = v);
                },
              ),
              const Spacer(),
              if (_selectable) Text('${_selected.length} dipilih'),
            ],
          ),
        ),
        if (_selectable) _batchActions(),
        Expanded(
          child: FutureBuilder<List<Record>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) return _LoadError(onRetry: _refresh);
              final all = snap.data ?? const <Record>[];
              final rows = _filterRows(all);
              if (rows.isEmpty) {
                return _EmptyState(
                  message: all.isEmpty
                      ? 'Tidak ada data.'
                      : 'Tidak ada surat yang cocok dengan pencarian atau filter.',
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: rows.length,
                  itemBuilder: (context, i) => _card(rows[i]),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _batchActions() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Wrap(
      spacing: 8,
      children: [
        if (widget.destination.flow == _Flow.tasks ||
            widget.destination.flow == _Flow.incoming)
          OutlinedButton.icon(
            onPressed: () => _batch('archive'),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Arsipkan'),
          ),
        if (widget.destination.flow == _Flow.paraf)
          OutlinedButton.icon(
            onPressed: () => _batch('paraf'),
            icon: const Icon(Icons.draw_outlined),
            label: const Text('Paraf multiple'),
          ),
        if (widget.destination.flow == _Flow.tte)
          OutlinedButton.icon(
            onPressed: () => _batch('tte'),
            icon: const Icon(Icons.edit_document),
            label: const Text('TTE multiple'),
          ),
      ],
    ),
  );

  List<Record> _filterRows(List<Record> rows) {
    final query = _search.text.trim().toLowerCase();
    return rows.where((r) {
      if (_selectable && r['processed_locally'] == true) return false;
      final searchable = [
        r['notugas'],
        r['tugas'],
        r['title'],
        r['unit'],
        r['status'],
        r['tglsurat'],
      ].whereType<Object>().join(' ').toLowerCase();
      final status = (r['status'] ?? '').toString().toLowerCase();
      return (query.isEmpty || searchable.contains(query)) &&
          (_filter == 'Semua' || status.contains(_filter.toLowerCase()));
    }).toList();
  }

  Widget _card(Record row) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Column(
      children: [
        ListTile(
          leading: _selectable
              ? Checkbox(
                  value: _selected.contains(_id(row)),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.add(_id(row));
                    } else {
                      _selected.remove(_id(row));
                    }
                  }),
                )
              : null,
          title: Text(
            _field(row, ['notugas', 'NOMOR_SURAT', 'title'], 'Surat sintetis'),
          ),
          subtitle: Text(
            '${_field(row, ['tugas', 'judul', 'title'], 'Judul surat tidak tersedia')}\n${_field(row, ['tglsurat', 'tanggal'], '')}${_field(row, ['status'], '').isEmpty ? '' : ' · ${_field(row, ['status'], '')}'}',
          ),
          isThreeLine: true,
          onTap: () => _openRow(row),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            children: [
              TextButton.icon(
                onPressed: () => _openTimeline(row),
                icon: const Icon(Icons.timeline),
                label: const Text('Timeline'),
              ),
              TextButton.icon(
                onPressed: () => _openPdf(row),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _openRow(Record row) {
    final type = switch (widget.destination.flow) {
      _Flow.incoming || _Flow.paraf => 'paraf',
      _Flow.tte => 'tte',
      _ => null,
    };
    if (type == null) {
      _openDetail(row);
    } else {
      _openForm(row, type);
    }
  }

  Future<void> _openDetail(Record row) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _DocumentDetail(data: widget.data, row: row),
      ),
    );
  }

  Future<void> _openTimeline(Record row) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _DocumentTimeline(data: widget.data, row: row),
      ),
    );
  }

  Future<void> _openPdf(Record row) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _SyntheticPdf(row: row, session: widget.data.session),
      ),
    );
  }

  Future<void> _openForm(Record row, String type) async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ActionForm(
          data: widget.data,
          resource: widget.destination.resource,
          rows: [row],
          type: type,
        ),
      ),
    );
    if (done == true && mounted) _refresh();
  }

  Future<void> _batch(String type) async {
    if (_selected.isEmpty) {
      _message('Pilih setidaknya satu surat terlebih dahulu.');
      return;
    }
    final all = await _future;
    if (!mounted) return;
    final rows = all.where((r) => _selected.contains(_id(r))).toList();
    if (rows.isEmpty) {
      _message('Surat terpilih sudah tidak tersedia. Muat ulang daftar.');
      return;
    }
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ActionForm(
          data: widget.data,
          resource: widget.destination.resource,
          rows: rows,
          type: type,
          multi: true,
        ),
      ),
    );
    if (done == true && mounted) {
      _selected.clear();
      _refresh();
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _refresh() async {
    final next = _load();
    if (mounted) {
      setState(() {
        _future = next;
        _selected.clear();
      });
    }
    try {
      await next;
    } catch (_) {}
  }
}

class _OutgoingHistory extends StatelessWidget {
  const _OutgoingHistory({required this.data});
  final DosenDemoData data;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat TTE Anda'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Paraf'),
            Tab(text: 'Tanda tangan'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _DocumentQueue(
            data: data,
            destination: const _Destination(
              'Riwayat Paraf',
              Icons.history,
              'pendapa_paraf_history',
              _Flow.parafHistory,
            ),
            historyTab: 'paraf',
          ),
          _DocumentQueue(
            data: data,
            destination: const _Destination(
              'Riwayat Tanda tangan',
              Icons.history,
              'pendapa_tte_history',
              _Flow.parafHistory,
            ),
            historyTab: 'tte',
          ),
        ],
      ),
    ),
  );
}

class _PendapaCalendar extends StatefulWidget {
  const _PendapaCalendar({required this.data});
  final DosenDemoData data;
  @override
  State<_PendapaCalendar> createState() => _PendapaCalendarState();
}

class _PendapaCalendarState extends State<_PendapaCalendar> {
  late DateTime _month;
  late Future<List<Record>> _future;
  DateTime? _selected;
  static const _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
    _future = _load();
  }

  Future<List<Record>> _load() => widget.data.read(
    'pendapa_calendar',
    year: _month.year,
    month: _month.month,
  );
  void _move(int n) => setState(() {
    _month = DateTime(_month.year, _month.month + n);
    _selected = null;
    _future = _load();
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Kalender Anda'),
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: () => setState(() => _future = _load()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Record>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _LoadError(onRetry: () => setState(() => _future = _load()));
        }
        final grouped = <DateTime, List<Record>>{};
        for (final row in snap.data ?? const <Record>[]) {
          final d = DateTime.tryParse(
            _field(row, ['tanggal', 'tglsurat', 'date'], ''),
          );
          if (d != null) {
            grouped
                .putIfAbsent(DateTime(d.year, d.month, d.day), () => [])
                .add(row);
          }
        }
        final days = grouped.keys.toList()..sort();
        final selected = _selected ?? (days.isEmpty ? null : days.first);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _move(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    '${_months[_month.month - 1]} ${_month.year}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: () => _move(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('Sen'),
                  Text('Sel'),
                  Text('Rab'),
                  Text('Kam'),
                  Text('Jum'),
                  Text('Sab'),
                  Text('Min'),
                ],
              ),
            ),
            _calendarGrid(_month, days, selected),
            const Divider(),
            Expanded(
              child: selected == null
                  ? const _EmptyState(
                      message: 'Tidak ada agenda surat pada bulan ini.',
                    )
                  : ListView(
                      children: [
                        for (final row in grouped[selected] ?? const [])
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.event),
                              title: Text(
                                _field(row, ['tugas', 'title'], 'Agenda surat'),
                              ),
                              subtitle: Text(
                                '${_field(row, ['notugas'], 'Nomor surat tidak tersedia')} · ${_field(row, ['tanggal', 'tglsurat'], '')}',
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => _DocumentDetail(
                                    data: widget.data,
                                    row: row,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    ),
  );
  Widget _calendarGrid(
    DateTime month,
    List<DateTime> eventDays,
    DateTime? selected,
  ) {
    final offset = DateTime(month.year, month.month, 1).weekday - 1;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((offset + count + 6) ~/ 7) * 7;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cells,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.2,
        ),
        itemBuilder: (context, i) {
          final day = i - offset + 1;
          if (day < 1 || day > count) return const SizedBox.shrink();
          final date = DateTime(month.year, month.month, day);
          final has = eventDays.contains(date);
          final chosen = selected == date;
          return InkWell(
            onTap: has ? () => setState(() => _selected = date) : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: chosen
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  child: Text(
                    '$day',
                    style: TextStyle(color: chosen ? Colors.white : null),
                  ),
                ),
                if (has)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DocumentDetail extends StatelessWidget {
  const _DocumentDetail({required this.data, required this.row});
  final DosenDemoData data;
  final Record row;
  static const _fields = <(String, List<String>)>[
    ('No Surat', ['notugas']),
    ('Jenis Surat', ['jenissurat']),
    ('Tanggal Surat', ['tglsurat']),
    ('Unit', ['unit']),
    ('Judul Surat', ['tugas', 'title']),
    ('Deskripsi', ['deskripsi']),
    ('Urgensi', ['urgensi']),
    ('Jenis Lokasi', ['jenislokasi']),
    ('Lokasi', ['lokasi']),
    ('Jenis Meeting', ['jenismeeting']),
    ('Jenis Lampiran', ['jenislampiran']),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Informasi Surat')),
    body: FutureBuilder<List<Record>>(
      future: data.read('document_detail', item: row),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _LoadError(
            onRetry: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(
                builder: (_) => _DocumentDetail(data: data, row: row),
              ),
            ),
          );
        }
        final doc = snap.data?.firstOrNull ?? row;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final f in _fields)
              if (_field(doc, f.$2, '').isNotEmpty)
                Card(
                  child: ListTile(
                    title: Text(f.$1),
                    subtitle: Text(_field(doc, f.$2, '')),
                  ),
                ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Pratinjau dokumen'),
                subtitle: Text(
                  localRoleText(data.session, 'Pratinjau sintetis lokal'),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        _SyntheticPdf(row: doc, session: data.session),
                  ),
                ),
              ),
            ),
            FutureBuilder<List<Record>>(
              future: data.read('document_attachments', item: doc),
              builder: (context, files) {
                if (files.connectionState != ConnectionState.done ||
                    files.hasError ||
                    (files.data?.isEmpty ?? true)) {
                  return const SizedBox.shrink();
                }
                return Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ListTile(title: Text('Lampiran')),
                      for (final file in files.data!)
                        ListTile(
                          leading: const Icon(Icons.attach_file),
                          title: Text(
                            _field(
                              file,
                              ['filename', 'title'],
                              data.session.localAccount
                                  ? 'Lampiran'
                                  : 'Lampiran sintetis',
                            ),
                          ),
                          subtitle: Text(
                            localRoleText(data.session, 'Berkas demo lokal'),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => _SyntheticPdf(
                                row: file,
                                session: data.session,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    ),
  );
}

class _DocumentTimeline extends StatelessWidget {
  const _DocumentTimeline({required this.data, required this.row});
  final DosenDemoData data;
  final Record row;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Timeline Surat')),
    body: FutureBuilder<List<Record>>(
      future: data.read('document_timeline', item: row),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _LoadError(
            onRetry: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(
                builder: (_) => _DocumentTimeline(data: data, row: row),
              ),
            ),
          );
        }
        final entries = snap.data ?? const <Record>[];
        if (entries.isEmpty) {
          return const _EmptyState(message: 'Timeline surat belum tersedia.');
        }
        return ListView(
          children: [
            for (final e in entries)
              ListTile(
                leading: const Icon(Icons.circle, size: 12),
                title: Text(_field(e, ['status', 'title'], 'Perubahan surat')),
                subtitle: Text(_field(e, ['tanggal', 'date'], '')),
              ),
          ],
        );
      },
    ),
  );
}

class _SyntheticPdf extends StatelessWidget {
  const _SyntheticPdf({required this.row, this.session});
  final Record row;
  final DemoSession? session;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pratinjau Dokumen')),
    body: Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                _field(
                  row,
                  ['filename', 'notugas', 'title', 'tugas'],
                  session?.localAccount == true
                      ? 'Dokumen'
                      : 'Dokumen sintetis',
                ),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                localRoleText(
                  session,
                  'Pratinjau sintetis lokal. Tidak ada berkas yang diunduh atau dibuka.',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ActionForm extends StatefulWidget {
  const _ActionForm({
    required this.data,
    required this.resource,
    required this.rows,
    required this.type,
    this.multi = false,
  });
  final DosenDemoData data;
  final String resource;
  final List<Record> rows;
  final String type;
  final bool multi;
  @override
  State<_ActionForm> createState() => _ActionFormState();
}

class _ActionFormState extends State<_ActionForm> {
  final Map<String, TextEditingController> _controllers = {};
  String? _status;
  bool _busy = false;
  TextEditingController _text(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);
  bool get _multi => widget.multi;
  String get _title => switch (widget.type) {
    'archive' => 'Arsipkan Surat Multiple',
    'paraf' => _multi ? 'Paraf Surat Multiple' : 'Paraf / Verifikasi Surat',
    'tte' => _multi ? 'TTE Multiple Surat' : 'Validasi dan TTE',
    _ => 'Proses Surat',
  };
  List<String> get _statuses {
    if (widget.type == 'archive') return ['Selesai dan Arsipkan'];
    if (widget.type == 'tte') return ['Setuju', 'Ditolak'];
    if (widget.type != 'paraf') return const [];
    if (_multi) return ['Setuju', 'Revisi'];
    // The map proves branch variation but does not normalize every condition.
    final verifier = (widget.rows.first['tagverifikator'] ?? '').toString();
    final choices = <String>['Setuju', 'Revisi'];
    if (verifier == 'penerima' || verifier == 'disposisi') {
      choices.insert(1, 'Disposisi');
    }
    if (verifier == 'disposisi') choices.insert(2, 'Distribusi');
    if (verifier == 'paraf' || verifier == 'pengusul') {
      choices.insert(1, 'Selesai dan Arsipkan');
    }
    return choices;
  }

  @override
  void initState() {
    super.initState();
    final r = widget.rows.first;
    _text('number').text = _field(r, ['notugas'], '');
    _text('title').text = _field(r, ['tugas', 'title'], '');
    _status = _statuses.first;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title)),
    body: SafeArea(
      child: Form(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.type == 'paraf' || widget.type == 'archive')
              _input('number', _multi ? 'Nomor Surat' : 'No Surat'),
            if (widget.type != 'archive' || !_multi)
              _input('title', 'Judul Surat'),
            _input('note', 'Catatan', lines: 3),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final s in _statuses)
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: (v) => setState(() => _status = v),
            ),
            if (widget.type == 'paraf' &&
                !_multi &&
                !widget.data.session.localAccount)
              Padding(
                padding: EdgeInsets.only(top: 4, bottom: 10),
                child: Text(
                  localRoleText(
                    widget.data.session,
                    'Pilihan status disederhanakan untuk data demo.',
                  ),
                  style: TextStyle(fontSize: 12),
                ),
              ),
            if (widget.type == 'paraf' || widget.type == 'archive') ...[
              _input('disposition', 'Disposisi'),
              _input('to', 'Kepada'),
              _input('dispositionNote', 'Catatan Disposisi', lines: 2),
            ],
            if (widget.type == 'tte' &&
                !_multi &&
                !widget.data.session.localAccount)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: const Text('Lampiran'),
                  subtitle: const Text('Buka pratinjau sintetis'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _SyntheticPdf(
                        row: widget.rows.first,
                        session: widget.data.session,
                      ),
                    ),
                  ),
                ),
              ),
            if (!widget.data.session.localAccount &&
                (widget.type == 'tte' ||
                    (widget.type == 'paraf' && _status == 'Setuju'))) ...[
              _input('nik', 'NIK TTE'),
              _input(
                'passphrase',
                'Passphrase',
                obscure: true,
                helper:
                    'Demo sintetis saja. Tidak disimpan atau digunakan untuk tanda tangan.',
              ),
            ],
            if (_multi)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '${widget.rows.length} surat diproses secara lokal.',
                ),
              ),
            if (!widget.data.session.localAccount)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Simulasi demo lokal. Tidak ada verifikasi UB atau penandatanganan elektronik.',
                  style: TextStyle(color: Colors.deepOrange),
                ),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context, false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: _busy ? null : _confirm,
                  child: Text(_busy ? 'Memproses…' : 'Kirim'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  Widget _input(
    String key,
    String label, {
    int lines = 1,
    bool obscure = false,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: _text(key),
      maxLines: obscure ? 1 : lines,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  Future<void> _confirm() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: Text(
          'Proses ${widget.rows.length} surat dengan status “$_status”${widget.data.session.localAccount ? '' : ' pada data demo lokal'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final target = _status == 'Selesai dan Arsipkan'
          ? 'pendapa_archive'
          : widget.type == 'tte'
          ? 'pendapa_tte_history'
          : widget.type == 'paraf'
          ? 'pendapa_paraf_history'
          : 'pendapa_archive';
      for (final row in widget.rows) {
        final updated = Map<String, dynamic>.from(row)
          ..['status'] = _status
          ..['catatan_demo'] = _text('note').text.trim()
          ..['processed_locally'] = true;
        if (_text('disposition').text.trim().isNotEmpty) {
          updated['disposisi_demo'] = _text('disposition').text.trim();
        }
        if (_text('to').text.trim().isNotEmpty) {
          updated['kepada_demo'] = _text('to').text.trim();
        }
        if (_text('dispositionNote').text.trim().isNotEmpty) {
          updated['catatan_disposisi_demo'] = _text(
            'dispositionNote',
          ).text.trim();
        }
        // Credential fields exist only to mirror the synthetic form. Never
        // write them to queue/history records, even under demo-only aliases.
        // Keep linked detail/timeline/attachment records; hide handled items from queues.
        await widget.data.save(widget.resource, updated);
        await widget.data.save(target, {...updated, 'id': null});
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localRoleText(
              widget.data.session,
              'Disimpan di demo lokal. Tidak ada layanan UB yang digunakan.',
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localRoleText(
                widget.data.session,
                'Perubahan demo gagal disimpan: $e',
              ),
            ),
          ),
        );
      }
    }
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.red),
        const SizedBox(height: 8),
        const Text('Data gagal dimuat'),
        TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

String _id(Record r) => (r['document_id'] ?? r['id'] ?? '').toString();
String _field(Record r, List<String> keys, String fallback) {
  for (final k in keys) {
    final v = r[k];
    if (v != null && v.toString().trim().isNotEmpty) return v.toString();
  }
  return fallback;
}
