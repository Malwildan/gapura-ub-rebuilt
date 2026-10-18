/// A caller-selected academic term. An absent year/odd pair means the service's
/// current/all-term behavior; dates and available years are never invented.
class AcademicTerm {
  const AcademicTerm({this.year, this.odd, this.short = false});

  factory AcademicTerm.fromParameters(Map<String, dynamic> parameters) {
    final rawYear = parameters['year'];
    final rawOdd = parameters['odd'];
    final rawShort = parameters.containsKey('short')
        ? parameters['short']
        : false;
    if ((rawYear != null && rawYear is! String) ||
        (rawOdd != null && rawOdd is! bool) ||
        rawShort is! bool) {
      throw const FormatException(invalidMessage);
    }
    final term = AcademicTerm(
      year: rawYear as String?,
      odd: rawOdd as bool?,
      short: rawShort,
    );
    term.validate();
    return term;
  }

  static const invalidMessage =
      'Pilihan semester tidak valid. Pilih tahun dan semester yang lengkap.';

  final String? year;
  final bool? odd;
  final bool short;

  bool get isExplicit => year != null && odd != null;

  void validate() {
    if ((year == null) != (odd == null)) {
      throw const FormatException(invalidMessage);
    }
    if (year != null &&
        (!RegExp(r'^[0-9]{4}$').hasMatch(year!) ||
            int.parse(year!) < 1900 ||
            int.parse(year!) > 2200)) {
      throw const FormatException(invalidMessage);
    }
  }

  /// No explicit term emits only the schedule flag, or x/x when allTerms=true.
  Map<String, String> query({bool allTerms = false}) {
    validate();
    return {
      if (isExplicit || allTerms) 'tahun': year ?? 'x',
      if (isExplicit || allTerms)
        'is_ganjil': odd == null ? 'x' : (odd! ? '1' : '0'),
      'is_pendek': short ? '1' : '0',
    };
  }

  Map<String, dynamic> toParameters() {
    validate();
    return {
      'short': short,
      if (isExplicit) 'year': year,
      if (isExplicit) 'odd': odd,
    };
  }

  String get label {
    validate();
    return '${year ?? 'Semester berjalan'}'
        '${odd == null ? '' : (odd! ? ' · Ganjil' : ' · Genap')}'
        '${short ? ' · Pendek' : ''}';
  }

  @override
  bool operator ==(Object other) =>
      other is AcademicTerm &&
      year == other.year &&
      odd == other.odd &&
      short == other.short;

  @override
  int get hashCode => Object.hash(year, odd, short);
}
