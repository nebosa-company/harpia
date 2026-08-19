import 'dart:async';

import 'package:flutter/material.dart';

enum _BannerState { none, offline, backOnline }

/// Banner strip above [child], driven by an injected online/offline stream.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({
    required this.status,
    required this.child,
    super.key,
  });

  /// true = online, false = offline.
  final Stream<bool> status;
  final Widget child;

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  StreamSubscription<bool>? _subscription;
  Timer? _hideTimer;
  _BannerState _banner = _BannerState.none;

  @override
  void initState() {
    super.initState();
    _subscription = widget.status.listen(_onStatus);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  void _onStatus(bool online) {
    if (!online) {
      _hideTimer?.cancel();
      _hideTimer = null;
      if (_banner != _BannerState.offline) {
        setState(() {
          _banner = _BannerState.offline;
        });
      }
      return;
    }
    // Online event: only interesting when we were offline just now.
    if (_banner == _BannerState.offline) {
      _hideTimer?.cancel();
      setState(() {
        _banner = _BannerState.backOnline;
      });
      _hideTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _banner = _BannerState.none;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_banner == _BannerState.offline)
          Container(
            width: double.infinity,
            color: Colors.red.shade700,
            padding: const EdgeInsets.all(8),
            child: const Text(
              'No internet connection',
              key: Key('offline-banner'),
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          )
        else if (_banner == _BannerState.backOnline)
          Container(
            width: double.infinity,
            color: Colors.green.shade700,
            padding: const EdgeInsets.all(8),
            child: const Text(
              'Back online',
              key: Key('online-banner'),
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
