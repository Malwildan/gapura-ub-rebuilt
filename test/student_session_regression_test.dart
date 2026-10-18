import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gapura_ub/model/academic_term.dart';
import 'package:gapura_ub/ui/home.dart';
import 'package:gapura_ub/widget/student_attendance.dart';

import 'widget_test.dart'
    show FixtureAccount, FixturePublic, FixtureAnnouncements;
import 'student_attendance_test.dart' show gateBody, meetingBody;

class SessionAccount extends FixtureAccount {
  String nim = 'SYNTHETIC-A';
  final held = <String>{};
  final pending = <String, List<Completer<Map<String, dynamic>>>>{};
  int statusReads = 0;

  @override
  Future<Map<String, dynamic>> request(
    String action, {
    Map<String, dynamic> parameters = const {},
  }) {
    if (held.contains(action)) {
      requests.add((action: action, parameters: Map.of(parameters)));
      final result = Completer<Map<String, dynamic>>();
      pending.putIfAbsent(action, () => []).add(result);
      return result.future;
    }
    if (action == 'profile') {
      return Future.value({
        'mhs': {
          'data': [
            {'NIM': nim, 'NAMA': 'Synthetic $nim'},
          ],
        },
      });
    }
    if (action == 'surveyStatus') {
      statusReads++;
      return Future.value(gateBody('1'));
    }
    if (action == 'attendanceMeetings') return Future.value(meetingBody());
    return super.request(action, parameters: parameters);
  }
}

class SessionPublic extends FixturePublic {
  @override
  Future<List<Map<String, dynamic>>> achievements() async => [];
}

Future<dynamic> showHome(WidgetTester tester, SessionAccount account) async {
  final api = SessionPublic();
  addTearDown(api.close);
  await tester.pumpWidget(
    MaterialApp(
      home: GapuraHome(
        onTheme: (_) {},
        service: api,
        account: account,
        announcements: FixtureAnnouncements(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state(find.byType(GapuraHome));
}

Map<String, dynamic> rows(String key, String marker) => {
  key: {
    'data': [
      {'NAMA': marker, 'MATA_KULIAH': marker},
    ],
  },
};

void main() {
  testWidgets('changed account clears student state and rejects pending A-B-A results', (
    tester,
  ) async {
    final account = SessionAccount();
    final dynamic home = await showHome(tester, account);
    home.update(() {
      home.cache['grades'] = [<String, dynamic>{'NAMA': 'Old grade'}];
      home.cache['latest_news'] = [<String, dynamic>{'title': 'Public retained'}];
      home.errors['finance'] = 'Old error';
      home.summariesByPage['grades'] = [<String, dynamic>{'IPK_LULUS': '4'}];
      home.periods['grades'] = const AcademicTerm(year: '2020', odd: true);
      home.selectedCourse = home.regularCourses.first;
      home.scheduleShort = true;
      home.active = false;
    });
    account.held.add('materials');
    final Future<void> old = home.loadStudent('materials');
    account.nim = 'SYNTHETIC-B';
    await home.connect();
    expect(home.cache.containsKey('grades'), isFalse);
    expect(home.summariesByPage, isEmpty);
    expect(home.periods, isEmpty);
    expect(home.selectedCourse, isNull);
    expect(home.scheduleShort, isFalse);
    expect(home.active, isTrue);
    expect(home.errors.containsKey('finance'), isFalse);
    expect(home.loading.contains('materials'), isFalse);
    expect(home.cache['latest_news'].single['title'], 'Public retained');

    // Reusing a NIM must not make its old request current again.
    account.nim = 'SYNTHETIC-A';
    await home.connect();
    final Future<void> fresh = home.loadStudent('materials');
    account.pending['materials']![0].complete(rows('output', 'Stale A'));
    await old;
    expect(home.cache.containsKey('materials'), isFalse);
    expect(home.loading.contains('materials'), isTrue);
    account.pending['materials']![1].complete(rows('output', 'Fresh A'));
    await fresh;
    expect(home.cache['materials'].single['NAMA'], 'Fresh A');
    expect(home.loading.contains('materials'), isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('disconnect invalidates reads and reconnect before bridge completes', (
    tester,
  ) async {
    final account = SessionAccount();
    final dynamic home = await showHome(tester, account);
    account.held.addAll(['profile', 'materials', 'disconnect']);
    final Future<void> read = home.loadStudent('materials');
    final Future<void> reconnect = home.connect();
    final Future<void> disconnect = home.disconnect();
    expect(home.profile, isNull);
    expect(home.loading.contains('materials'), isFalse);
    account.pending['profile']!.single.complete({
      'mhs': {
        'data': [
          {'NIM': 'SYNTHETIC-A', 'NAMA': 'Late profile'},
        ],
      },
    });
    account.pending['materials']!.single.complete(rows('output', 'Late read'));
    await reconnect;
    await read;
    expect(home.profile, isNull);
    expect(home.cache.containsKey('materials'), isFalse);
    account.pending['disconnect']!.single.complete({});
    await disconnect;
    await tester.pumpAndSettle();
    expect(home.profile, isNull);
    expect(home.connecting, isFalse);
  });

  testWidgets('course card starts fresh history while previous course is loading', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final account = SessionAccount();
    final dynamic home = await showHome(tester, account);
    account.held.add('history');
    home.go('schedule');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Riwayat Pertemuan').first);
    await tester.tap(find.text('Riwayat Pertemuan').first);
    await tester.pump();
    home.back();
    await tester.pump();
    await tester.ensureVisible(find.text('Riwayat Pertemuan').last);
    await tester.tap(find.text('Riwayat Pertemuan').last);
    await tester.pump();
    expect(account.pending['history'], hasLength(2));
    final historyRequests = account.requests.where((r) => r.action == 'history');
    expect(historyRequests.last.parameters['course']['K_MK'], 'QA2');
    account.pending['history']![1].complete(rows('output', 'New course history'));
    await tester.pump();
    account.pending['history']![0].complete(rows('output', 'Stale course history'));
    await tester.pumpAndSettle();
    expect(find.text('New course history'), findsOneWidget);
    expect(find.text('Stale course history'), findsNothing);
  });

  testWidgets('attendance toolbar and pull refresh reload current guarded state', (
    tester,
  ) async {
    final account = SessionAccount();
    final dynamic home = await showHome(tester, account);
    home.go('attendance');
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(StudentAttendance));
    final reads = account.statusReads;
    await tester.tap(find.byTooltip('Muat ulang'));
    await tester.pumpAndSettle();
    expect(account.statusReads, reads + 1);
    expect(tester.state(find.byType(StudentAttendance)), same(state));
    final refresh = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    await refresh.onRefresh();
    await tester.pumpAndSettle();
    expect(account.statusReads, reads + 2);

    // A toolbar refresh cannot reset a pending confirmed attendance write.
    account.held.add('attendanceSubmit');
    await tester.ensureVisible(find.text('HADIR'));
    await tester.tap(find.text('HADIR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luring'));
    await tester.pump();
    await tester.tap(find.byTooltip('Muat ulang'));
    await tester.pump();
    expect(account.statusReads, reads + 2);
    expect(tester.state(find.byType(StudentAttendance)), same(state));
    account.pending['attendanceSubmit']!.single.complete({
      'mhs': {
        'data': [
          {'ERRSTATE': '00000'},
        ],
      },
    });
    await tester.pumpAndSettle();
    expect(account.statusReads, reads + 3);
    expect(find.textContaining('telah tersimpan'), findsOneWidget);
  });
}
