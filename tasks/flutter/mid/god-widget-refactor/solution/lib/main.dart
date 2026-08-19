import 'package:flutter/material.dart';

import 'widgets/profile_header.dart';
import 'widgets/settings_section.dart';
import 'widgets/stats_row.dart';

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

/// Profile screen: owns the state, composes the reusable pieces.
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
          ProfileHeader(
            name: name,
            handle: handle,
            following: _following,
            onFollowToggle: () {
              setState(() {
                _following = !_following;
              });
            },
          ),
          const SizedBox(height: 24),
          const StatsRow(
            posts: posts,
            followers: followers,
            following: followingCount,
          ),
          const SizedBox(height: 24),
          SettingsSection(
            values: _settings,
            onChanged: (title, value) {
              setState(() {
                _settings[title] = value;
              });
            },
          ),
        ],
      ),
    );
  }
}
