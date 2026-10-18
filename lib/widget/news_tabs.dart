import 'package:flutter/material.dart';

import '../model/news_feed.dart';

/// Six source tabs and swipe navigation recovered from NewsState's TabBarView.
class NewsTabs extends StatefulWidget {
  const NewsTabs({
    super.key,
    required this.header,
    required this.initialFeed,
    required this.onSelected,
    required this.feedBuilder,
  });

  final Widget header;
  final NewsFeed initialFeed;
  final ValueChanged<NewsFeed> onSelected;
  final Widget Function(NewsFeed) feedBuilder;

  @override
  State<NewsTabs> createState() => _NewsTabsState();
}

class _NewsTabsState extends State<NewsTabs>
    with SingleTickerProviderStateMixin {
  late final _controller = TabController(
    length: NewsFeed.tabs.length,
    initialIndex: NewsFeed.tabs.indexOf(widget.initialFeed),
    vsync: this,
  )..addListener(_changed);
  late NewsFeed _selected = widget.initialFeed;

  void _changed() {
    final feed = NewsFeed.tabs[_controller.index];
    if (_selected == feed) return;
    _selected = feed;
    widget.onSelected(feed);
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      widget.header,
      TabBar(
        controller: _controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: [for (final feed in NewsFeed.tabs) Tab(text: feed.label)],
      ),
      Expanded(
        child: TabBarView(
          controller: _controller,
          children: [
            for (final feed in NewsFeed.tabs) widget.feedBuilder(feed),
          ],
        ),
      ),
    ],
  );
}
