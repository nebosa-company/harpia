import 'dart:async';

import 'package:flutter/material.dart';

import 'search_api.dart';

/// Debounced search over a [SearchApi], dropping stale responses.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    required this.api,
    this.debounce = const Duration(milliseconds: 300),
    super.key,
  });

  final SearchApi api;
  final Duration debounce;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Timer? _debounceTimer;
  int _generation = 0;
  bool _loading = false;
  List<String> _results = const [];
  String _query = '';

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounceTimer?.cancel();
    if (text.isEmpty) {
      _generation++;
      setState(() {
        _query = '';
        _results = const [];
        _loading = false;
      });
      return;
    }
    _debounceTimer = Timer(widget.debounce, () => _fire(text));
  }

  void _fire(String text) {
    final generation = ++_generation;
    setState(() {
      _query = text;
      _loading = true;
    });
    widget.api.search(text).then((hits) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _loading = false;
        _results = hits;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            key: const Key('search-field'),
            onChanged: _onChanged,
            decoration: const InputDecoration(
              labelText: 'Search the pantry',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(key: Key('search-loading')),
            ),
          )
        else if (_query.isNotEmpty && _results.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No results', key: Key('no-results')),
          )
        else
          Expanded(
            child: ListView(
              children: [
                for (final hit in _results) ListTile(title: Text(hit)),
              ],
            ),
          ),
      ],
    );
  }
}
