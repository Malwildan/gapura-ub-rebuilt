import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account_bridge.dart';
import '../services.dart';
import '../common/features.dart';
import '../common/colors.dart';
import '../model/records.dart';
import '../model/academic_term.dart';
import '../model/news_feed.dart';
import '../widget/academic_period_picker.dart';
import '../widget/news_tabs.dart';
import '../widget/student_attendance.dart';
import '../widget/achievement_carousel.dart';
import 'guest/university_information.dart';
import 'guest/university_library.dart';
import 'guest/student_profile.dart';
import '../widget/page_header.dart';
import '../model/general_announcement.dart';
import '../service/general_announcements.dart';
import '../widget/general_announcement_banner.dart';
part 'student/academic_views.dart';
part 'guest/university_views.dart';

class GapuraHome extends StatefulWidget {
  const GapuraHome({
    super.key,
    required this.onTheme,
    this.themeMode = ThemeMode.system,
    this.service,
    this.account,
    this.announcements,
    this.syntheticGuestPreview = false,
    this.previewControls,
  });
  final ValueChanged<ThemeMode> onTheme;
  final ThemeMode themeMode;
  final GapuraService? service;
  final AccountBridge? account;
  final GeneralAnnouncementsSource? announcements;
  final bool syntheticGuestPreview;
  final Widget? previewControls;
  @override
  State<GapuraHome> createState() => _GapuraHomeState();
}

