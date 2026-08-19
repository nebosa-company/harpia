import 'package:flutter/material.dart';

/// Adaptive shell: phone below 600, rail up to 1024, pinned panel above.
class ResponsiveHome extends StatelessWidget {
  const ResponsiveHome({super.key});

  static const sections = ['Inbox', 'Starred', 'Sent', 'Drafts'];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < 600) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Mail'),
              leading: IconButton(
                key: const Key('menu-button'),
                icon: const Icon(Icons.menu),
                onPressed: () {},
              ),
            ),
            body: KeyedSubtree(
              key: const Key('mobile-layout'),
              child: _sectionList(),
            ),
          );
        }
        if (width < 1024) {
          return Scaffold(
            appBar: AppBar(title: const Text('Mail')),
            body: KeyedSubtree(
              key: const Key('tablet-layout'),
              child: Row(
                children: [
                  NavigationRail(
                    key: const Key('nav-rail'),
                    selectedIndex: 0,
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.inbox),
                        label: Text('Inbox'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.star_border),
                        label: Text('Starred'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.send),
                        label: Text('Sent'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.drafts),
                        label: Text('Drafts'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: _sectionList()),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Mail')),
          body: KeyedSubtree(
            key: const Key('desktop-layout'),
            child: Row(
              children: [
                SizedBox(
                  key: const Key('side-panel'),
                  width: 280,
                  child: ListView(
                    children: [
                      for (final section in sections)
                        ListTile(title: Text(section)),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _sectionList()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionList() {
    return ListView(
      children: [
        for (final section in sections) ListTile(title: Text(section)),
      ],
    );
  }
}
