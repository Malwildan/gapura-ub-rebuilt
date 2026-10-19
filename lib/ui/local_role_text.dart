import '../demo/demo_session.dart';

String localRoleText(DemoSession? session, String text) {
  if (session?.localAccount != true) return text;
  return text
      .replaceAll(
        'Simulasi demo lokal. Tidak ada verifikasi UB atau penandatanganan elektronik.',
        'Konfirmasi tindakan.',
      )
      .replaceAll(
        'Pratinjau sintetis lokal. Tidak ada berkas yang diunduh atau dibuka.',
        'Pratinjau dokumen.',
      )
      .replaceAll('Jawaban tersimpan di demo lokal.', 'Jawaban disimpan.')
      .replaceAll('Presensi tersimpan di demo lokal.', 'Presensi disimpan.')
      .replaceAll(
        'Mode kerja diperbarui di demo lokal.',
        'Mode kerja diperbarui.',
      )
      .replaceAll(
        'Perubahan demo gagal disimpan: ',
        'Perubahan tidak dapat disimpan: ',
      )
      .replaceAll(
        'Perubahan demo gagal disimpan. Silakan coba lagi.',
        'Perubahan tidak dapat disimpan. Silakan coba lagi.',
      )
      .replaceAll(
        'Pilihan status disederhanakan untuk data demo.',
        'Pilihan status yang tersedia untuk data ini.',
      )
      .replaceAll(
        'Demo sintetis saja. Tidak disimpan atau digunakan untuk tanda tangan.',
        'Konfirmasi tindakan.',
      )
      .replaceAll(
        'Disimpan di demo lokal. Tidak ada layanan UB yang digunakan.',
        'Perubahan disimpan.',
      )
      .replaceAll(
        'Dokumen pajak sintetis · demo lokal.',
        'Dokumen pajak diproses.',
      )
      .replaceAll(' demo lokal', '')
      .replaceAll(' (demo)', '')
      .replaceAll(' demo', '')
      .replaceAll(' sintetis', '')
      .replaceAll(' disimulasikan', '')
      .replaceAllMapped(RegExp(r'\s+([.,:;!?])'), (match) => match[1]!)
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}
