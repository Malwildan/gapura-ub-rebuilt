import 'dart:convert';
import 'dart:typed_data';

import '../model/records.dart';

/// A local sample document, never a representation of an actual tax record.
class DemoTaxDocument {
  DemoTaxDocument(Record row) {
    final candidate = row['year'];
    if (row['synthetic'] != true ||
        candidate is! int ||
        candidate < 1900 ||
        candidate > 9999 ||
        row['id'] != 'DEMO-TAX-$candidate') {
      throw const FormatException('Dokumen demo tidak valid.');
    }
    year = candidate;
  }
  late final int year;
  String get filename => 'DEMO-Bukti-Potong-$year.pdf';
  List<String> get lines => [
    'DEMO - DATA SINTETIS',
    'Contoh Bukti Pemotongan PPh Pasal 21',
    'Tahun: $year',
    'Nama: Demo Tendik',
    'Identitas: DEMO-PEGAWAI-001',
    'Bruto: Rp 5.000.000',
    'Pajak: Rp 100.000',
    'Bukan dokumen perpajakan yang sah.',
  ];

  Uint8List get bytes {
    final content =
        'BT /F1 14 Tf 50 790 Td 24 TL\n${lines.map((line) => '(${line.replaceAll('\\', '\\\\').replaceAll('(', '\\(').replaceAll(')', '\\)')}) Tj T*').join('\n')}\nET';
    final objects = [
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
      '<< /Length ${ascii.encode(content).length} >>\nstream\n$content\nendstream',
    ];
    final output = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(ascii.encode(output.toString()).length);
      output.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
    }
    final xref = ascii.encode(output.toString()).length;
    output.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (final offset in offsets.skip(1)) {
      output.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    output.write(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
    );
    return Uint8List.fromList(ascii.encode(output.toString()));
  }
}
