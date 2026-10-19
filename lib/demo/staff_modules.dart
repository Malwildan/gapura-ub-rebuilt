import '../model/records.dart';
import 'demo_session.dart';

/// Synthetic presentation records only. No account adapter or HTTP fallback.
class DemoStaffModules {
  DemoStaffModules(this.session);
  final DemoSession session;
  final requests = <String>[];
  static const resources = {
    'personnel.profile',
    'personnel.sister',
    'personnel.history',
    'remuneration.profile',
    'remuneration.tgp',
    'remuneration.incentive',
    'remuneration.additional',
    'remuneration.thirteenth',
    'remuneration.deductions',
    'remuneration.activities',
    'income.reports',
    'income.documents',
    'income.bonus',
  };

  Future<List<Record>> read(
    String resource, {
    int? year,
    int? month,
    String? category,
    Record? item,
  }) async {
    if (!session.role.employee || !resources.contains(resource)) {
      throw UnsupportedError('Layanan pegawai tidak tersedia untuk peran ini.');
    }
    if (resource == 'personnel.sister' && session.role != DemoRole.lecturer) {
      throw StateError('Data tidak tersedia');
    }
    if (month != null && (month < 1 || month > 12)) {
      throw const FormatException('Bulan tidak valid.');
    }
    requests.add(resource);
    await session.read();
    if (session.scenario == DemoScenario.empty) return [];
    final selectedYear = year ?? DateTime.now().year;
    final selectedMonth = month ?? DateTime.now().month;
    final period = '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}';
    Record field(String label, String value) => {
      'label': label,
      'value': value,
    };
    Record entry(String title, Map<String, dynamic> fields) => {
      'id': 'DEMO-$resource-$selectedYear-$selectedMonth',
      'title': title,
      'fields': fields,
    };
    return switch (resource) {
      'personnel.profile' => [
        field('Nama', 'Demo ${session.role.label}'),
        field('Tempat dan Tanggal Lahir', 'Kota Demo, 01 Januari 1990'),
        field('Nomor seri Karpeg', 'DEMO-KARPEG-001'),
        field('Pangkat / Golongan', 'Pangkat Demo / III-a'),
        field('TMT Golongan', '01 Januari 2024'),
        field('Jabatan Fungsional', 'Jabatan Demo'),
        field('TMT Jabatan Fungsional', '01 Januari 2024'),
        field('Pendidikan Dinilai', 'S1 Demo'),
        field('Pendidikan Terakhir', 'S1 Demo'),
        field('Masa Kerja', '2 tahun (sintetis)'),
        field('Masa Kerja Golongan', '2 tahun (sintetis)'),
        field('Unit', 'Unit Demo'),
        field('Jurusan', 'Jurusan Demo'),
        field('Program Studi', 'Program Studi Demo'),
      ],
      'personnel.sister' => [
        field('Nama', 'Demo Dosen'),
        field('Unit', 'Unit Demo'),
        field('Pendidikan Terakhir', 'S2 Demo'),
      ],
      'personnel.history' => [
        entry('Demo ${category ?? 'Riwayat'}', {
          'Keterangan': 'Catatan ${category ?? 'pegawai'} sintetis',
          'Tanggal': '01 Januari $selectedYear',
          'Unit': 'Unit Demo',
        }),
      ],
      'remuneration.profile' => [
        field('Jabatan', 'Jabatan Demo'),
        field('Total Remunerasi', 'Rp 3.000.000 (sintetis)'),
        field('Maksimum TGP', 'Rp 2.000.000 (sintetis)'),
        field('Maksimum Insentif', 'Rp 1.000.000 (sintetis)'),
      ],
      'remuneration.tgp' => [
        entry('TGP Demo $selectedYear', {
          'Periode': '$selectedYear',
          'TGP': 'Rp 2.000.000',
          'Potongan': 'Rp 100.000',
        }),
      ],
      'remuneration.incentive' => [
        entry('Insentif Kinerja Demo $selectedYear', {
          'Periode': '$selectedYear',
          'Insentif': 'Rp 750.000',
        }),
      ],
      'remuneration.additional' => [
        entry('Insentif Tambahan Demo $selectedYear', {
          'Periode': '$selectedYear',
          'Insentif': 'Rp 250.000',
        }),
      ],
      'remuneration.thirteenth' => [
        entry('Remunerasi 13 Demo $selectedYear', {
          'Tahun': '$selectedYear',
          'Remunerasi 13': 'Rp 2.000.000',
        }),
      ],
      'remuneration.deductions' => [
        for (final section in [
          'Faktor Kurang',
          'Ketidakhadiran dengan Keterangan',
          'Hukuman',
        ])
          {
            ...entry(section, {'Keterangan': 'Contoh $section sintetis'}),
            'section': section,
          },
      ],
      'remuneration.activities' => [
        for (final section in [
          'Nilai CKP',
          'Nilai Kinerja',
          'Tugas Utama',
          'Tugas Tambahan',
          'Tugas KPP',
        ])
          {
            ...entry(section, {'Keterangan': 'Contoh $section sintetis'}),
            'section': section,
          },
      ],
      'income.reports' => [
        entry('Pendapatan Demo $period', {
          'Periode': period,
          'Bruto': 'Rp 5.000.000',
          'Pajak': 'Rp 100.000',
          'Tabungan Pajak': 'Rp 50.000',
          'Zakat': 'Rp 100.000',
          'Netto': 'Rp 4.750.000',
        }),
      ],
      'income.documents' => [
        {
          'id': 'DEMO-TAX-$selectedYear',
          'title': 'Bukti Potong Demo $selectedYear',
          'year': selectedYear,
          'synthetic': true,
        },
      ],
      'income.bonus' => [
        entry('Bonus Prestasi UB Demo $selectedYear', {
          'Tahun': '$selectedYear',
          'Bruto': 'Rp 500.000',
        }),
      ],
      _ => throw UnsupportedError('Pembaca pegawai tidak tersedia.'),
    };
  }
}
