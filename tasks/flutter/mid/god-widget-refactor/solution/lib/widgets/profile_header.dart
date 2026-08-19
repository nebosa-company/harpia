import 'package:flutter/material.dart';

/// Avatar, name, handle, and the follow button.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.name,
    required this.handle,
    required this.following,
    required this.onFollowToggle,
    super.key,
  });

  final String name;
  final String handle;
  final bool following;
  final VoidCallback onFollowToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          child: Text(name.split(' ').map((part) => part[0]).join()),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleLarge),
              Text(handle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        ElevatedButton(
          key: const Key('follow-button'),
          onPressed: onFollowToggle,
          child: Text(following ? 'Following' : 'Follow'),
        ),
      ],
    );
  }
}
