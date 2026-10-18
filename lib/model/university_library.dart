/// Bundled local records recovered from LIBRARY-3.3.38-EVIDENCE.json.
/// These are external navigation targets, not a library API or native forms.
class UniversityLibraryLink {
  const UniversityLibraryLink(this.title, this.url, this.colorHex);

  final String title;
  final String url;
  final String colorHex;

  Uri get uri => Uri.parse(url);
  int get colorArgb => int.parse('ff${colorHex.substring(1)}', radix: 16);
}

const universityLibraryTitle = 'Layanan Perpustakaan UB';

const universityLibraryBaseLinks = [
  UniversityLibraryLink(
    'Dashboard',
    'https://lib.ub.ac.id/dasboard-lib/',
    '#9b1411',
  ),
  UniversityLibraryLink(
    'Form Bebas Pustaka',
    'https://lib.ub.ac.id/form-bebas-pustaka/',
    '#dfbc2b',
  ),
  UniversityLibraryLink(
    'Form Serah Simpan Naskah TA',
    'https://lib.ub.ac.id/serah-terima-naskah-ta/',
    '#dfbc2b',
  ),
  UniversityLibraryLink('Repository', 'http://repository.ub.ac.id/', '#96a19b'),
  UniversityLibraryLink('Jurnal UB', 'https://jurnal.ub.ac.id/', '#96a19b'),
  UniversityLibraryLink('Digilib UB', 'https://digilib.ub.ac.id/', '#96a19b'),
  UniversityLibraryLink(
    'e-Resources UB',
    'https://lib.ub.ac.id/e-resources-ind/',
    '#96a19b',
  ),
  UniversityLibraryLink(
    'E-Library UB (Web)',
    'https://elibrary.ub.ac.id/',
    '#96a19b',
  ),
];

const universityLibraryAndroidLink = UniversityLibraryLink(
  'E-Library UB (Android)',
  'https://play.google.com/store/apps/details?id=id.kubuku.xbk2648856',
  '#96a19b',
);

const universityLibraryLinks = [
  ...universityLibraryBaseLinks,
  universityLibraryAndroidLink,
];
