import 'dart:convert';
import '../model/student_attendance.dart';
import 'student_attendance.dart';

const surveyUnknown =
    'Hasil pengiriman survey belum diketahui. Muat ulang status sebelum mengirim kembali.';

// One guard across bridge instances and auth contexts. Login/logout never reset it.
class SurveySubmissionGuard {
  bool inFlight = false, unknown = false;
  void begin(Map<String, dynamic> parameters) {
    validateSurveySubmission(parameters);
    if (inFlight || unknown) throw StateError(surveyUnknown);
    inFlight = true;
  }

  void statusRead(Map<String, dynamic> body) {
    if (!inFlight && surveyGate(body) != SurveyGate.unknown) unknown = false;
  }
}

final surveySubmissionGuard = SurveySubmissionGuard();

String surveyField(Object? value, {bool empty = true}) {
  // Compatibility limit: backend delimiter escaping is unproven. Never invent
  // SQL/backslash escaping. URI encoding alone cannot escape tuple delimiters.
  if (value is! String ||
      (!empty && value.trim().isEmpty) ||
      RegExp(r'["\\\x00-\x1f\x7f]').hasMatch(value)) {
    throw StateError(
      'Survey memuat karakter yang belum didukung. Gunakan aplikasi resmi.',
    );
  }
  return value;
}

List<Map<String, dynamic>> surveySnapshot(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) throw StateError('Pertanyaan survey belum tersedia.');
  final ids = <String>{};
  return rows.map((q) {
    final id = surveyField(q['K_PERTANYAAN'], empty: false);
    if (!ids.add(id)) throw StateError('Pertanyaan survey tidak valid.');
    final wrapper = q['JAWABAN'];
    final answers = wrapper is Map ? wrapper['JAWABAN_LIST'] : null;
    if (answers is! List || answers.isEmpty) {
      throw StateError('Pilihan survey tidak valid.');
    }
    final answerIds = <String>{};
    return <String, dynamic>{
      for (final key in [
        'K_PERTANYAAN',
        'PERTANYAAN',
        'K_PERTANYAAN_SYARAT',
        'JAWABAN_SYARAT',
        'K_JAWABAN_SYARAT',
      ])
        key: key == 'K_PERTANYAAN' ? id : (q[key] ?? ''),
      'answers': answers.map((a) {
        if (a is! Map) throw StateError('Pilihan survey tidak valid.');
        final aid = surveyField(a['K_JAWABAN'], empty: false);
        if (!answerIds.add(aid)) {
          throw StateError('Pilihan survey tidak valid.');
        }
        return {
          for (final key in [
            'K_JAWABAN',
            'JAWABAN',
            'IS_KETERANGAN',
            'REDIRECT_LINK',
          ])
            key: a[key] ?? '',
        };
      }).toList(),
    };
  }).toList();
}

void validateSurveySubmission(Map<String, dynamic> p) {
  if (p.length != 3 ||
      p['confirmed'] != true ||
      p['questions'] is! List ||
      p['answers'] is! List) {
    throw StateError('Pilihan survey tidak valid.');
  }
  final questions = p['questions'] as List, answers = p['answers'] as List;
  if (questions.isEmpty || answers.length != questions.length) {
    throw StateError('Harap mengisi semua pertanyaan');
  }
  final ids = <String>{};
  for (var i = 0; i < questions.length; i++) {
    final q = questions[i], a = answers[i];
    if (q is! Map || a is! Map || a.length != 3 || q['answers'] is! List) {
      throw StateError('Pilihan survey tidak valid.');
    }
    const questionKeys = [
      'K_PERTANYAAN',
      'PERTANYAAN',
      'K_PERTANYAAN_SYARAT',
      'JAWABAN_SYARAT',
      'K_JAWABAN_SYARAT',
      'answers',
    ];
    const answerKeys = [
      'K_JAWABAN',
      'JAWABAN',
      'IS_KETERANGAN',
      'REDIRECT_LINK',
    ];
    if (q.length != questionKeys.length ||
        questionKeys.where((k) => k != 'answers').any((k) => q[k] is! String)) {
      throw StateError('Pertanyaan survey tidak valid.');
    }
    final optionIds = <String>{};
    for (final option in q['answers'] as List) {
      if (option is! Map ||
          option.length != answerKeys.length ||
          answerKeys.any((k) => option[k] is! String) ||
          !optionIds.add(surveyField(option['K_JAWABAN'], empty: false))) {
        throw StateError('Pilihan survey tidak valid.');
      }
    }
    final id = surveyField(q['K_PERTANYAAN'], empty: false);
    surveyField(q['PERTANYAAN']);
    if (!ids.add(id) || a['question'] != id) {
      throw StateError('Pilihan survey tidak valid.');
    }
    final answer = surveyField(a['answer'], empty: false);
    surveyField(a['explanation']);
    if ((q['answers'] as List)
            .where((v) => v is Map && v['K_JAWABAN'] == answer)
            .length !=
        1) {
      throw StateError('Harap mengisi semua pertanyaan');
    }
  }
}

String? surveySaveMessage(Map<String, dynamic> body) {
  if (body['status'] is! String || body['err_msg'] is! String) return null;
  try {
    final rows = attendanceRows(body, 'output');
    if (rows.isEmpty ||
        rows.any(
          (r) => [
            'ERRSTATE',
            'MESSAGE',
            'ELAPSED_TIME',
          ].any((k) => r[k] is! String),
        )) {
      return null;
    }
    return rows.first['MESSAGE'] as String;
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>> submitHealthSurvey({
  required Map<String, dynamic> parameters,
  required AttendanceGet read,
  required AttendanceGet write,
}) async {
  validateSurveySubmission(parameters);
  final gate = surveyGate(
    await read('/mahasiswa/index/cekStatusSurveyHarian/', null),
  );
  if (gate != SurveyGate.pending) {
    throw StateError('Muat ulang status survey sebelum mengirim.');
  }
  final body = await read('/mahasiswa/index/getPertanyaanSurvey/', null);
  if (body['status'] != 'true') {
    throw StateError('Pertanyaan survey belum tersedia.');
  }
  final rows = attendanceRows(body, 'output');
  final snapshot = surveySnapshot(rows);
  if (jsonEncode(snapshot) != jsonEncode(parameters['questions'])) {
    throw StateError('Pertanyaan survey berubah. Muat ulang dan isi kembali.');
  }
  validateSurveySubmission(parameters);
  final selected = parameters['answers'] as List;
  final tuples = <String>[];
  for (var i = 0; i < rows.length; i++) {
    final q = rows[i], a = selected[i] as Map;
    // Membership was checked against the snapshot, now equal to fresh server data.
    final fields = [
      q['K_PERTANYAAN'],
      q['PERTANYAAN'],
      a['answer'],
      a['explanation'],
    ].map((v) => surveyField(v));
    tuples.add('("${fields.join('", "')}")');
  }
  try {
    final result = await write('/mahasiswa/index/insSurveyKesehatanBulk/', {
      'data_all': tuples.join(','),
    });
    if (surveySaveMessage(result) == null) throw const FormatException();
    return result;
  } catch (_) {
    surveySubmissionGuard.unknown = true;
    throw StateError(surveyUnknown);
  }
}
