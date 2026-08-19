import 'package:flutter/material.dart';

void main() => runApp(const TabsApp());

class TabsApp extends StatelessWidget {
  const TabsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Sections',
      home: TabsPage(),
    );
  }
}

class TabsPage extends StatefulWidget {
  const TabsPage({super.key});

  @override
  State<TabsPage> createState() => _TabsPageState();
}

class _TabsPageState extends State<TabsPage> with SingleTickerProviderStateMixin {
  static const labels = ['Home', 'Search', 'Profile'];

  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
    _controller.animation!.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // Track the nearest tab while tapping or swiping.
    final nearest = _controller.animation!.value.round();
    if (nearest != _current) {
      setState(() {
        _current = nearest;
      });
    }
  }

  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(labels[_current], key: const Key('appbar-title')),
        bottom: TabBar(
          controller: _controller,
          tabs: const [
            Tab(key: Key('tab-home'), text: 'Home'),
            Tab(key: Key('tab-search'), text: 'Search'),
            Tab(key: Key('tab-profile'), text: 'Profile'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [
          Center(child: Text('Welcome home', key: Key('home-view'))),
          Center(child: Text('Search the catalog', key: Key('search-view'))),
          Center(child: Text('Your profile', key: Key('profile-view'))),
        ],
      ),
    );
  }
}
