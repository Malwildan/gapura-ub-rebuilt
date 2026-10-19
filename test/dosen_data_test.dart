import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/demo/demo_session.dart';
import 'package:gapura_ub/demo/dosen_data.dart';

DosenDemoData data([
  DemoRole role = DemoRole.lecturer,
  DemoScenario scenario = DemoScenario.populated,
]) => DosenDemoData(
  DemoSession(role: role, scenario: scenario, delay: Duration.zero),
);

void main() {
  test('all 44 lecturer resources are readable', () async {
    final demo = data();
    expect(DosenDemoData.resources, hasLength(44));
    for (final resource in DosenDemoData.resources) {
      expect(await demo.read(resource), isA<List>(), reason: resource);
    }
  });

  test('deep copies isolate nested fixture and saved data', () async {
    final demo = data();
    final first = await demo.read('publication_output');
    (first.single['tahun'] as List).add(2099);
    expect((await demo.read('publication_output')).single['tahun'], [
      2022,
      2023,
      2024,
    ]);

    final input = <String, dynamic>{
      'nested': {'value': 1},
    };
    final saved = await demo.save('tasks', input);
    (input['nested'] as Map)['value'] = 2;
    (saved['nested'] as Map)['value'] = 3;
    expect(
      (await demo.read(
        'tasks',
      )).singleWhere((r) => r['id'] == saved['id'])['nested'],
      {'value': 1},
    );
  });

  test('rejects non-lecturer roles and unknown resources', () async {
    await expectLater(
      data(DemoRole.staff).read('profile'),
      throwsUnsupportedError,
    );
    await expectLater(
      data(DemoRole.student).save('profile', {}),
      throwsUnsupportedError,
    );
    await expectLater(data().read('not-a-resource'), throwsArgumentError);
  });

  test(
    'empty, error, and loading scenarios follow DemoSession behavior',
    () async {
      expect(
        await data(DemoRole.lecturer, DemoScenario.empty).read('profile'),
        isEmpty,
      );
      await expectLater(
        data(DemoRole.lecturer, DemoScenario.error).read('profile'),
        throwsStateError,
      );
      await expectLater(
        data(
          DemoRole.lecturer,
          DemoScenario.loading,
        ).read('profile').timeout(const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()),
      );
    },
  );

  test('year and month filters require a matching alias or date', () async {
    final demo = data();
    expect(await demo.read('attendance_history', year: 2026), hasLength(1));
    expect(await demo.read('attendance_history', year: 2025), isEmpty);
    expect(await demo.read('attendance_history', month: 10), hasLength(1));
    expect(await demo.read('attendance_history', month: 9), isEmpty);
    expect(
      await demo.read('survey', year: 2026),
      isEmpty,
      reason: 'rows with no year/date must not pass a requested year filter',
    );
    expect(
      await demo.read('attendance_history', year: 2026, month: 9),
      isEmpty,
    );
  });

  test('save replaces or inserts locally and remove deletes by ID', () async {
    final demo = data();
    final original = (await demo.read('tasks')).single;
    await demo.save('tasks', {...original, 'TUGAS': 'Tugas diperbarui'});
    expect((await demo.read('tasks')).single['TUGAS'], 'Tugas diperbarui');
    final inserted = await demo.save('tasks', {'TUGAS': 'Tugas baru'});
    expect(inserted['id'], startsWith('DEMO-tasks-'));
    await demo.remove('tasks', inserted['id'].toString());
    expect(await demo.read('tasks'), hasLength(1));
  });

  test(
    'recovered category, lesson, document, calendar, and survey links cohere',
    () async {
      final demo = data();
      const historyCategories = [
        'Keaktifan',
        'Keluarga',
        'Penghargaan',
        'Kepangkatan',
        'Perubahan Gaji',
        'Jab. Fungsional',
        'Jab. Struktural',
        'Jab. NonStruktural',
        'Homebase',
        'Serdos',
        'Pendidikan',
        'Diklat',
        'Sertifikat',
      ];
      for (final category in historyCategories) {
        expect(
          await demo.read('personnel_history', category: category),
          hasLength(1),
        );
      }

      final course = (await demo.read('schedule')).single;
      final lesson = (await demo.read('teaching_drafts', item: course)).single;
      final roster = await demo.read('student_attendance', item: lesson);
      expect(roster, hasLength(1));
      expect(roster.single['class_id'], course['id']);

      final queue = (await demo.read('pendapa_incoming')).single;
      final detail = (await demo.read('document_detail', item: queue)).single;
      expect(detail['title'], 'Surat demo untuk diproses');
      for (final field in [
        'notugas',
        'tugas',
        'tglsurat',
        'unit',
        'deskripsi',
      ]) {
        expect(detail[field], isNotEmpty, reason: field);
      }
      expect(queue['document_id'], detail['id']);
      final calendarEntry = (await demo.read('pendapa_calendar')).single;
      final taskEntry = (await demo.read('pendapa_tasks')).single;
      expect(calendarEntry['document_id'], detail['id']);
      expect(taskEntry['document_id'], detail['id']);
      expect(
        (await demo.read('document_detail', item: calendarEntry)).single['id'],
        detail['id'],
      );
      expect(
        (await demo.read('document_detail', item: taskEntry)).single['id'],
        detail['id'],
      );

      final account = (await demo.read('calendars')).single;
      expect(account['calendar_id'], isNotEmpty);
      expect(account['name'], isNotEmpty);
      expect(account.containsKey('NAMA_KEGIATAN'), isFalse);
      expect((await demo.read('survey')).single['judul_survey'], isNotEmpty);
      expect(
        (await demo.read('survey_components')).single['komponen_survey'],
        isNotEmpty,
      );
    },
  );

  test(
    'document removal clears rows linked by canonical demo document ID',
    () async {
      final demo = data();
      await demo.remove('document_detail', 'DEMO-DOC-01');
      expect(await demo.read('document_timeline'), isEmpty);
      expect(await demo.read('document_attachments'), isEmpty);
      expect(await demo.read('pendapa_incoming'), isEmpty);
    },
  );
}