class _GapuraHomeState extends State<GapuraHome> with WidgetsBindingObserver {
  void update(VoidCallback change) => setState(change);
  final scaffold = GlobalKey<ScaffoldState>();
  final scroll = ScrollController();
  final libraryKey = GlobalKey<UniversityLibraryViewState>();
  var attendanceKey = GlobalKey<StudentAttendanceState>();
  late final api = widget.service ?? GapuraService();
  late final account = widget.account ?? AccountBridge();
  late final announcementSource =
      widget.announcements ?? GeneralAnnouncementsSource();
  List<GeneralAnnouncement>? generalAnnouncements;
  GeneralAnnouncementsFailure? announcementFailure;
  final Map<String, List<Record>> cache = {};
  final Map<String, String> errors = {};
  final Set<String> loading = {};
  final List<String> stack = [];
  Record? profile;
  Record? profileUser;
  String? profileIdentityError;
  List<Record> courses = [];
  List<Record> regularCourses = [];
  final Map<String, List<Record>> summariesByPage = {};
  List<Record> get summaries => summariesByPage[page] ?? [];
  final Map<String, AcademicTerm> periods = {};
  final Map<String, int> studentVersions = {};
  int studentGeneration = 0, connectionVersion = 0;
  bool scheduleShort = false;
  NewsFeed selectedNewsFeed = NewsFeed.official;
  final newsSearch = {
    for (final feed in NewsFeed.tabs) feed: TextEditingController(),
  };
  Record? selectedCourse;
  String page = 'home', search = '', calendarTerm = 'Semua';
  String? connectionError;
  String? publicTitle;
  bool connecting = false, active = true;
  int day = 0;
  DateTime? updated;
  bool get connected => profile != null;
  // The connected account reader currently supports the student profile only.
  // These are the recovered student/fallback items, not staff Pendapa gates.
  List<({String page, String label, IconData icon})> get navigationItems => [
    (page: 'home', label: 'Beranda', icon: Icons.home),
    if (connected) (page: 'dashboard', label: 'Menu', icon: Icons.apps),
    (page: 'news', label: 'Berita', icon: Icons.chrome_reader_mode),
    if (connected) (page: 'profile', label: 'Profil', icon: Icons.person),
  ];
  bool get isPublic =>
      [...publicFeatures, ...publicReaderFeatures].any((f) => f.id == page);
  bool get isStudent => studentFeatures.any((f) => f.id == page);
  String get title =>
      publicTitle ??
      universityInformationTitle(page) ??
      switch (page) {
        'home' => 'Beranda',
        'dashboard' => 'Aplikasi Saya',
        'profile' => 'Profil Saya',
        'notifications' => 'Notifikasi',
        'attendance' => 'Presensi Kelas',
        'library' => 'Layanan Perpustakaan UB',
        'about' => 'Tentang Gapura UB',
        _ => [
          ...studentFeatures,
          ...studentMenuFeatures,
          ...publicFeatures,
          ...publicReaderFeatures,
        ].firstWhere((f) => f.id == page).label,
      };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadGeneralAnnouncements();
    loadHomeFeeds();
    if (!widget.syntheticGuestPreview) connect(silent: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scroll.dispose();
    for (final controller in newsSearch.values) {
      controller.dispose();
    }
    if (widget.service == null) api.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.syntheticGuestPreview &&
        state == AppLifecycleState.resumed &&
        !connected &&
        !connecting) {
      connect(silent: true);
    }
  }

  String errorText(Object e) => e.toString().replaceFirst(
    RegExp(r'^(Bad state: |StateError: |FormatException: |Exception: )'),
    '',
  );
  Future<void> connect({bool silent = false}) async {
    if (connecting) return;
    final version = ++connectionVersion;
    bool current() => mounted && connectionVersion == version;
    setState(() {
      connecting = true;
      connectionError = null;
    });
    try {
      final rows = records(await account.request('profile'), 'mhs');
      if (!current()) return;
      if (rows.isEmpty) {
        throw StateError('Profil mahasiswa tidak tersedia untuk akun ini.');
      }
      Record? identity;
      String? identityError;
      try {
        final data = await account.request('identity');
        identity = {
          'nim': data['X-Ub-Nim'] is String ? data['X-Ub-Nim'] : null,
          'email': data['X-Ub-Email'] is String ? data['X-Ub-Email'] : null,
        };
      } catch (e) {
        identityError = errorText(e);
      }
      if (!current()) return;
      setState(() {
        if (profile?['NIM'] != rows.first['NIM']) clearStudentState();
        profile = rows.first;
        profileUser = identity;
        profileIdentityError = identityError;
        updated = DateTime.now();
      });
      await loadStudent('schedule', force: true);
      if (!current()) return;
      if (isStudent && page != 'schedule') await loadStudent(page);
    } catch (e) {
      if (current() && !silent) setState(() => connectionError = errorText(e));
    } finally {
      if (current()) setState(() => connecting = false);
    }
  }

  Future<void> login() async {
    if (kIsWeb) {
      await open('https://akun.ub.ac.id/dashboard');
      return;
    }
    try {
      await account.request('login');
      await connect();
    } catch (e) {
      if (mounted) setState(() => connectionError = errorText(e));
    }
  }

  void go(String target, {bool back = false}) {
    if (widget.syntheticGuestPreview &&
        target != 'home' &&
        target != 'news' &&
        target != 'about' &&
        target != 'library' &&
        !publicFeatures.any((feature) => feature.id == target) &&
        !publicReaderFeatures.any((feature) => feature.id == target)) {
      return;
    }
    if (target == page && !back) return;
    setState(() {
      if (!back) {
        if (navigationItems.any((item) => item.page == target)) {
          stack.clear();
        } else {
          stack.add(page);
        }
      }
      page = target;
      publicTitle = null;
      search = '';
      day = 0;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
    if (isPublic) loadPublic(page);
    if ((isStudent || page == 'notifications') && connected) loadStudent(page);
  }

  void back() => go(stack.isEmpty ? 'home' : stack.removeLast(), back: true);
  String publicCacheKey(String target, {NewsFeed? feed}) =>
      target == 'news' ? 'news:${(feed ?? selectedNewsFeed).id}' : target;
  bool isPublicCacheKey(String key) =>
      key == 'latest_news' ||
      key.startsWith('news:') ||
      [
        ...publicFeatures,
        ...publicReaderFeatures,
      ].any((feature) => feature.id == key);

  static const homeNewsFeeds = [NewsFeed.rsub, NewsFeed.klinik, NewsFeed.rsgm];

  Future<void> loadHomeFeeds({bool force = false}) async {
    await Future.wait([
      loadPublic('latest_news', force: force),
      for (final feed in homeNewsFeeds)
        loadPublic('news', feed: feed, force: force),
    ]);
  }

  Future<void> loadGeneralAnnouncements() async {
    try {
      final rows = await announcementSource.fetch();
      if (!mounted) return;
      setState(() {
        generalAnnouncements = rows;
        announcementFailure = null;
      });
    } on GeneralAnnouncementsException catch (error) {
      if (!mounted) return;
      // The original failed fetch leaves its prior in-memory list intact.
      setState(() => announcementFailure = error.failure);
    }
  }

  void openHomeFeed(NewsFeed feed) {
    selectedNewsFeed = feed;
    go('news');
  }

  void selectNewsFeed(NewsFeed feed) {
    if (feed == selectedNewsFeed) return;
    setState(() {
      selectedNewsFeed = feed;
      search = '';
    });
    loadPublic('news');
  }

  Future<void> loadPublic(
    String target, {
    bool force = false,
    NewsFeed? feed,
  }) async {
    final newsFeed = feed ?? selectedNewsFeed;
    final key = publicCacheKey(target, feed: newsFeed);
    if (loading.contains(key) || (!force && cache.containsKey(key))) {
      return;
    }
    setState(() {
      loading.add(key);
      errors.remove(key);
    });
    try {
      final rows = await switch (target) {
        'news' => api.newsFeed(newsFeed),
        'latest_news' => api.latestNews(),
        'calendar' => api.calendar(),
        'statistics' => api.statistics(),
        'images' => api.images(),
        _ => Future<List<Record>>.value([]),
      };
      if (mounted) {
        setState(() {
          cache[key] = rows;
          updated = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() => errors[key] = errorText(e));
    } finally {
      if (mounted) setState(() => loading.remove(key));
    }
  }

  Future<void> loadStudent(String target, {bool force = false}) async {
    // Library is a bundled link list, with no account/API request of its own.
    if (target == 'library') return;
    if (!connected ||
        (!force && loading.contains(target)) ||
        (!force && cache.containsKey(target))) {
      return;
    }
    if (target == 'history' && regularCourses.isEmpty) return;
    final version = (studentVersions[target] ?? 0) + 1;
    studentVersions[target] = version;
    final generation = studentGeneration;
    final identity = profile?['NIM'];
    final selection = periods[target] ?? const AcademicTerm();
    final shortSchedule = scheduleShort;
    final course = target == 'history'
        ? selectedCourse ?? regularCourses.first
        : null;
    bool isCurrent() =>
        mounted &&
        connected &&
        studentGeneration == generation &&
        profile?['NIM'] == identity &&
        studentVersions[target] == version;
    setState(() {
      loading.add(target);
      errors.remove(target);
    });
    try {
      if (target == 'notifications') {
        final session = await account.request('connection');
        if (!isCurrent()) return;
        final username = value(session['username'], '');
        if (username.isEmpty) {
          throw StateError('Nama akun UB belum tersedia.');
        }
        final rows = await api.notifications(username);
        if (isCurrent()) {
          setState(() {
            cache[target] = rows;
            updated = DateTime.now();
          });
        }
        return;
      }
      final data = await account.request(
        target,
        parameters: {
          if (target == 'schedule') 'short': shortSchedule,
          if (['krs', 'grades', 'transcript'].contains(target))
            ...selection.toParameters(),
          if (target == 'materials') 'active': active,
          if (target == 'history') 'course': course,
        },
      );
      final key = switch (target) {
        'schedule' => 'jadwal',
        'krs' => 'krs',
        'grades' || 'transcript' => 'khs',
        'finance' => 'tagihan',
        'notifications' => 'notifications',
        _ => 'output',
      };
      final rows = records(data, key);
      if (isCurrent()) {
        setState(() {
          cache[target] = rows;
          updated = DateTime.now();
          if (target == 'schedule') {
            courses = rows;
            courses.sort(
              (a, b) => '${a['HARI_KE']}${a['JAM_MULAI']}'.compareTo(
                '${b['HARI_KE']}${b['JAM_MULAI']}',
              ),
            );
            if (!shortSchedule) regularCourses = List.of(courses);
          }
          if (['grades', 'transcript'].contains(target)) {
            summariesByPage[target] =
                data['akadSum'] is Map && data['akadSum']['data'] is List
                ? records(data, 'akadSum')
                : [];
          }
        });
      }
    } catch (e) {
      if (isCurrent()) setState(() => errors[target] = errorText(e));
    } finally {
      if (isCurrent()) setState(() => loading.remove(target));
    }
  }

  void selectPeriod(String target, AcademicTerm period) {
    if (period == (periods[target] ?? const AcademicTerm())) return;
    setState(() {
      periods[target] = period;
      cache.remove(target);
      errors.remove(target);
      summariesByPage.remove(target);
    });
    loadStudent(target, force: true);
  }

  void selectSchedule(bool short) {
    if (short == scheduleShort) return;
    setState(() {
      scheduleShort = short;
      courses = [];
      cache.remove('schedule');
      errors.remove('schedule');
      search = '';
      day = 0;
    });
    loadStudent('schedule', force: true);
  }

  Future<void> refresh() async {
    if (page == 'attendance') {
      await attendanceKey.currentState?.reload();
    } else if (page == 'library') {
      await libraryKey.currentState?.reload();
    } else if (isPublic) {
      await loadPublic(page, force: true);
    } else if (isStudent || page == 'notifications') {
      await loadStudent(page, force: true);
    } else {
      await Future.wait([
        loadHomeFeeds(force: true),
        loadGeneralAnnouncements(),
      ]);
      if (connected && !widget.syntheticGuestPreview) await connect();
    }
  }

  Future<void> open(String address) async {
    if (widget.syntheticGuestPreview) return;
    final uri = Uri.tryParse(address);
    if (uri == null ||
        uri.scheme != 'https' ||
        !(uri.host == 'ub.ac.id' || uri.host.endsWith('.ub.ac.id'))) {
      return;
    }
    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: scaffold,
    drawer: drawer(),
    appBar: header(),
    body: SafeArea(
      bottom: false,
      child: page == 'news'
          ? newsBody()
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView(
                    controller: scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: page == 'home' || page == 'profile'
                            ? const EdgeInsets.only(bottom: 36)
                            : page == 'dashboard'
                            ? const EdgeInsets.only(top: 5, bottom: 36)
                            : const EdgeInsets.fromLTRB(20, 20, 20, 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (connectionError != null) ...[
                              message(connectionError!, error: true),
                              const SizedBox(height: 16),
                            ],
                            ...switch (page) {
                              'home' => home(),
                              'dashboard' => dashboard(),
                              'profile' => profileView(),
                              'about' => about(),
                              _ => isPublic ? publicView() : studentView(),
                            },
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
    bottomNavigationBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.previewControls != null) widget.previewControls!,
        BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: navigationBackground,
          selectedItemColor: navigationSelected,
          unselectedItemColor: navigationUnselected,
          iconSize: 24,
          selectedFontSize: 14,
          unselectedFontSize: 12,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          currentIndex:
              navigationItems.indexWhere((item) => item.page == page) < 0
              ? 0
              : navigationItems.indexWhere((item) => item.page == page),
          onTap: (i) => go(navigationItems[i].page),
          items: [
            for (final item in navigationItems)
              BottomNavigationBarItem(icon: Icon(item.icon), label: item.label),
          ],
        ),
      ],
    ),
  );
  Widget newsBody() => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: NewsTabs(
        header: const SizedBox.shrink(),
        initialFeed: selectedNewsFeed,
        onSelected: selectNewsFeed,
        feedBuilder: (feed) => RefreshIndicator(
          onRefresh: () => loadPublic('news', force: true, feed: feed),
          child: ListView(
            key: PageStorageKey('news-${feed.id}'),
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: publicView(feed: feed),
          ),
        ),
      ),
    ),
  );
  PreferredSizeWidget header() {
    final root = navigationItems.any((item) => item.page == page);
    return AppBar(
      backgroundColor: navigationBackground,
      foregroundColor: Colors.white,
      toolbarHeight: 56,
      leading: IconButton(
        tooltip: root ? 'Buka menu' : 'Kembali',
        onPressed: root ? () => scaffold.currentState?.openDrawer() : back,
        icon: Icon(root ? Icons.menu : Icons.arrow_back_ios_new),
      ),
      title: page == 'home' || page == 'news' || page == 'profile'
          ? Image.asset('assets/img/gapura-logo-white.png', height: 20)
          : Text(title),
      actions: [
        if (!widget.syntheticGuestPreview)
          IconButton(
            tooltip: 'Notifikasi',
            onPressed: () => go('notifications'),
            icon: const Icon(Icons.notifications_none),
          ),
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: refresh,
          icon: const Icon(Icons.refresh),
        ),
        PopupMenuButton<ThemeMode>(
          tooltip: 'Ganti tema',
          initialValue: widget.themeMode,
          onSelected: widget.onTheme,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: ThemeMode.system,
              child: Text('Sesuai sistem'),
            ),
            PopupMenuItem(value: ThemeMode.light, child: Text('Terang')),
            PopupMenuItem(value: ThemeMode.dark, child: Text('Gelap')),
          ],
          icon: const Icon(Icons.brightness_6_outlined),
        ),
      ],
    );
  }

  List<Widget> home() => [
    AchievementCarousel(
      service: api,
      onOpen: open,
      localPreview: widget.syntheticGuestPreview,
    ),
    Padding(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width / 20,
      ),
      child: connected
          ? Text(
              'Halo, ${value(profile?['NAMA'])}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Halo, Pengunjung\n',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xffed8b00),
                  ),
                ),
                if (!widget.syntheticGuestPreview)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Akses menu lain? silakan ',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xff004f86),
                        ),
                      ),
                      Semantics(
                        button: true,
                        child: InkWell(
                          onTap: login,
                          child: const Text(
                            'masuk',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xffffaa32),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    ),
    // Two columns and zero grid padding are recovered. Full-width constraints
    // are a responsive accommodation; the binary's width180/height0.9W
    // arguments do not establish their final rendered geometry.
    Card(child: featureGrid(publicFeatures, columns: 2, radius: 13)),
    GeneralAnnouncementBanner(announcements: generalAnnouncements),
    homeFeed('Berita Terkini', 'latest_news', onTap: () => go('news')),
    homeFeed('Info Rumah Sakit UB', 'news:rsub', feed: NewsFeed.rsub),
    homeFeed('Info Klinik UB', 'news:klinik', feed: NewsFeed.klinik),
    homeFeed('Info RSGM UB', 'news:rsgm', feed: NewsFeed.rsgm),
  ];

  Widget homeFeed(
    String label,
    String key, {
    NewsFeed? feed,
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onTap ?? () => openHomeFeed(feed!),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              label,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
            ),
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView(
            key: ValueKey('home-$key'),
            primary: false,
            children: [
              ...status(
                key,
                onRetry: () => loadPublic(
                  feed == null ? 'latest_news' : 'news',
                  feed: feed,
                  force: true,
                ),
              ),
              if (!loading.contains(key) &&
                  errors[key] == null &&
                  (cache[key] ?? []).isEmpty)
                empty('Tidak ada berita untuk saat ini.'),
              for (final row in cache[key] ?? <Record>[]) newsCard(row),
            ],
          ),
        ),
      ],
    ),
  );
  Widget loginCard() => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Satu akun, semua layanan.',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const Text(
          'Masuk untuk melihat jadwal kuliah, hasil studi, dan layanan mahasiswa Anda.',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: login,
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Masuk dengan Akun UB'),
            ),
            if (kIsWeb)
              OutlinedButton.icon(
                onPressed: connecting ? null : () => connect(),
                icon: connecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 18),
                label: Text(
                  connecting ? 'Menghubungkan…' : 'Hubungkan sesi UB',
                ),
              ),
          ],
        ),
      ],
    ),
  );
  List<Widget> dashboard() => [
    if (!connected) loginCard(),
    if (connected)
      for (final feature in studentMenuFeatures)
        Container(
          margin: const EdgeInsets.fromLTRB(15, 0, 15, 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(13)),
          child: Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              leading: SizedBox(
                width: 40,
                child: Image.asset('assets/${feature.asset}'),
              ),
              title: Text(feature.label),
              trailing: const Icon(Icons.keyboard_arrow_right),
              onTap: () => go(feature.id),
            ),
          ),
        ),
  ];
  Widget heading(String text, {String? action, VoidCallback? onTap}) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
      ),
      if (action != null) TextButton(onPressed: onTap, child: Text(action)),
    ],
  );
  Widget featureGrid(List<Feature> items, {int? columns, double radius = 15}) =>
      LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns ?? (constraints.maxWidth > 750 ? 8 : 4),
            mainAxisSpacing: 14,
            crossAxisSpacing: 8,
            mainAxisExtent: 116,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final f = items[i];
            return Semantics(
              button: true,
              label: f.label,
              child: InkWell(
                excludeFromSemantics: true,
                borderRadius: BorderRadius.circular(radius),
                onTap: () => go(f.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 7,
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/${f.asset}',
                        width: 58,
                        height: 58,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            Icon(f.icon, size: 46, color: Colors.orange),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        f.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
  List<Widget> profileView() => !connected
      ? [loginCard()]
      : [
          const PageHeader(title: 'Profil Saya'),
          const SizedBox(height: 2),
          StudentProfileView(profile: profile!, user: profileUser),
          if (profileIdentityError != null)
            message(profileIdentityError!, error: true),
        ];

  // Called inside setState before replacing/removing the connected profile.
  // The generation prevents old A requests becoming current after A -> B -> A.
  void clearStudentState() {
    studentGeneration++;
    studentVersions.clear();
    attendanceKey = GlobalKey<StudentAttendanceState>();
    profileUser = null;
    profileIdentityError = null;
    courses = [];
    regularCourses = [];
    summariesByPage.clear();
    periods.clear();
    scheduleShort = false;
    selectedCourse = null;
    active = true;
    search = '';
    day = 0;
    updated = null;
    loading.removeWhere((key) => !isPublicCacheKey(key));
    cache.removeWhere((key, _) => !isPublicCacheKey(key));
    errors.removeWhere((key, _) => !isPublicCacheKey(key));
  }

  Future<void> disconnect() async {
    // Invalidate immediately, including a connect waiting on profile/identity.
    connectionVersion++;
    setState(() {
      clearStudentState();
      connecting = false;
      profile = null;
      connectionError = null;
    });
    go('home');
    if (!kIsWeb) await account.request('disconnect');
  }

  Widget detail(String key, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(key, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
  String term() => courses.isEmpty
      ? 'Semester mengikuti data dari UB'
      : 'Semester ${value(courses.first['IS_GANJIL']) == '1' ? 'Ganjil' : 'Genap'} · ${value(courses.first['TAHUN'])}';

  String academicPeriodLabel() {
    final period = periods[page] ?? const AcademicTerm();
    if (period.isExplicit) return period.label;
    final scope = page == 'transcript' ? 'Semua semester' : 'Semester berjalan';
    return '$scope · ${period.short ? 'Pendek' : 'Reguler'}';
  }

  int historyCourseIndex() {
    if (selectedCourse == null) return 0;
    final index = regularCourses.indexWhere(
      (row) => ['K_MK', 'KELAS', 'TAHUN', 'IS_GANJIL'].every(
        (key) => row[key]?.toString() == selectedCourse?[key]?.toString(),
      ),
    );
    return index < 0 ? 0 : index;
  }

  List<Widget> status(String target, {VoidCallback? onRetry}) => [
    if (loading.contains(target))
      const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    if (errors[target] != null) ...[
      message(errors[target]!, error: true),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed:
              onRetry ??
              () => publicFeatures.any((f) => f.id == target)
                  ? loadPublic(target, force: true)
                  : loadStudent(target, force: true),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Coba lagi'),
        ),
      ),
    ],
  ];
  Widget card(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
  Widget message(String text, {bool error = false}) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: (error ? const Color(0xffa65220) : const Color(0xff338362))
          .withValues(alpha: .15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: (error ? const Color(0xffa65220) : const Color(0xff338362))
            .withValues(alpha: .5),
      ),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.5,
        color: Theme.of(context).brightness == Brightness.dark
            ? (error ? const Color(0xffffc397) : const Color(0xff9be0c0))
            : null,
      ),
    ),
  );
  Widget empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 20),
    child: Column(
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 42,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
  List<Widget> about() => [
    Image.asset('assets/img/app-logo_gapura-logo.png', height: 80),
    const SizedBox(height: 24),
    const Text(
      'Gapura UB',
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 12),
    const Text(
      'Rekonstruksi Flutter dari aplikasi Android 3.3.38. Menggunakan artwork asli dan kontrak layanan yang dipulihkan dari paket aplikasi.',
      style: TextStyle(height: 1.7),
    ),
    const SizedBox(height: 16),
    const Text(
      'Data akademik dibaca dari sesi Akun UB Anda. Berita, kalender, statistik, dan galeri berasal dari layanan UB. Presensi, perubahan KRS, pembayaran, dan layanan pegawai belum diimplementasikan.',
      style: TextStyle(height: 1.7),
    ),
    const SizedBox(height: 18),
    OutlinedButton(
      onPressed: () => open('https://gapura.ub.ac.id'),
      child: const Text('Gapura Universitas Brawijaya'),
    ),
  ];
  Widget drawer() => Drawer(
    child: SafeArea(
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: blue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/img/gapura-logo-white.png', height: 40),
                const SizedBox(height: 22),
                Text(
                  connected ? value(profile?['NAMA']) : 'Selamat datang',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  connected ? value(profile?['NIM']) : 'Universitas Brawijaya',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          for (final e in [
            ('home', 'Beranda', Icons.home_outlined),
            if (!widget.syntheticGuestPreview) ...[
              ('profile', 'Profil Saya', Icons.person_outline),
              ('dashboard', 'Aplikasi Saya', Icons.grid_view_outlined),
              ('notifications', 'Notifikasi', Icons.notifications_none),
            ],
          ])
            ListTile(
              leading: Icon(e.$3),
              title: Text(e.$2),
              onTap: () {
                Navigator.pop(context);
                go(e.$1);
              },
            ),
          if (connected)
            for (final f in studentFeatures.where(
              (f) => !studentMenuFeatures.any((item) => item.id == f.id),
            ))
              ListTile(
                leading: Icon(f.icon),
                title: Text(f.label),
                onTap: () {
                  Navigator.pop(context);
                  go(f.id);
                },
              ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 15, 20, 8),
            child: Text(
              'UNIVERSITAS',
              style: TextStyle(fontSize: 11, letterSpacing: 2),
            ),
          ),
          for (final f in [...publicFeatures, ...publicReaderFeatures])
            ListTile(
              leading: Icon(f.icon),
              title: Text(f.label),
              onTap: () {
                Navigator.pop(context);
                go(f.id);
              },
            ),
          const Divider(),
          if (connected)
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('Putuskan koneksi aplikasi'),
              onTap: () async {
                Navigator.pop(context);
                await disconnect();
              },
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Tentang Gapura UB'),
            onTap: () {
              Navigator.pop(context);
              go('about');
            },
          ),
        ],
      ),
    ),
  );
}
