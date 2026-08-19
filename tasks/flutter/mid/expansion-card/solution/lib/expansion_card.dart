import 'package:flutter/material.dart';

/// Custom expansion card: tappable header, rotating chevron, animated body.
class ExpansionCard extends StatefulWidget {
  const ExpansionCard({
    required this.title,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    super.key,
  });

  final String title;
  final Widget child;
  final Duration duration;

  @override
  State<ExpansionCard> createState() => _ExpansionCardState();
}

class _ExpansionCardState extends State<ExpansionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.status == AnimationStatus.forward ||
        _controller.status == AnimationStatus.completed) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: const Key('expansion-header'),
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  RotationTransition(
                    key: const Key('expansion-chevron'),
                    turns: Tween<double>(begin: 0.0, end: 0.5).animate(_curve),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: SizeTransition(
              key: const Key('expansion-body'),
              sizeFactor: _curve,
              axisAlignment: -1,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
