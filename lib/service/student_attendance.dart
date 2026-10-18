import '../model/student_attendance.dart';

typedef AttendanceRequest =
    Future<Map<String, dynamic>> Function(
      String action,
      Map<String, dynamic> parameters,
    );
typedef AttendanceGet =
    Future<Map<String, dynamic>> Function(
      String path,
      Map<String, String>? query,
    );

// Internal transport operation. Never exposed as a generic URL/GET action.
Future<Map<String, dynamic>> submitStudentAttendance({
  required Map<String, dynamic> parameters,
  required AttendanceGet read,
  required Future<Map<String, dynamic>> Function() profile,
  required AttendanceGet write,
}) async {
  validateAttendanceChoice(parameters);
  if (surveyGate(await read('/mahasiswa/index/cekStatusSurveyHarian/', null)) !=
      SurveyGate.complete) {
    throw StateError(
      'Survey kesehatan belum terverifikasi. Muat ulang status.',
    );
  }
  final user = await profile();
  String field(String key) {
    final v = user[key];
    if ((v is! String && v is! num) || '$v'.trim().isEmpty) {
      throw StateError('Profil mahasiswa belum lengkap.');
    }
    return '$v';
  }

  final faculty = field('K_FAKULTAS'), branch = field('K_CABANG');
  final available = attendanceRows(
    await read('/mahasiswa/getDataMateriByMhs/', {
      'is_aktif': '1',
      'k_fakultas': faculty,
      'k_cabang': branch,
    }),
    'output',
  );
  final matches = available.where(
    (row) => row['K_MATERI_AJAR']?.toString() == parameters['meeting'],
  );
  if (matches.length != 1 || matches.single['K_ABSENSI'] != '') {
    throw StateError(
      'Pertemuan tidak tersedia untuk presensi. Muat ulang daftar.',
    );
  }
  // Recheck after context reads too; no stale client completion flag is used.
  if (surveyGate(await read('/mahasiswa/index/cekStatusSurveyHarian/', null)) !=
      SurveyGate.complete) {
    throw StateError(
      'Survey kesehatan belum terverifikasi. Muat ulang status.',
    );
  }
  try {
    return await write('/mahasiswa/index/insupdPresensiMhs/', {
      'k_materi': matches.single['K_MATERI_AJAR'].toString(),
      'k_absensi': parameters['status'] as String,
      'keterangan': '',
      'k_fakultas': faculty,
      'k_cabang': branch,
      'is_daring': parameters['mode'] as String,
      'catatan': parameters['status'] == 'H' ? '' : 'catatan',
    });
  } catch (_) {
    throw StateError(
      'Hasil pengiriman presensi belum diketahui. Muat ulang status dan daftar sebelum memilih kembali.',
    );
  }
}
