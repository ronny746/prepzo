import 'package:flutter/material.dart';
import 'package:lms/core/widgets/app_scaffold.dart';

class StudentScheduleScreen extends StatelessWidget {
  const StudentScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Schedule',
      showAppBar: false,
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_rounded, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Schedule coming soon', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
