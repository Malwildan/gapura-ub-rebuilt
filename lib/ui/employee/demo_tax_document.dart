import 'package:flutter/material.dart';
import 'employee_app_bar.dart';
import '../../demo/tax_document.dart';
import '../../service/demo_document_export.dart';

class DemoTaxDocumentScreen extends StatefulWidget {
  const DemoTaxDocumentScreen({
    super.key,
    required this.document,
    this.localAccount = false,
  });
  final DemoTaxDocument document;
  final bool localAccount;
  @override
  State<DemoTaxDocumentScreen> createState() => _DemoTaxDocumentScreenState();
}

class _DemoTaxDocumentScreenState extends State<DemoTaxDocumentScreen> {
  bool saving = false;
  String? error;

  Future<void> save() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await saveDemoDocument(widget.document.bytes, widget.document.filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.localAccount
                  ? 'PDF disimpan di perangkat ini.'
                  : 'PDF demo dikirim ke penyimpanan.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e.toString().replaceFirst(RegExp(r'^[\w ]+: '), ''),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: EmployeeAppBar(
      title: const Text('Surat Bukti Pemotongan PPh Pasal 21'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.localAccount
              ? 'Pratinjau dokumen'
              : 'Pratinjau dokumen sintetis',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              widget.document.lines.join('\n\n'),
              style: const TextStyle(color: Colors.black, height: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: Text(widget.localAccount ? 'UNDUH PDF' : 'UNDUH PDF DEMO'),
        ),
      ],
    ),
  );
}
