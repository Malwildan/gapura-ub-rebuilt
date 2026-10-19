import 'package:flutter/material.dart';
import 'employee_app_bar.dart';

import '../../model/records.dart';
import '../../service/staff_modules.dart';

/// Tendik remuneration tabs backed by the caller's local/demo data reader.
class RemunerationScreen extends StatefulWidget {
  const RemunerationScreen({super.key, required this.read});

  final StaffRead read;

  @override
  State<RemunerationScreen> createState() => _RemunerationScreenState();
}

class _RemunerationScreenState extends State<RemunerationScreen> {
  static const _tabs = <_RemunTab>[
    _RemunTab('Profil', 'remuneration.profile'),
    _RemunTab('TGP', 'remuneration.tgp'),
    _RemunTab('Insentif Kinerja', 'remuneration.incentive'),
    _RemunTab('Insentif Tambahan', 'remuneration.additional'),
    _RemunTab('Remunerasi 13', 'remuneration.thirteenth'),
  ];

  late int _year = DateTime.now().year;
  final Map<String, _LoadState> _states = {};
  final Map<String, int> _requests = {};

  @override
  void initState() {
    super.initState();
    for (final tab in _tabs) {
      _load(tab.resource);
    }
  }

  Future<void> _load(String resource) async {
    final request = (_requests[resource] ?? 0) + 1;
    _requests[resource] = request;
    setState(() => _states[resource] = const _LoadState.loading());
    try {
      final rows = await widget.read(resource, year: _year);
      if (!mounted || _requests[resource] != request) return;
      setState(() => _states[resource] = _LoadState.data(rows));
    } catch (error) {
      if (!mounted || _requests[resource] != request) return;
      setState(() => _states[resource] = _LoadState.error(error));
    }
  }

  Future<void> _chooseYear() async {
    var selected = _year;
    final now = DateTime.now().year;
    final year = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pilih Tahun'),
          content: DropdownButton<int>(
            value: selected,
            isExpanded: true,
            items: List.generate(11, (index) => now - index)
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text('$value')),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setDialogState(() => selected = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Filter'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || year == null || year == _year) return;
    setState(() => _year = year);
    for (final tab in _tabs) {
      _load(tab.resource);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: _tabs.length,
    child: Scaffold(
      appBar: EmployeeAppBar(
        title: const Text('Remunerasi'),
        actions: [
          IconButton(
            tooltip: 'Pilih Tahun',
            onPressed: _chooseYear,
            icon: const Icon(Icons.calendar_month),
          ),
        ],
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Profil'),
            Tab(text: 'TGP'),
            Tab(text: 'Insentif Kinerja'),
            Tab(text: 'Insentif Tambahan'),
            Tab(text: 'Remunerasi 13'),
          ],
        ),
      ),
      body: TabBarView(children: _tabs.map(_buildTab).toList()),
    ),
  );

  Widget _buildTab(_RemunTab tab) {
    final state = _states[tab.resource];
    if (state == null || state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return _MessageState(
        message: 'Data remunerasi belum dapat dimuat.\n${state.error}',
        action: FilledButton.icon(
          onPressed: () => _load(tab.resource),
          icon: const Icon(Icons.refresh),
          label: const Text('Coba Lagi'),
        ),
      );
    }
    final rows = state.rows!;
    if (rows.isEmpty) {
      return _MessageState(
        message: 'Mohon maaf data Remunerasi Anda masih belum ada.',
        action: TextButton.icon(
          onPressed: () => _load(tab.resource),
          icon: const Icon(Icons.refresh),
          label: const Text('Muat Ulang'),
        ),
      );
    }
    if (tab.resource == 'remuneration.profile') {
      return _profile(rows);
    }
    return RefreshIndicator(
      onRefresh: () => _load(tab.resource),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        itemBuilder: (context, index) => _RecordCard(
          row: rows[index],
          onTap: tab.resource == 'remuneration.tgp'
              ? () => _openDetail('remuneration.deductions', rows[index], [
                  'Faktor Kurang',
                  'Ketidakhadiran dengan Keterangan',
                  'Hukuman',
                ])
              : (tab.resource == 'remuneration.incentive' ||
                    tab.resource == 'remuneration.additional')
              ? () => _openDetail('remuneration.activities', rows[index], [
                  'Nilai CKP',
                  'Nilai Kinerja',
                  'Tugas Utama',
                  'Tugas Tambahan',
                  'Tugas KPP',
                ])
              : null,
          actionLabel: tab.resource == 'remuneration.tgp'
              ? 'Potongan'
              : 'Lihat Rincian',
        ),
      ),
    );
  }

  Widget _profile(List<Record> rows) => RefreshIndicator(
    onRefresh: () => _load('remuneration.profile'),
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final row in rows)
          if (row.containsKey('label'))
            Card(
              child: ListTile(
                title: Text(value(row['label'])),
                subtitle: Text(value(row['value'])),
              ),
            )
          else
            _RecordCard(row: row),
      ],
    ),
  );

  Future<void> _openDetail(
    String resource,
    Record item,
    List<String> categories,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _RemunerationDetailScreen(
          read: widget.read,
          resource: resource,
          item: item,
          year: _year,
          categories: categories,
        ),
      ),
    );
  }
}

