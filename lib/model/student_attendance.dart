enum SurveyGate { complete, pending, unknown }

SurveyGate surveyGate(Map<String, dynamic> body) {
  final output = body['output'];
  final rows = output is Map ? output['data'] : null;
  if (rows is! List || rows.isEmpty || rows.first is! Map) {
    return SurveyGate.unknown;
  }
  final flag = (rows.first as Map)['STAT_ISI'];
  if (flag is! String) return SurveyGate.unknown;
  return flag == '1' ? SurveyGate.complete : SurveyGate.pending;
}

List<Map<String, dynamic>> attendanceRows(
  Map<String, dynamic> body,
  String key,
) {
  final wrapper = body[key];
  final rows = wrapper is Map ? wrapper['data'] : null;
  if (rows is! List || rows.any((row) => row is! Map)) {
    throw const FormatException('Data UB belum dapat dibaca.');
  }
  return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
}

String? attendanceResult(Map<String, dynamic> body) {
  try {
    final rows = attendanceRows(body, 'mhs');
    final code = rows.first['ERRSTATE'];
    return code is String ? code : null;
  } catch (_) {
    return null;
  }
}

void validateAttendanceChoice(Map<String, dynamic> parameters) {
  if (parameters.length != 4 ||
      parameters['confirmed'] != true ||
      parameters['meeting'] is! String ||
      (parameters['meeting'] as String).trim().isEmpty ||
      !['H', 'I', 'S'].contains(parameters['status']) ||
      !['0', '1'].contains(parameters['mode']) ||
      (parameters['status'] != 'H' && parameters['mode'] != '0')) {
    throw StateError('Pilihan presensi tidak valid.');
  }
}
