import 'package:flutter/material.dart';
import 'employee_app_bar.dart';

import '../../model/records.dart';
import '../../service/staff_modules.dart';

const personnelHistoryGroups = <String, List<String>>{
  'Profil': ['Keaktifan', 'Keluarga', 'Penghargaan'],
  'Karir': [
    'Kepangkatan',
    'Perubahan Gaji',
    'Jab. Fungsional',
    'Jab. Struktural',
    'Jab. NonStruktural',
    'Homebase',
    'Serdos',
  ],
  'Kualifikasi Pendidikan': ['Formal', 'Non Formal', 'Sertifikat Kompetensi'],
};

const _historyAssets = {
  'Keaktifan': 'keaktifan',
  'Keluarga': 'keluarga',
  'Penghargaan': 'penghargaan',
  'Kepangkatan': 'kepangkatan',
  'Perubahan Gaji': 'perubahan',
  'Jab. Fungsional': 'jabfungsional',
  'Jab. Struktural': 'jabstruktural',
  'Jab. NonStruktural': 'jabstruktural',
  'Homebase': 'homebase',
  'Serdos': 'serdos',
  'Formal': 'formal',
  'Non Formal': 'nonformal',
  'Sertifikat Kompetensi': 'nonformal',
};

class PersonnelScreen extends StatelessWidget {
  const PersonnelScreen({
    super.key,
    required this.read,
    this.isLecturer = false,
  });
  final StaffRead read;
  final bool isLecturer;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: EmployeeAppBar(
        title: const Text('Kepegawaian'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Data Diri'),
            Tab(text: 'SISTER'),
            Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _RecordList(read: read, resource: 'personnel.profile', profile: true),
          isLecturer
              ? _RecordList(
                  read: read,
                  resource: 'personnel.sister',
                  profile: true,
                )
              : const Center(child: Text('Data tidak tersedia')),
          _HistoryGroups(read: read),
        ],
      ),
    ),
  );
}

class _HistoryGroups extends StatelessWidget {
  const _HistoryGroups({required this.read});
  final StaffRead read;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      for (final group in personnelHistoryGroups.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          child: Text(group.key, style: Theme.of(context).textTheme.titleLarge),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final category in group.value)
              SizedBox(
                width: 155,
                child: Card(
                  child: InkWell(
                    key: ValueKey('history-category-$category'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PersonnelHistoryScreen(
                          read: read,
                          category: category,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset(
                            'assets/icon/pegawai_${_historyAssets[category]}.png',
                            width: 40,
                            height: 40,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(height: 8),
                          Text(category),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ],
  );
}

class PersonnelHistoryScreen extends StatelessWidget {
  const PersonnelHistoryScreen({
    super.key,
    required this.read,
    required this.category,
  });
  final StaffRead read;
  final String category;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EmployeeAppBar(title: Text(category)),
    body: _RecordList(
      read: read,
      resource: 'personnel.history',
      category: category,
      history: true,
    ),
  );
}

class _RecordList extends StatefulWidget {
  const _RecordList({
    required this.read,
    required this.resource,
    this.category,
    this.profile = false,
    this.history = false,
  });
  final StaffRead read;
  final String resource;
  final String? category;
  final bool profile;
  final bool history;

  @override
  State<_RecordList> createState() => _RecordListState();
}

class _RecordListState extends State<_RecordList> {
  List<Record>? rows;
  Object? error;
  bool loading = true;
  int requestId = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant _RecordList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource != widget.resource ||
        oldWidget.category != widget.category) {
      load();
    }
  }

  Future<void> load() async {
    final id = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.read(
        widget.resource,
        category: widget.category,
      );
      if (!mounted || id != requestId) return;
      setState(() {
        rows = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted || id != requestId) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    requestId++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return _MessageState(
        message: 'Data belum dapat dimuat.',
        action: 'Coba lagi',
        onPressed: load,
      );
    }
    if (rows == null || rows!.isEmpty) {
      return RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text('Mohon maaf data Kepegawaian Anda masih belum ada.'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [for (final row in rows!) _recordTile(row)],
      ),
    );
  }

  Widget _recordTile(Record row) {
    if (widget.profile) {
      return Card(
        child: ListTile(
          title: Text(value(row['label'], '')),
          subtitle: Text(value(row['value'], '—')),
        ),
      );
    }
    final fields = row['fields'];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value(row['title'], 'Riwayat'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (fields is Map)
              for (final field in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${field.key}: ${value(field.value)}'),
                ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.message,
    required this.action,
    required this.onPressed,
  });
  final String message;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 8),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    ),
  );
}
