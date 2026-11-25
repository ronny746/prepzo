import 'package:flutter/material.dart';

class UserProfile {
  const UserProfile({
    required this.name,
    required this.role,
    required this.email,
    required this.mobile,
    required this.address,
    required this.dateOfBirth,
    required this.gender,
    required this.userId,
    required this.institute,
    required this.className,
    required this.section,
    required this.rollNumber,
    required this.session,
  });

  final String name;
  final String role;
  final String email;
  final String mobile;
  final String address;
  final String dateOfBirth;
  final String gender;
  final String userId;
  final String institute;
  final String className;
  final String section;
  final String rollNumber;
  final String session;
}

class NotificationItem {
  const NotificationItem({
    required this.title,
    required this.message,
    required this.category,
    required this.time,
    this.isRead = false,
  });

  final String title;
  final String message;
  final String category;
  final String time;
  final bool isRead;
}

class SettingOption {
  const SettingOption({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class SupportOption {
  const SupportOption({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class DashboardStat {
  const DashboardStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;
}

class ScheduleItem {
  const ScheduleItem({
    required this.time,
    required this.subject,
    required this.teacher,
    required this.room,
  });

  final String time;
  final String subject;
  final String teacher;
  final String room;
}

class FutureModule {
  const FutureModule({required this.title, required this.icon});

  final String title;
  final IconData icon;
}

class AppData {
  static const studentProfile = UserProfile(
    name: 'Aarav Sharma',
    role: 'Student',
    email: 'aarav.sharma@example.com',
    mobile: '+91 98765 43210',
    address: '12 Green Avenue, New Delhi',
    dateOfBirth: '14 Aug 2010',
    gender: 'Male',
    userId: 'STD-1024',
    institute: 'The Prepzo',
    className: 'Class 10',
    section: 'A',
    rollNumber: '23',
    session: '2026-27',
  );

  static const parentProfile = UserProfile(
    name: 'Priya Sharma',
    role: 'Parent',
    email: 'priya.sharma@example.com',
    mobile: '+91 99887 77665',
    address: '12 Green Avenue, New Delhi',
    dateOfBirth: '03 Mar 1987',
    gender: 'Female',
    userId: 'PAR-2048',
    institute: 'The Prepzo',
    className: 'Class 10',
    section: 'A',
    rollNumber: '23',
    session: '2026-27',
  );

  static const studentStats = <DashboardStat>[
    DashboardStat(
      label: 'Attendance',
      value: '92%',
      icon: Icons.fact_check_outlined,
      color: Color(0xFF22C55E),
      trend: '+2% this month',
    ),
    DashboardStat(
      label: 'Assignments',
      value: '14',
      icon: Icons.assignment_outlined,
      color: Color(0xFFF59E0B),
      trend: '3 pending',
    ),
    DashboardStat(
      label: 'Upcoming Exams',
      value: '03',
      icon: Icons.event_note_outlined,
      color: Color(0xFF4F46E5),
      trend: 'Next in 2 days',
    ),
    DashboardStat(
      label: 'Resources',
      value: '28',
      icon: Icons.auto_stories_outlined,
      color: Color(0xFF06B6D4),
      trend: '5 new uploads',
    ),
  ];

  static const parentStats = <DashboardStat>[
    DashboardStat(
      label: 'Attendance',
      value: '92%',
      icon: Icons.fact_check_outlined,
      color: Color(0xFF22C55E),
      trend: 'Strong this term',
    ),
    DashboardStat(
      label: 'Performance',
      value: 'A-',
      icon: Icons.insights_outlined,
      color: Color(0xFF4F46E5),
      trend: 'Improved in science',
    ),
    DashboardStat(
      label: 'Assignments',
      value: '03',
      icon: Icons.assignment_late_outlined,
      color: Color(0xFFF59E0B),
      trend: 'Need attention',
    ),
    DashboardStat(
      label: 'Exam Reminders',
      value: '02',
      icon: Icons.alarm_outlined,
      color: Color(0xFFEF4444),
      trend: 'This week',
    ),
  ];

  static const recentActivities = <Map<String, String>>[
    {
      'title': 'New Assignment Uploaded',
      'subtitle': 'Biology NCERT Chapter 12 worksheet due tomorrow',
      'time': '10 min ago',
    },
    {
      'title': 'Teacher Feedback Added',
      'subtitle': 'Chemistry practical reviewed with 4.8/5 score',
      'time': '45 min ago',
    },
    {
      'title': 'Revision Notes Shared',
      'subtitle': 'Chemistry Organic reactions summary added to resources',
      'time': 'Yesterday',
    },
  ];

  static const schedule = <ScheduleItem>[
    ScheduleItem(
      time: '08:30',
      subject: 'Physics',
      teacher: 'Ms. Mehta',
      room: 'Lab 2',
    ),
    ScheduleItem(
      time: '10:00',
      subject: 'Chemistry',
      teacher: 'Dr. Sharma',
      room: 'Chem Lab',
    ),
    ScheduleItem(
      time: '12:30',
      subject: 'Biology',
      teacher: 'Ms. Roy',
      room: 'Room 12',
    ),
  ];

  static const upcomingEvents = <Map<String, String>>[
    {'title': 'NEET Physics Unit Test', 'subtitle': 'Friday • 09:30 AM'},
    {
      'title': 'All India NEET Mock Analysis',
      'subtitle': 'Monday • Auditorium',
    },
    {'title': 'Parent Progress Review', 'subtitle': 'Wednesday • 11:00 AM'},
  ];

  static const notifications = <NotificationItem>[
    NotificationItem(
      title: 'Attendance Alert',
      message: 'Attendance dropped to 88% this month. Please review.',
      category: 'Attendance',
      time: 'Today',
    ),
    NotificationItem(
      title: 'Assignment Reminder',
      message: 'Physics Electrostatics homework is pending for submission.',
      category: 'Assignment',
      time: 'Today',
      isRead: true,
    ),
    NotificationItem(
      title: 'Fee Due Notice',
      message: 'Quarterly fee payment is due on 15 June 2026.',
      category: 'Fee',
      time: 'Yesterday',
    ),
    NotificationItem(
      title: 'Academy Announcement',
      message: 'National NEET Quiz Battle registrations are open now.',
      category: 'Announcement',
      time: '2 days ago',
      isRead: true,
    ),
  ];

  static const settings = <SettingOption>[
    SettingOption(
      title: 'Language Selection',
      subtitle: 'English • Hindi coming soon',
      icon: Icons.language,
    ),
    SettingOption(
      title: 'Notification Preferences',
      subtitle: 'Academic, attendance, exam and fee alerts',
      icon: Icons.notifications_active_outlined,
    ),
    SettingOption(
      title: 'Theme Selection',
      subtitle: 'Light / Dark / System',
      icon: Icons.palette_outlined,
    ),
    SettingOption(
      title: 'Session Information',
      subtitle: 'Trusted devices and access control',
      icon: Icons.security,
    ),
  ];

  static const supportOptions = <SupportOption>[
    SupportOption(
      title: 'Help Center',
      description: 'Guided FAQs for students, parents and teachers.',
      icon: Icons.help_outline,
    ),
    SupportOption(
      title: 'Contact School',
      description: 'Call or message administration for urgent issues.',
      icon: Icons.call_outlined,
    ),
    SupportOption(
      title: 'Raise Support Ticket',
      description: 'Track technical issues and account requests.',
      icon: Icons.support_agent,
    ),
  ];

  static const futureModules = <FutureModule>[
    FutureModule(title: 'Live Classes', icon: Icons.videocam_outlined),
    FutureModule(title: 'AI Tutor', icon: Icons.smart_toy_outlined),
    FutureModule(title: 'Doubt Solving', icon: Icons.forum_outlined),
    FutureModule(title: 'Quiz Battles', icon: Icons.sports_esports_outlined),
    FutureModule(title: 'PTM Booking', icon: Icons.event_available_outlined),
    FutureModule(title: 'Chat System', icon: Icons.chat_bubble_outline),
    FutureModule(title: 'Exams', icon: Icons.menu_book_outlined),
    FutureModule(title: 'Fees', icon: Icons.account_balance_wallet_outlined),
  ];
}
