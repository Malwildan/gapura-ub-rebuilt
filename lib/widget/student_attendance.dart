import '../service/survey_submission.dart';
import 'package:flutter/material.dart';
import '../model/student_attendance.dart';
import '../service/student_attendance.dart';

class StudentAttendance extends StatefulWidget {
  const StudentAttendance({super.key, required this.request});
  final AttendanceRequest request;
  @override
  State<StudentAttendance> createState() => StudentAttendanceState();
}

class StudentAttendanceState extends State<StudentAttendance> {
  SurveyGate gate = SurveyGate.unknown;
  List<Map<String, dynamic>> meetings = [], questions = [];
  final Map<int, int> answers = {};
  final List<TextEditingController> explanations = [];
  bool busy = false, sending = false, confirming = false, ongoing = true;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    generation++;
    for (final controller in explanations) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> reload() async {
    if (sending || confirming || busy) return;
    final version = ++generation;
    setState(() {
      busy = true;
      gate = SurveyGate.unknown;
      error = null;
      meetings = [];
      questions = [];
      answers.clear();
      for (final controller in explanations) {
        controller.dispose();
      }
      explanations.clear();
    });
    bool current() => mounted && generation == version;
    try {
      final next = surveyGate(await widget.request('surveyStatus', {}));
      if (next == SurveyGate.unknown) {
        throw StateError('Status survey kesehatan belum dapat diverifikasi.');
      }
      List<Map<String, dynamic>> rows;
      if (next == SurveyGate.complete) {
        rows = attendanceRows(
          await widget.request('attendanceMeetings', {'active': ongoing}),
          'output',
        );
      } else {
        final body = await widget.request('surveyQuestions', {});
        if (body['status'] != 'true') {
          throw StateError('Pertanyaan survey belum tersedia.');
        }
        rows = attendanceRows(body, 'output');
      }
      if (current()) {
        setState(() {
          gate = next;
          if (next == SurveyGate.complete) {
            meetings = rows;
          } else {
            questions = rows;
            explanations.addAll(rows.map((_) => TextEditingController()));
          }
        });
      }
    } catch (e) {
      if (current()) {
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (current()) setState(() => busy = false);
    }
  }

  Future<void> confirm(Map<String, dynamic> meeting, String status) async {
    if (sending || confirming || busy || meeting['K_ABSENSI'] != '') return;
    setState(() => confirming = true);
    final mode = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sistem akan mencatat kehadiran Anda pada mata kuliah ${meeting['MATA_KULIAH'] ?? ''} dengan status : \n$status\n',
              ),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(sheet),
                    child: const Text('Batal'),
                  ),
                  if (status == 'H') ...[
                    FilledButton(
                      onPressed: () => Navigator.pop(sheet, '0'),
                      child: const Text('Luring'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheet, '1'),
                      child: const Text('Daring'),
                    ),
                  ] else
                    FilledButton(
                      onPressed: () => Navigator.pop(sheet, '0'),
                      child: const Text('Lanjutkan'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => confirming = false);
    if (mode == null || sending) return;
    setState(() {
      sending = true;
      error = null;
    });
    var saved = false;
    try {
      final body = await widget.request('attendanceSubmit', {
        'confirmed': true,
        'meeting': meeting['K_MATERI_AJAR']?.toString(),
        'status': status,
        'mode': mode,
      });
      final code = attendanceResult(body);
      if (code != '00000') {
        throw StateError(
          code == null
              ? 'Hasil pengiriman presensi belum diketahui. Muat ulang status dan daftar sebelum memilih kembali.'
              : '[$code] Presensi Anda pada mata kuliah ${meeting['MATA_KULIAH']} gagal disimpan! Silakan login ulang atau coba beberapa saat lagi.',
        );
      }
      saved = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Presensi Anda pada mata kuliah ${meeting['MATA_KULIAH']} telah tersimpan dengan status : $status',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString().replaceFirst('Bad state: ', '');
          gate = SurveyGate.unknown;
          meetings = [];
        });
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
    if (saved && mounted) await reload();
  }

  Future<void> submitSurvey() async {
    if (busy || sending || confirming || gate != SurveyGate.pending) return;
    Map<String, dynamic> parameters;
    try {
      parameters = {
        'confirmed': true,
        'questions': surveySnapshot(questions),
        'answers': [
          for (var i = 0; i < questions.length; i++)
            {
              'question': questions[i]['K_PERTANYAAN'],
              'answer': answers[i] == null
                  ? null
                  : options(questions[i])[answers[i]!]['K_JAWABAN'],
              'explanation': explanations[i].text,
            },
        ],
      };
      validateSurveySubmission(parameters);
    } catch (_) {
      setState(
        () => error =
            'Harap mengisi semua pertanyaan. Karakter kutip ganda, garis miring terbalik, dan kontrol belum didukung.',
      );
      return;
    }
    setState(() => confirming = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Kirim Jawaban'),
        content: const Text(
          'Kirim jawaban survey kesehatan yang Anda pilih ke UB?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => confirming = false);
    if (confirmed != true) return;
    setState(() {
      sending = true;
      error = null;
    });
    var responded = false;
    try {
      final body = await widget.request('surveySubmit', parameters);
      final message = surveySaveMessage(body);
      if (message == null) {
        throw StateError(surveyUnknown);
      }
      responded = true;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      // No automatic replay or answer refill, including changed-question errors.
      if (mounted) {
        setState(() {
          error = surveyUnknown;
          gate = SurveyGate.unknown;
        });
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
    // Save response never grants entry. Only this fresh daily status can do so.
    if (responded && mounted) await reload();
  }

  String text(Object? value) => value?.toString() ?? '';
  List<Map<String, dynamic>> options(Map<String, dynamic> question) {
    final wrapper = question['JAWABAN'];
    final rows = wrapper is Map ? wrapper['JAWABAN_LIST'] : null;
    return rows is List
        ? rows
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
        : [];
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        gate == SurveyGate.complete ? 'Presensi Kelas' : 'Survey Kesehatan',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (busy || sending) const LinearProgressIndicator(),
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(error!),
        ),
      TextButton(
        onPressed: busy || sending || confirming ? null : reload,
        child: const Text('Muat ulang status'),
      ),
      if (gate == SurveyGate.pending) ...[
        const Text(
          'Silakan mengisi survey kesehatan berikut sebelum melakukan presensi.',
        ),
        for (var i = 0; i < questions.length; i++) ...[
          const SizedBox(height: 16),
          Text(
            text(questions[i]['PERTANYAAN']).replaceAll(RegExp(r'<[^>]*>'), ''),
          ),
          DropdownButton<int>(
            value: answers[i],
            hint: const Text('-'),
            isExpanded: true,
            items: [
              for (var j = 0; j < options(questions[i]).length; j++)
                DropdownMenuItem(
                  value: j,
                  child: Text(text(options(questions[i])[j]['JAWABAN'])),
                ),
            ],
            onChanged: busy || sending || confirming
                ? null
                : (answer) => setState(() {
                    if (answer != null) answers[i] = answer;
                  }),
          ),
          if (answers[i] != null &&
              options(questions[i])[answers[i]!]['IS_KETERANGAN'] == '1')
            TextField(
              key: ValueKey('explanation-$generation-$i'),
              controller: explanations[i],
              enabled: !busy && !sending && !confirming,
              decoration: const InputDecoration(
                hintText: 'Ketikkan penjelasan di sini',
              ),
            ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed:
              busy ||
                  sending ||
                  confirming ||
                  questions.isEmpty ||
                  answers.length != questions.length
              ? null
              : submitSurvey,
          child: const Text('Kirim Jawaban'),
        ),
        const Text(
          'Jawaban belum dikirim sampai Anda mengonfirmasi pengiriman.',
        ),
      ],
      if (gate == SurveyGate.complete) ...[
        DropdownButtonFormField<bool>(
          initialValue: ongoing,
          decoration: const InputDecoration(labelText: 'Jenis Presensi:'),
          items: const [
            DropdownMenuItem(value: true, child: Text('Berjalan')),
            DropdownMenuItem(value: false, child: Text('Terlewat')),
          ],
          onChanged: busy || sending || confirming
              ? null
              : (value) {
                  if (value != null) {
                    ongoing = value;
                    reload();
                  }
                },
        ),
        if (meetings.isEmpty) const Text('Tidak ada data'),
        for (final meeting in meetings)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${text(meeting['MATA_KULIAH'])} / ${text(meeting['KELAS'])}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Sub Capaian Pembelajaran : ${text(meeting['MATERI'])}'),
                  Text(
                    'Catatan :\n${text(meeting['KETERANGAN']).replaceAll('&nbsp;', '\n')}',
                  ),
                  Text(
                    'Presensi berlangsung hingga ${text(meeting['WAKTU_TUTUP']).length > 19 ? text(meeting['WAKTU_TUTUP']).substring(0, 19) : text(meeting['WAKTU_TUTUP'])}',
                  ),
                  if (meeting['K_ABSENSI'] == '')
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final choice in const {
                          'H': 'HADIR',
                          'I': 'IZIN',
                          'S': 'SAKIT',
                        }.entries)
                          OutlinedButton(
                            onPressed: busy || sending || confirming
                                ? null
                                : () => confirm(meeting, choice.key),
                            child: Text(choice.value),
                          ),
                      ],
                    )
                  else if (const ['H', 'I', 'S'].contains(meeting['K_ABSENSI']))
                    Text(
                      'Status Presensi : ${const {'H': 'HADIR', 'I': 'IZIN', 'S': 'SAKIT'}[meeting['K_ABSENSI']]}${meeting['K_ABSENSI'] == 'H' ? (meeting['IS_DARING'] == '1' ? ' (Daring)' : ' (Luring)') : ''}',
                    ),
                ],
              ),
            ),
          ),
      ],
    ],
  );
}
