import 'package:flutter/material.dart';
import 'employee_app_bar.dart';

import '../../model/records.dart';
import '../../service/staff_modules.dart';

/// Employee income and PPh21 reports. Data always comes from the injected reader.
class IncomeTaxScreen extends StatefulWidget {
  const IncomeTaxScreen({
    super.key,
    required this.read,
    required this.openDocument,
  });

  final StaffRead read;
  final StaffOpenDocument openDocument;

  @override
  State<IncomeTaxScreen> createState() => _IncomeTaxScreenState();
}

class _IncomeTaxScreenState extends State<IncomeTaxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late int _year;
  late int _month;
  final Map<String, List<Record>> _data = {};
  final Map<String, Object> _errors = {};
  final Map<String, bool> _loading = {};
  final Map<String, int> _requestIds = {};
  final Set<String> _documentActions = {};
  int _lastTab = 0;

  static const _resources = [
    'income.reports',
    'income.documents',
    'income.bonus',
  ];
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
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _tabs = TabController(length: 3, vsync: this)..addListener(_onTabChanged);
    _loadCurrent();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  String get _currentResource => _resources[_tabs.index];

  void _onTabChanged() {
    if (_lastTab == _tabs.index) return;
    _lastTab = _tabs.index;
    if (!_data.containsKey(_currentResource) &&
        _loading[_currentResource] != true) {
      _loadCurrent();
    }
  }

  void _invalidatePeriod() {
    for (final resource in _resources) {
      _requestIds[resource] = (_requestIds[resource] ?? 0) + 1;
    }
    _data.clear();
    _errors.clear();
    _loading.clear();
  }

  Future<void> _loadCurrent() async {
    await _loadResource(_currentResource);
  }

  Future<void> _loadResource(String resource) async {
    final requestId = (_requestIds[resource] ?? 0) + 1;
    _requestIds[resource] = requestId;
    setState(() {
      _loading[resource] = true;
      _errors.remove(resource);
    });
    try {
      final rows = await widget.read(
        resource,
        year: _year,
        month: resource == 'income.reports' ? _month : null,
      );
      if (!mounted || _requestIds[resource] != requestId) return;
      setState(() => _data[resource] = rows);
    } catch (error) {
      if (!mounted || _requestIds[resource] != requestId) return;
      setState(() => _errors[resource] = error);
    } finally {
      if (mounted && _requestIds[resource] == requestId) {
        setState(() => _loading[resource] = false);
      }
    }
  }

  Future<void> _choosePeriod() async {
    var year = _year;
    var month = _month;
    final selected = await showDialog<(int, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tahun - Bulan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: year,
                decoration: const InputDecoration(labelText: 'Pilih Tahun'),
                items: _years
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text('$value')),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => year = value ?? year),
              ),
              DropdownButtonFormField<int>(
                initialValue: month,
                decoration: const InputDecoration(labelText: 'Pilih Bulan'),
                items: List.generate(
                  12,
                  (i) =>
                      DropdownMenuItem(value: i + 1, child: Text(_months[i])),
                ),
                onChanged: (value) =>
                    setDialogState(() => month = value ?? month),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, (year, month)),
              child: const Text('Filter'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _year = selected.$1;
      _month = selected.$2;
      _invalidatePeriod();
    });
    _loadCurrent();
  }

  List<int> get _years => List.generate(10, (i) => DateTime.now().year - i);

  Future<void> _chooseYear(String resource) async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Pilih Tahun'),
        children: _years
            .map(
              (year) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, year),
                child: Text(
                  '$year',
                  style: TextStyle(
                    fontWeight: year == _year ? FontWeight.bold : null,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (!mounted || selected == null || selected == _year) return;
    setState(() {
      _year = selected;
      _invalidatePeriod();
    });
    _loadCurrent();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EmployeeAppBar(
      title: const Text('Rekap Pendapatan & PPh21'),
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Pendapatan'),
          Tab(text: 'Bukti Potong'),
          Tab(text: 'Bonus Prestasi UB'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: [
        _reportTab('income.reports', period: true),
        _reportTab('income.documents', period: false),
        _reportTab('income.bonus', period: false),
      ],
    ),
  );

  Widget _reportTab(String resource, {required bool period}) {
    final loading = _loading[resource] ?? false;
    final error = _errors[resource];
    final rows = _data[resource];
    return RefreshIndicator(
      onRefresh: () async {
        if (_currentResource == resource) await _loadCurrent();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text(period ? 'Tahun - Bulan' : 'Tahun'),
              subtitle: Text(
                period ? '${_months[_month - 1]} $_year' : '$_year',
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: () => period ? _choosePeriod() : _chooseYear(resource),
            ),
          ),
          if (loading && rows == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            _errorView(error)
          else if (rows == null || rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('Data belum tersedia.')),
            )
          else
            ...rows.map(
              (row) => resource == 'income.documents'
                  ? _documentCard(row)
                  : _fieldsCard(row, bonus: resource == 'income.bonus'),
            ),
          if (loading && rows != null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: LinearProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _errorView(Object error) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data belum dapat dimuat. $error'),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadCurrent,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );

  Widget _fieldsCard(Record row, {required bool bonus}) {
    final rawFields = row['fields'];
    final fields = rawFields is Map
        ? Map<String, dynamic>.from(rawFields)
        : <String, dynamic>{};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value(row['title'], bonus ? 'Bonus Prestasi UB' : 'Pendapatan'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (bonus && !fields.containsKey('Bruto')) const SizedBox.shrink(),
            ...fields.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(entry.key)),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(value(entry.value), textAlign: TextAlign.end),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _documentCard(Record row) {
    const title = 'Bukti Pemotongan PPh Pasal 21';
    final key = '${row['id'] ?? row['title'] ?? row.hashCode}';
    final busy = _documentActions.contains(key);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value(row['title'], title),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('Dokumen PDF'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => _openDocument(key, row, download: false),
                  child: const Text('TINJAU'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => _openDocument(key, row, download: true),
                  child: const Text('UNDUH'),
                ),
              ],
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocument(
    String key,
    Record row, {
    required bool download,
  }) async {
    setState(() => _documentActions.add(key));
    try {
      await widget.openDocument(row, download: download);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dokumen belum dapat dibuka. $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _documentActions.remove(key));
    }
  }
}
