import 'package:flutter/material.dart';
import 'package:lms/core/widgets/app_scaffold.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Messages',
      showAppBar: false,
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_rounded, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Messages coming soon',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
