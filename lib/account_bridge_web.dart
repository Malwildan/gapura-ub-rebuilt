import 'dart:convert';
import 'dart:js_interop';
import 'model/student_attendance.dart';
import 'service/survey_submission.dart';

@JS('gapuraAccountRequest')
external JSPromise<JSString> _accountRequest(
  JSString action,
  JSString parameters,
);

class AccountBridge {
  Future<Map<String, dynamic>> request(
    String action, {
    Map<String, dynamic> parameters = const {},
  }) async {
    final submit = action == 'surveySubmit';
    final recovering =
        action == 'surveyStatus' &&
        surveySubmissionGuard.unknown &&
        !surveySubmissionGuard.inFlight;
    if (submit) surveySubmissionGuard.begin(parameters);
    try {
      final checked = submit
          ? Map<String, dynamic>.from(jsonDecode(jsonEncode(parameters)) as Map)
          : parameters;
      final result = await _request(action, parameters: checked);
      if (recovering) surveySubmissionGuard.statusRead(result);
      return result;
    } catch (_) {
      if (submit) surveySubmissionGuard.unknown = true;
      if (submit && surveySubmissionGuard.unknown) {
        throw StateError(surveyUnknown);
      }
      rethrow;
    } finally {
      if (submit) surveySubmissionGuard.inFlight = false;
    }
  }

  Future<Map<String, dynamic>> _request(
    String action, {
    Map<String, dynamic> parameters = const {},
  }) async {
    if (action == 'attendanceSubmit') {
      validateAttendanceChoice(parameters);
    }
    final result = await _accountRequest(
      action.toJS,
      jsonEncode(parameters).toJS,
    ).toDart;
    final decoded = jsonDecode(result.toDart);
    if (decoded is! Map || decoded['ok'] != true) {
      throw StateError(
        decoded is Map
            ? decoded['error']?.toString() ?? 'Koneksi akun UB gagal.'
            : 'Format respons akun UB tidak dikenali.',
      );
    }
    final data = decoded['data'];
    if (data is! Map) {
      throw StateError('Format data akun UB tidak dikenali.');
    }
    return Map<String, dynamic>.from(data);
  }
}
