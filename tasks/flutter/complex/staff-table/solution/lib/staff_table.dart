import 'package:flutter/material.dart';

import 'staff.dart';

/// Sortable, filterable staff table.
class StaffTable extends StatefulWidget {
  const StaffTable({required this.members, super.key});

  final List<StaffMember> members;

  @override
  State<StaffTable> createState() => _StaffTableState();
}

class _StaffTableState extends State<StaffTable> {
  late List<StaffMember> _rows;
  String _filter = '';
  String? _sortColumn;
  bool _ascending = true;

  @override
  void initState() {
    super.initState();
    _rows = List.of(widget.members);
  }

  static String formatSalary(int salary) {
    final digits = salary.toString();
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        grouped.write(',');
      }
      grouped.write(digits[i]);
    }
    return '\$$grouped';
  }

  void _sortBy(String column) {
    setState(() {
      if (_sortColumn == column) {
        _ascending = !_ascending;
      } else {
        _sortColumn = column;
        _ascending = true;
      }
      final sign = _ascending ? 1 : -1;
      int compare(StaffMember a, StaffMember b) {
        switch (column) {
          case 'name':
            return sign * a.name.compareTo(b.name);
          case 'department':
            return sign * a.department.compareTo(b.department);
          default:
            return sign * a.salary.compareTo(b.salary);
        }
      }

      // Stable sort: decorate with the current display index.
      final indexed = _rows.asMap().entries.toList();
      indexed.sort((a, b) {
        final c = compare(a.value, b.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
      _rows = [for (final entry in indexed) entry.value];
    });
  }

  bool _matches(StaffMember member) {
    if (_filter.isEmpty) {
      return true;
    }
    final needle = _filter.toLowerCase();
    return member.name.toLowerCase().contains(needle) ||
        member.department.toLowerCase().contains(needle);
  }

  @override
  Widget build(BuildContext context) {
    final visible = [for (final m in _rows) if (_matches(m)) m];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            key: const Key('filter-field'),
            onChanged: (value) => setState(() => _filter = value),
            decoration: const InputDecoration(
              labelText: 'Filter by name or department',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Showing ${visible.length} of ${widget.members.length}',
            key: const Key('count-label'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _header('name', 'Name'),
            _header('department', 'Department'),
            _header('salary', 'Salary'),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('No matches', key: Key('no-rows')))
              : SingleChildScrollView(
                  child: Column(
                    children: [for (final m in visible) _row(m)],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _header(String column, String label) {
    final active = _sortColumn == column;
    return Expanded(
      child: InkWell(
        key: Key('header-$column'),
        onTap: () => _sortBy(column),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (active)
                Icon(
                  _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  key: const Key('sort-icon'),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(StaffMember member) {
    return Container(
      key: Key('row-${member.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(member.name)),
          Expanded(child: Text(member.department)),
          Expanded(child: Text(formatSalary(member.salary))),
        ],
      ),
    );
  }
}
