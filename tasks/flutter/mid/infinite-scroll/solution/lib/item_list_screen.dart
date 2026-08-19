import 'package:flutter/material.dart';

import 'item_repository.dart';

/// Infinitely scrolling list over a paged [ItemRepository].
class ItemListScreen extends StatefulWidget {
  const ItemListScreen({required this.repository, super.key});

  final ItemRepository repository;

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  final List<String> _items = [];
  int _nextPage = 0;
  bool _loading = false;
  bool _exhausted = false;

  @override
  void initState() {
    super.initState();
    _fetchNext();
  }

  void _fetchNext() {
    if (_loading || _exhausted) {
      return;
    }
    _loading = true;
    final page = _nextPage;
    widget.repository.fetchPage(page).then((batch) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        if (batch.isEmpty) {
          _exhausted = true;
        } else {
          _items.addAll(batch);
          _nextPage = page + 1;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
          itemCount: _items.length + 1,
          itemBuilder: (context, index) {
            if (index < _items.length) {
              return ListTile(title: Text(_items[index]));
            }
            if (_exhausted) {
              return const ListTile(
                title: Center(
                  child: Text('End of list', key: Key('end-of-list')),
                ),
              );
            }
            if (!_loading) {
              // The sentinel became visible: ask for the next page once the
              // current frame is done building.
              WidgetsBinding.instance.addPostFrameCallback((_) => _fetchNext());
            }
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: CircularProgressIndicator(key: Key('loading-indicator')),
              ),
            );
          },
        ),
      ),
    );
  }
}
