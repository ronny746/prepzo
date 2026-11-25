class DashboardItem {
  const DashboardItem({
    required this.title,
    required this.subtitle,
    this.tertiary,
    this.status,
    this.value,
    this.id,
  });

  final String title;
  final String subtitle;
  final String? tertiary;
  final String? status;
  final String? value;
  final String? id;
}

class MentorSessionItem {
  const MentorSessionItem({
    required this.id,
    required this.mentorName,
    required this.audienceName,
    required this.startAt,
    required this.meetingLink,
  });

  final String id;
  final String mentorName;
  final String audienceName;
  final DateTime? startAt;
  final String meetingLink;
}

class StudentDashboardData {
  const StudentDashboardData({
    required this.studentName,
    required this.userCode,
    required this.role,
    required this.course,
    required this.subjects,
    required this.classes,
    required this.schedule,
    required this.assignments,
    required this.attendance,
    required this.fees,
    required this.exams,
    required this.results,
    required this.performance,
    this.performanceData = const {},
    this.mentorSessions = const [],
    required this.announcements,
    required this.activities,
    this.classesError,
    this.scheduleError,
    this.assignmentsError,
    this.attendanceError,
    this.feesError,
    this.examsError,
    this.resultsError,
  });

  final String studentName;
  final String userCode;
  final String role;
  final String course;
  final List<String> subjects;
  final List<DashboardItem> classes;
  final List<DashboardItem> schedule;
  final List<DashboardItem> assignments;
  final List<DashboardItem> attendance;
  final List<DashboardItem> fees;
  final List<DashboardItem> exams;
  final List<DashboardItem> results;
  final Map<String, String> performance;
  final Map<String, dynamic> performanceData;
  final List<MentorSessionItem> mentorSessions;
  final List<DashboardItem> announcements;
  final List<DashboardItem> activities;

  final String? classesError;
  final String? scheduleError;
  final String? assignmentsError;
  final String? attendanceError;
  final String? feesError;
  final String? examsError;
  final String? resultsError;
}

class TeacherDashboardData {
  const TeacherDashboardData({
    required this.teacherName,
    required this.userCode,
    required this.role,
    required this.subjects,
    required this.classes,
    required this.sections,
    required this.students,
    required this.enrollments,
    this.subjectsError,
    this.classesError,
    this.sectionsError,
    this.studentsError,
    this.enrollmentsError,
  });

  final String teacherName;
  final String userCode;
  final String role;
  final List<DashboardItem> subjects;
  final List<DashboardItem> classes;
  final List<DashboardItem> sections;
  final List<DashboardItem> students;
  final List<DashboardItem> enrollments;
  final String? subjectsError;
  final String? classesError;
  final String? sectionsError;
  final String? studentsError;
  final String? enrollmentsError;
}

class ParentDashboardData {
  const ParentDashboardData({
    required this.parentName,
    required this.children,
    required this.upcomingPTM,
    required this.pendingFees,
    required this.pendingHomework,
    this.childrenError,
  });

  final String parentName;
  final List<DashboardItem> children;
  final int upcomingPTM;
  final double pendingFees;
  final int pendingHomework;
  final String? childrenError;
}

/// Which Quick Access areas the student's plan unlocks (`GET /users/me/access`).
/// Defaults to everything on: an old server or failed call must never hide features.
class StudentAccess {
  const StudentAccess({
    this.liveClasses = true,
    this.studyMaterials = true,
    this.dpps = true,
    this.testSeries = true,
  });

  final bool liveClasses;
  final bool studyMaterials;
  final bool dpps;
  final bool testSeries;

  factory StudentAccess.fromJson(Map<String, dynamic> json) {
    // Only an explicit `false` hides a feature; a missing key stays visible.
    bool flag(String k) => json[k] != false;
    return StudentAccess(
      liveClasses: flag('liveClasses'),
      studyMaterials: flag('studyMaterials'),
      dpps: flag('dpps'),
      testSeries: flag('testSeries'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StudentAccess &&
      other.liveClasses == liveClasses &&
      other.studyMaterials == studyMaterials &&
      other.dpps == dpps &&
      other.testSeries == testSeries;

  @override
  int get hashCode =>
      Object.hash(liveClasses, studyMaterials, dpps, testSeries);
}
