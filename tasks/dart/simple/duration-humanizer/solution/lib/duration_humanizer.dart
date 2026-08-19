/// Human-readable rendering of [Duration] values.

/// Renders [duration] as described in the project brief.
String humanize(Duration duration) {
  if (duration.inSeconds == 0) return '0 seconds';
  if (duration.isNegative) return 'minus ${humanize(-duration)}';
  final totalSeconds = duration.inSeconds;
  final days = totalSeconds ~/ 86400;
  final hours = (totalSeconds % 86400) ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final units = [
    (days, 'day'),
    (hours, 'hour'),
    (minutes, 'minute'),
    (seconds, 'second'),
  ];
  final parts = units
      .where((u) => u.$1 > 0)
      .take(2)
      .map((u) => '${u.$1} ${u.$2}${u.$1 == 1 ? '' : 's'}')
      .toList();
  return parts.join(' ');
}
