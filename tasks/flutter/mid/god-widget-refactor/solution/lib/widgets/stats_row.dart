import 'package:flutter/material.dart';

/// Posts / followers / following, side by side.
class StatsRow extends StatelessWidget {
  const StatsRow({
    required this.posts,
    required this.followers,
    required this.following,
    super.key,
  });

  final int posts;
  final int followers;
  final int following;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _stat(context, const Key('stat-posts'), posts, 'Posts'),
        _stat(context, const Key('stat-followers'), followers, 'Followers'),
        _stat(context, const Key('stat-following'), following, 'Following'),
      ],
    );
  }

  Widget _stat(BuildContext context, Key key, int value, String label) {
    return Column(
      key: key,
      children: [
        Text('$value', style: Theme.of(context).textTheme.titleMedium),
        Text(label),
      ],
    );
  }
}
