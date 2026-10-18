import 'package:flutter/material.dart';

class Feature {
  const Feature(
    this.id,
    this.label,
    this.asset,
    this.icon, {
    this.originalRoute,
  });
  final String id, label, asset;
  final IconData icon;
  // Preserve recovered route names when a local academic route already uses it.
  final String? originalRoute;
}

const studentFeatures = [
  Feature(
    'schedule',
    'Jadwal & Presensi Kuliah',
    'img/-_mhs-jadwal.png',
    Icons.calendar_month,
  ),
  Feature(
    'krs',
    'Kartu Rencana Studi',
    'img/-_mhs-krs.png',
    Icons.assignment_outlined,
  ),
  Feature(
    'grades',
    'Kartu Hasil Studi',
    'img/-_mhs-khs.png',
    Icons.school_outlined,
  ),
  Feature(
    'transcript',
    'Rekap Hasil Studi',
    'icon/ub_khs-rekap.png',
    Icons.stacked_bar_chart,
  ),
  Feature(
    'finance',
    'Biaya Kuliah',
    'img/-_mhs-biaya.png',
    Icons.payments_outlined,
  ),
  Feature(
    'announcements',
    'Pengumuman',
    'img/-_news.png',
    Icons.campaign_outlined,
  ),
  Feature(
    'materials',
    'Materi Kuliah',
    'icon/ub_absen-kuliah.png',
    Icons.fact_check_outlined,
  ),
  Feature('history', 'Riwayat Kuliah', 'icon/ub_khs-rekap.png', Icons.history),
];
const publicFeatures = [
  Feature(
    'overview',
    'Visi Misi',
    'icon/ub_visi-misi.png',
    Icons.flag_outlined,
  ),
  Feature('faculty', 'Fakultas', 'icon/ub_fakultas.png', Icons.school_outlined),
  Feature(
    'officials',
    'Pimpinan',
    'icon/ub_pimpinan.png',
    Icons.people_outline,
  ),
  Feature('facility', 'Fasilitas', 'icon/ub_fasilitas.png', Icons.apartment),
  Feature(
    'calendar',
    'Kalender Akademik',
    'icon/ub_kalendar-akademik.png',
    Icons.event_note,
  ),
  Feature(
    'statistics',
    'Statistik',
    'icon/ub_statistik.png',
    Icons.bar_chart,
    originalRoute: 'statistic',
  ),
  Feature(
    'university_history',
    'Sejarah',
    'icon/ub_sejarah.png',
    Icons.history,
    originalRoute: 'history',
  ),
  Feature('lambang', 'Lambang', 'icon/ub_lambang.png', Icons.shield_outlined),
];

// Existing public readers remain accessible without adding unproven Home tiles.
const publicReaderFeatures = [
  Feature('news', 'Berita Terkini', 'img/-_news.png', Icons.newspaper),
  Feature(
    'images',
    'Galeri Universitas',
    'img/-_ubprofile.png',
    Icons.photo_library_outlined,
  ),
];

// UserApps.init replaces FeatureListStudent with FeatureStudent (16856).
const studentMenuFeatures = [
  Feature(
    'finance',
    'Biaya Kuliah',
    'icon/ub_biaya.png',
    Icons.payments_outlined,
    originalRoute: 'tuition',
  ),
  Feature(
    'transcript',
    'Hasil Studi',
    'icon/ub_khs-rekap.png',
    Icons.stacked_bar_chart,
    originalRoute: 'rekap_hasil_studi',
  ),
  Feature(
    'grades',
    'Kartu Hasil Studi',
    'icon/ub_khs.png',
    Icons.school_outlined,
    originalRoute: 'student_khs',
  ),
  Feature(
    'krs',
    'Kartu Rencana Studi',
    'icon/ub_krs.png',
    Icons.assignment_outlined,
    originalRoute: 'student_krs',
  ),
  Feature(
    'schedule',
    'Jadwal & Presensi Kuliah',
    'icon/ub_jadwal-kuliah.png',
    Icons.calendar_month,
    originalRoute: 'jadwal_kuliah',
  ),
  Feature(
    'attendance',
    'Presensi Kelas',
    'icon/ub_absen-kuliah.png',
    Icons.fact_check_outlined,
    originalRoute: 'survey_mhs',
  ),
  Feature(
    'library',
    'Layanan Perpustakaan',
    'img/-_fakultas.png',
    Icons.local_library_outlined,
    originalRoute: 'ublibrary',
  ),
];
