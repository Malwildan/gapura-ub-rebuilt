import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/academic_term.dart';

/// The labels and request fields are evidenced in the APK; layout is rebuilt.
class AcademicPeriodPicker extends StatefulWidget {
  const AcademicPeriodPicker({
    super.key,
    required this.period,
    required this.onChanged,
    this.currentYear,
    this.currentOdd,
    this.allTermsByDefault = false,
    this.enabled = true,
  });

  final AcademicTerm period;
  final ValueChanged<AcademicTerm> onChanged;
  final String? currentYear;
  final bool? currentOdd;
  final bool allTermsByDefault;
  final bool enabled;

  @override
  State<AcademicPeriodPicker> createState() => _AcademicPeriodPickerState();
}

class _AcademicPeriodPickerState extends State<AcademicPeriodPicker> {
  final _form = GlobalKey<FormState>();
  late final _year = TextEditingController(
    text: widget.period.year ?? widget.currentYear ?? '',
  );
  late bool _explicit = widget.period.isExplicit;
  late bool _odd = widget.period.odd ?? widget.currentOdd ?? true;
  late bool _short = widget.period.short;

  @override
  void didUpdateWidget(covariant AcademicPeriodPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_year.text.isEmpty && widget.currentYear != null) {
      _year.text = widget.currentYear!;
    }
    if (!_explicit && widget.currentOdd != null) {
      _odd = widget.currentOdd!;
    }
  }

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  void _apply() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final term = AcademicTerm.fromParameters({
      if (_explicit) 'year': _year.text.trim(),
      if (_explicit) 'odd': _odd,
      'short': _short,
    });
    FocusScope.of(context).unfocus();
    widget.onChanged(term);
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<bool>(
          key: const ValueKey('period-mode'),
          initialValue: _explicit,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Semester'),
          items: [
            DropdownMenuItem(
              value: false,
              child: Text(
                widget.allTermsByDefault
                    ? 'Semua semester'
                    : 'Semester berjalan',
              ),
            ),
            const DropdownMenuItem(
              value: true,
              child: Text('Pilih tahun dan semester'),
            ),
          ],
          onChanged: !widget.enabled
              ? null
              : (v) => setState(() => _explicit = v!),
        ),
        if (_explicit) ...[
          const SizedBox(height: 14),
          TextFormField(
            key: const ValueKey('period-year'),
            controller: _year,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 4,
            decoration: const InputDecoration(
              labelText: 'Tahun',
              counterText: '',
            ),
            validator: (text) {
              final year = int.tryParse(text ?? '');
              if (text?.length != 4 ||
                  year == null ||
                  year < 1900 ||
                  year > 2200) {
                return 'Masukkan tahun akademik dengan empat angka.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<bool>(
            key: const ValueKey('period-odd'),
            initialValue: _odd,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Semester'),
            items: const [
              DropdownMenuItem(value: true, child: Text('Semester Ganjil')),
              DropdownMenuItem(value: false, child: Text('Semester Genap')),
            ],
            onChanged: !widget.enabled
                ? null
                : (v) => setState(() => _odd = v!),
          ),
        ],
        const SizedBox(height: 14),
        DropdownButtonFormField<bool>(
          key: const ValueKey('period-short'),
          initialValue: _short,
          decoration: const InputDecoration(labelText: 'Jenis semester:'),
          items: const [
            DropdownMenuItem(value: false, child: Text('Reguler')),
            DropdownMenuItem(value: true, child: Text('Pendek')),
          ],
          onChanged: !widget.enabled
              ? null
              : (v) => setState(() => _short = v!),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const ValueKey('period-apply'),
            onPressed: widget.enabled ? _apply : null,
            icon: const Icon(Icons.filter_alt_outlined, size: 18),
            label: const Text('Terapkan'),
          ),
        ),
      ],
    ),
  );
}
