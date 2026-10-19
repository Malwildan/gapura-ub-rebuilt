import 'package:flutter/material.dart';

import '../../demo/dosen_data.dart';
import '../../demo/staff_modules.dart';
import '../local_role_text.dart';
import '../employee/personnel_screen.dart';
import '../employee/remuneration_screen.dart';
import '../employee/income_tax_screen.dart';
import 'dosen_academic.dart';
import 'dosen_attendance.dart';
import 'dosen_widgets.dart';

export 'dosen_pendapa.dart' show DosenPendapaView;

/// Lecturer routes share one local source for the lifetime of the demo session.
class DosenModuleScreen extends StatelessWidget {
  const DosenModuleScreen({super.key, required this.data, required this.route});
  final DosenDemoData data;
  final String route;

  @override
  Widget build(BuildContext context) => switch (route) {
    'survey_employee' => DosenAttendanceScreen(data: data),
    'jadwal_dosen' ||
    'student_pa' ||
    'publikasi' => DosenAcademicScreen(data: data, route: route),
    'kepegawaian' => PersonnelScreen(
      read: DemoStaffModules(data.session).read,
      isLecturer: true,
    ),
    'remunerasi' => RemunerationScreen(
      read: DemoStaffModules(data.session).read,
    ),
    'simkeu' => IncomeTaxScreen(
      read: DemoStaffModules(data.session).read,
      openDocument: (document, {required download}) async {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localRoleText(
                  data.session,
                  'Dokumen pajak sintetis · demo lokal.',
                ),
              ),
            ),
          );
        }
      },
    ),
    _ => const Center(child: Text('Modul tidak tersedia.')),
  };
}

class DosenProfileView extends StatelessWidget {
  const DosenProfileView({super.key, required this.data});
  final DosenDemoData data;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const DosenHeading('Profil Saya'),
      Expanded(
        child: DosenLoad(
          identity: data,
          load: () => data.read('profile'),
          builder: (context, rows) {
            final row = rows.first;
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const SizedBox(height: 18),
                const CircleAvatar(
                  radius: 42,
                  child: Icon(Icons.person, size: 46),
                ),
                const SizedBox(height: 10),
                Text(
                  dosenText(row, ['pegawai', 'NAMA']),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  dosenText(row, ['nomor_identitas']),
                  textAlign: TextAlign.center,
                ),
                Text(
                  data.session.localAccount
                      ? 'PROFIL PEGAWAI'
                      : 'AKUN PEGAWAI UB',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                for (final group in <String, Map<String, String>>{
                  'Data Diri': {
                    'Nomor seri Karpeg': dosenText(row, ['nomor_karpeg']),
                    'Pendidikan Terakhir': dosenText(row, [
                      'jenjang_pendidikan',
                    ]),
                    'Tempat dan Tanggal Lahir':
                        '${dosenText(row, ['tempat_lahir'])}, ${dosenText(row, ['tanggal_lahir'])}',
                  },
                  'Alamat dan Kontak': {
                    'Alamat': dosenText(row, ['alamat']),
                    'No. Telepon Rumah': dosenText(row, ['nomor_telp']),
                    'No. HP': dosenText(row, ['nomor_hp']),
                  },
                  'Kependudukan': {
                    'NIK/KTP': dosenText(row, ['nomor_ktp']),
                    'Agama': dosenText(row, ['agama']),
                    'Kewarganegaraan': dosenText(row, ['negara']),
                    'Status Perkawinan': dosenText(row, ['status_nikah']),
                  },
                  'Lain-lain': {
                    'No.NPWP': dosenText(row, ['nomor_npwp']),
                    'Nama Wajib Pajak': dosenText(row, ['nama_wajib_pajak']),
                  },
                }.entries)
                  DosenFields(title: group.key, fields: group.value),
              ],
            );
          },
        ),
      ),
    ],
  );
}