class _RemunTab {
  const _RemunTab(this.label, this.resource);
  final String label;
  final String resource;
}

class _LoadState {
  const _LoadState.loading() : rows = null, error = null, isLoading = true;
  const _LoadState.data(this.rows) : error = null, isLoading = false;
  const _LoadState.error(this.error) : rows = null, isLoading = false;
  final List<Record>? rows;
  final Object? error;
  final bool isLoading;
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message, required this.action});
  final String message;
  final Widget action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          action,
        ],
      ),
    ),
  );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.row,
    this.onTap,
    this.actionLabel = 'Lihat Rincian',
  });
  final Record row;
  final VoidCallback? onTap;
  final String actionLabel;
  @override
  Widget build(BuildContext context) {
    final fields = row['fields'];
    final title = value(row['title'], 'Remunerasi');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (fields is Map)
                ...fields.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: Text(entry.key)),
                        Expanded(
                          flex: 3,
                          child: Text(
                            value(entry.value),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (onTap != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: onTap, child: Text(actionLabel)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemunerationDetailScreen extends StatefulWidget {
  const _RemunerationDetailScreen({
    required this.read,
    required this.resource,
    required this.item,
    required this.year,
    required this.categories,
  });
  final StaffRead read;
  final String resource;
  final Record item;
  final int year;
  final List<String> categories;
  @override
  State<_RemunerationDetailScreen> createState() =>
      _RemunerationDetailScreenState();
}

class _RemunerationDetailScreenState extends State<_RemunerationDetailScreen> {
  List<Record>? _rows;
  Object? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = ++_request;
    setState(() {
      _rows = null;
      _error = null;
    });
    try {
      final rows = await widget.read(
        widget.resource,
        year: widget.year,
        item: widget.item,
      );
      if (!mounted || id != _request) return;
      setState(() => _rows = rows);
    } catch (error) {
      if (!mounted || id != _request) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EmployeeAppBar(
      title: Text(value(widget.item['title'], 'Rincian Remunerasi')),
    ),
    body: _rows == null
        ? _error == null
              ? const Center(child: CircularProgressIndicator())
              : _MessageState(
                  message: 'Rincian belum dapat dimuat.\n$_error',
                  action: TextButton(
                    onPressed: _load,
                    child: const Text('Coba Lagi'),
                  ),
                )
        : _rows!.isEmpty
        ? _MessageState(
            message: 'Mohon maaf data Remunerasi Anda masih belum ada.',
            action: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Muat Ulang'),
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final category in widget.categories)
                  _DetailSection(
                    category: category,
                    rows: _rows!
                        .where(
                          (row) =>
                              row['category'] == category ||
                              row['section'] == category,
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.category, required this.rows});
  final String category;
  final List<Record> rows;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category, style: Theme.of(context).textTheme.titleMedium),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Belum ada data'),
            ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _RecordCard(row: row),
            ),
        ],
      ),
    ),
  );
}
