import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/demo/demo_adapters.dart';
import 'package:gapura_ub/demo/demo_session.dart';
import 'package:gapura_ub/demo/dosen_data.dart';
import 'package:gapura_ub/demo/staff_modules.dart';
import 'package:gapura_ub/demo/tax_document.dart';

DemoSession local(DemoRole role) => DemoSession(
  role: role,
  scenario: DemoScenario.populated,
  delay: Duration.zero,
  localAccount: true,
);

void main() {
  test(
    'local academic identities and parent linked child use coherent records',
    () async {
      final parent = local(DemoRole.parent);
      final child = local(DemoRole.student);
      expect(parent.profile['NAMA'], 'Budi Santoso');
      expect(parent.profile['NAMA_ANAK'], child.profile['NAMA']);
      expect(parent.profile['NIM_ANAK'], child.profile['NIM']);
      expect(parent.identity['email'], 'parent@example.com');
      final response = await DemoAccount(parent).request('profile');
      final profile = (response['mhs'] as Map)['data'] as List;
      expect(profile.single['NAMA'], parent.profile['NAMA']);
      await expectLater(
        DemoAccount(parent).request('attendanceSubmit'),
        throwsStateError,
      );
    },
  );

  test(
    'local academic, Tendik and lecturer data are realistic and isolated',
    () async {
      final studentAccount = DemoAccount(local(DemoRole.student));
      final schedule =
          ((await studentAccount.request('schedule'))['jadwal'] as Map)['data']
              as List;
      expect(schedule.first['KULIAH'], 'Reguler Sistem Informasi 1');
      expect(schedule.first['K_MK'], 'SIK61001');
      final finance =
          ((await studentAccount.request('finance'))['tagihan'] as Map)['data']
              as List;
      expect(finance.single['JENIS_BAYAR'], 'UKT Semester Ganjil');
      expect(finance.single['JML_TAGIH'], '1000000');

      final staff = local(DemoRole.staff);
      expect(staff.profile['NAMA'], 'Nadia Kusumawardani');
      final staffRows = await DemoStaffModules(staff).read('personnel.profile');
      expect(staffRows.first['value'], 'Nadia Kusumawardani');
      expect(
        staffRows.singleWhere(
          (row) => row['label'] == 'Nomor seri Karpeg',
        )['value'],
        'KP-1987-0426',
      );
      final taxRows = await DemoStaffModules(
        staff,
      ).read('income.documents', year: 2026);
      final document = DemoTaxDocument(taxRows.single);
      expect(document.lines, contains('Nama: Nadia Kusumawardani'));
      expect(document.lines, isNot(contains('DEMO - DATA SINTETIS')));

      final lecturer = local(DemoRole.lecturer);
      final data = DosenDemoData(lecturer);
      final profile = (await data.read('profile')).single;
      expect(profile['pegawai'], 'Dr. Raka Pradipta');
      final teachingSchedule = (await data.read('schedule')).single;
      expect(teachingSchedule['K_MK'], 'SIK61001');
      expect(teachingSchedule['K_GEDUNG_KULIAH'], 'F');
      expect(
        (await data.read('document_detail')).single['notugas'],
        'SUR-2026-01045',
      );
      final pendapa = (await data.read('pendapa_tasks')).single;
      final id = pendapa['id'];
      expect(pendapa['title'], 'Tugas tindak lanjut surat');
      final saved = await data.save('pendapa_tasks', {
        ...pendapa,
        'status': 'Diproses',
      });
      expect(saved['id'], id);
      expect((await data.read('pendapa_tasks')).single['status'], 'Diproses');
      expect(
        (await DosenDemoData(
          local(DemoRole.lecturer),
        ).read('pendapa_tasks')).single['status'],
        'Menunggu',
      );
    },
  );

  test(
    'local Tendik may use only employee and Pendapa data resources',
    () async {
      final staff = local(DemoRole.staff);
      final data = DosenDemoData(staff);
      for (final resource in ['profile', 'employee']) {
        final row = (await data.read(resource)).single;
        expect(row['pegawai'], staff.profile['NAMA']);
        expect(row['NIM'], staff.profile['NIM']);
        expect(row['nomor_identitas'], staff.profile['NIM']);
        expect(row['jenjang_pendidikan'], 'S1 Administrasi Pendidikan');
        expect(row['unit'], 'Direktorat Akademik');
      }

      for (final resource in ['attendance', 'tasks', 'pendapa_tasks']) {
        final original = (await data.read(resource)).single;
        final id = original['id'];
        final saved = await data.save(resource, {
          ...original,
          'status': 'Diproses',
        });
        expect(saved['id'], id, reason: resource);
        expect((await data.read(resource)).single['id'], id, reason: resource);
        expect((await data.read(resource)).single['status'], 'Diproses');
        await data.remove(resource, id.toString());
        expect(await data.read(resource), isEmpty, reason: resource);
      }

      await expectLater(data.read('schedule'), throwsUnsupportedError);
      await expectLater(data.read('advisees'), throwsUnsupportedError);
      await expectLater(
        DosenDemoData(
          DemoSession(
            role: DemoRole.staff,
            scenario: DemoScenario.populated,
            delay: Duration.zero,
          ),
        ).read('profile'),
        throwsUnsupportedError,
      );
    },
  );

  test('local lecturer profile values match its session identity', () async {
    final lecturer = local(DemoRole.lecturer);
    final row = (await DosenDemoData(lecturer).read('profile')).single;
    expect(row['pegawai'], lecturer.profile['NAMA']);
    expect(row['NIM'], lecturer.profile['NIM']);
    expect(row['nomor_identitas'], lecturer.profile['NIM']);
    expect(row['agama'], 'Islam');
    expect(row['status_nikah'], 'Menikah');
    expect(row['jenjang_pendidikan'], 'S3 Sistem Informasi');
    expect(row['alamat'], contains('**'));
    expect(row['nomor_hp'], contains('*'));
  });

  test(
    'presentation helpers preserve default data and technical mutation IDs',
    () async {
      final demo = DemoSession(
        role: DemoRole.lecturer,
        scenario: DemoScenario.populated,
      );
      final localSession = local(DemoRole.lecturer);
      final record = <String, dynamic>{
        'id': 'DEMO-DOC-01',
        'document_id': 'DEMO-DOC-01',
        'title': 'Surat demo untuk diproses',
        'K_JAWABAN': 'DEMO-A1',
      };
      expect(
        demo.presentText('Surat demo untuk diproses'),
        'Surat demo untuk diproses',
      );
      expect(demo.presentRecord(record), same(record));
      expect(demo.profile['NAMA'], 'Demo Dosen');
      expect(demo.profile['STATUS'], 'Aktif (sintetis)');
      final defaultAccount = DemoAccount(
        DemoSession(
          role: DemoRole.student,
          scenario: DemoScenario.populated,
          delay: Duration.zero,
        ),
      );
      final defaultProfile =
          (await defaultAccount.request('profile'))['mhs'] as Map;
      expect((defaultProfile['data'] as List).single['NIM'], 'DEMO-MHS-001');
      final presented = localSession.presentRecord(record);
      expect(presented['id'], 'DEMO-DOC-01');
      expect(presented['document_id'], 'DEMO-DOC-01');
      expect(presented['title'], 'Permohonan pemutakhiran data akademik');
      expect(presented['K_JAWABAN'], 'DEMO-A1');
      expect(
        localSession.presentText('unmapped demo string'),
        'unmapped string',
      );
    },
  );
}
