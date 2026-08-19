import 'package:flutter/material.dart';

void main() => runApp(const ProfileApp());

class ProfileApp extends StatelessWidget {
  const ProfileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Profile',
      home: ProfilePage(),
    );
  }
}

/// The whole profile screen in one widget. It grew. Nobody stopped it.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String name = 'Ada Runcorn';
  static const String handle = '@ada';
  static const int posts = 128;
  static const int followers = 3421;
  static const int followingCount = 210;

  bool _following = false;
  final Map<String, bool> _settings = {
    'Notifications': true,
    'Dark mode': false,
    'Auto-play videos': true,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- header ---
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                child: Text(
                  name.split(' ').map((part) => part[0]).join(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(handle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              ElevatedButton(
                key: const Key('follow-button'),
                onPressed: () {
                  setState(() {
                    _following = !_following;
                  });
                },
                child: Text(_following ? 'Following' : 'Follow'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // --- stats ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                key: const Key('stat-posts'),
                children: [
                  Text('$posts',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Text('Posts'),
                ],
              ),
              Column(
                key: const Key('stat-followers'),
                children: [
                  Text('$followers',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Text('Followers'),
                ],
              ),
              Column(
                key: const Key('stat-following'),
                children: [
                  Text('$followingCount',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Text('Following'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // --- settings ---
          for (final entry in _settings.entries)
            SwitchListTile(
              key: Key('setting-${entry.key}'),
              title: Text(entry.key),
              value: entry.value,
              onChanged: (value) {
                setState(() {
                  _settings[entry.key] = value;
                });
              },
            ),
        ],
      ),
    );
  }
}
