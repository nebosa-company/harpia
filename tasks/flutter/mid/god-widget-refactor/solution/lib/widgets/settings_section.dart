import 'package:flutter/material.dart';

/// One SwitchListTile per setting, reporting changes upward.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.values,
    required this.onChanged,
    super.key,
  });

  final Map<String, bool> values;
  final void Function(String title, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in values.entries)
          SwitchListTile(
            key: Key('setting-${entry.key}'),
            title: Text(entry.key),
            value: entry.value,
            onChanged: (value) => onChanged(entry.key, value),
          ),
      ],
    );
  }
}
