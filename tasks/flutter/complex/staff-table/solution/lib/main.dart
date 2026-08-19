import 'package:flutter/material.dart';

import 'staff.dart';
import 'staff_table.dart';

void main() => runApp(const StaffApp());

class StaffApp extends StatelessWidget {
  const StaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Staff',
      home: Scaffold(
        body: SafeArea(
          child: StaffTable(members: staffRoster),
        ),
      ),
    );
  }
}
