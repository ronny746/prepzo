import 'package:flutter/material.dart';
import 'package:lms/core/widgets/app_scaffold.dart';

class ParentSetupScreen extends StatelessWidget {
  const ParentSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Parent Portal',
      showAppBar: false,
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.family_restroom_rounded, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Parent Portal coming soon',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
