/// Exact source order and destinations recovered from Gapura UB 3.3.38.
/// LatestNews is a separate home widget, not the Prasetya headline tab.
enum NewsFeed {
  official('official', 'UB Official', 'https://ub.ac.id/id/feed/'),
  prasetya(
    'prasetya',
    'Prasetya',
    'https://prasetya.ub.ac.id/category/headline/feed/',
  ),
  selma('selma', 'SELMA', 'https://selma.ub.ac.id/id/rss'),
  rsub('rsub', 'RSUB', 'https://rumahsakit.ub.ac.id/feed/'),
  rsgm('rsgm', 'RSGM', 'https://rsgm.ub.ac.id/feed/'),
  klinik('klinik', 'Klinik', 'https://klinik.ub.ac.id/feed/'),
  latest('latest', 'Berita Terkini', 'http://prasetya.ub.ac.id/feed/');

  const NewsFeed(this.id, this.label, this._url);

  final String id;
  final String label;
  final String _url;

  Uri get uri => Uri.parse(_url);

  static const tabs = [official, prasetya, selma, rsub, rsgm, klinik];
}
