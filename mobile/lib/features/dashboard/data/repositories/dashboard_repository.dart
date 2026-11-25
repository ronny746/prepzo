import 'package:lms/core/network/api_client.dart';
import 'package:lms/core/network/api_exception.dart';
import 'package:lms/features/dashboard/data/models/dashboard_models.dart';
import 'package:lms/features/dashboard/data/models/banner_model.dart';
import 'package:lms/features/profile/data/models/profile_details.dart';

class DashboardRepository {
  DashboardRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<BannerModel>> getBanners() async {
    try {
      final response = await _apiClient.get('/public/banners');
      final List<dynamic> data = response['data'] ?? [];
      return data
          .map((json) => BannerModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching banners: $e');
      return [];
    }
  }

  /// Plan-based feature access. Any failure (404 on an old server, network)
  /// returns all-true so Quick Access shows everything.
  Future<StudentAccess> getAccess(String token) async {
    try {
      final response = await _apiClient.get('/users/me/access', token: token);
      final data = response['data'];
      if (data is Map) {
        return StudentAccess.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
    return const StudentAccess();
  }

  Future<StudentDashboardData> getStudentDashboard({
    required String token,
  }) async {
    if (token.startsWith('mock-')) {
      return StudentDashboardData(
        studentName: 'Aarav Sharma',
        userCode: 'STD-1024',
        role: 'STUDENT',
        course: 'NEET Premium Batch 2027',
        subjects: const ['Physics', 'Chemistry', 'Biology'],
        classes: const [
          DashboardItem(
            title: 'Physics: Electrostatics',
            subtitle: 'Class 12 - Chapter 1',
            value: '70%',
          ),
          DashboardItem(
            title: 'Organic Chemistry: Carbonyls',
            subtitle: 'Class 12 - Chapter 5',
            value: '85%',
          ),
          DashboardItem(
            title: 'Biology: Genetics & Evolution',
            subtitle: 'Class 12 - Chapter 3',
            value: '88%',
          ),
        ],
        schedule: const [
          DashboardItem(
            title: 'Physics Electrostatics Lecture',
            subtitle: '10:00 AM - 11:30 AM',
            tertiary: 'Lecture Hall 2',
          ),
          DashboardItem(
            title: 'Chemistry Doubt Solving',
            subtitle: '01:00 PM - 03:00 PM',
            tertiary: 'Doubt Desk 4',
          ),
        ],
        assignments: const [
          DashboardItem(
            title: "Coulomb's Law Practice Sheet",
            subtitle: 'Due in 2 days',
            status: 'pending',
          ),
          DashboardItem(
            title: 'Hydrocarbons Chapter Report',
            subtitle: 'Submitted',
            status: 'success',
          ),
        ],
        attendance: const [
          DashboardItem(
            title: 'June Attendance',
            subtitle: 'Present: 22, Absent: 2',
            value: '91%',
          ),
        ],
        fees: const [
          DashboardItem(
            title: 'Tuition Fee - Term 1',
            subtitle: 'Due Date: 15 July',
            value: '₹12,500',
            status: 'PENDING',
          ),
        ],
        exams: const [
          DashboardItem(
            title: 'NEET Grand Full Syllabus Mock #15',
            subtitle: 'Upcoming: Tomorrow',
            value: '200 Qs',
          ),
        ],
        results: const [
          DashboardItem(
            title: 'Electrochemistry Quiz 1',
            subtitle: 'Grade: A',
            value: '88%',
          ),
          DashboardItem(
            title: 'Genetics & Heredity Test',
            subtitle: 'Grade: A',
            value: '92%',
          ),
        ],
        performance: const {
          'gpa': '88%',
          'attendance': '94%',
          'rank': '#12',
          'points': '850',
        },
        announcements: const [
          DashboardItem(
            title: 'NEET 2027 Ultimate Rankers Course',
            subtitle:
                'Enrollments are now open! Exclusive 40% discount for registered students.',
          ),
          DashboardItem(
            title: 'Summer Vacation Schedule',
            subtitle:
                'Academy will remain closed from 15th to 30th May for summer holidays.',
          ),
        ],
        activities: const [
          DashboardItem(
            title: 'Exam Completed',
            subtitle: 'Electrochemistry Quiz 1',
            status: 'success',
          ),
          DashboardItem(
            title: 'New Announcement',
            subtitle: 'NEET 2027 Ultimate Rankers Course',
            status: 'warning',
          ),
        ],
      );
    }

    final profileFuture = _loadProfile(token);
    final classesFuture = _safeGet('/batches/my-batches', token: token);
    final scheduleFuture = _safeGet('/classes-schedule', token: token);
    final liveFuture = _safeGet('/live-classes?status=ONGOING', token: token);
    final performanceFuture = _safeGet(
      '/analytics-reports/student/me/performance',
      token: token,
    );
    final mentorSessionsFuture = _safeGet(
      '/operations/mentor-sessions/my',
      token: token,
    );

    final results = await Future.wait([
      profileFuture,
      classesFuture,
      scheduleFuture,
      liveFuture,
      performanceFuture,
      mentorSessionsFuture,
    ]);

    final profile = results[0] as ProfileDetails;
    final classesResult = results[1] as _EndpointResult;
    final scheduleResult = results[2] as _EndpointResult;
    final liveResult = results[3] as _EndpointResult;
    final performanceResult = results[4] as _EndpointResult;
    final mentorSessionsResult = results[5] as _EndpointResult;

    final Map<String, dynamic> perfData =
        performanceResult.data is Map<String, dynamic>
        ? performanceResult.data as Map<String, dynamic>
        : {};

    final enrolledBatchesList = _extractList(classesResult.data);
    final rawScheduleList = _extractList(scheduleResult.data);
    final rawLiveList = _extractList(liveResult.data);

    final parsedClasses = _parseStudentClasses(enrolledBatchesList);
    final parsedSchedule = _parseSchedule(
      scheduleList: rawScheduleList,
      liveList: rawLiveList,
      enrolledBatches: enrolledBatchesList,
    );

    // The dashboard must reflect the student's actual enrollment. Do not
    // manufacture a NEET/JEE course when the institute has not assigned one.
    final courseName = parsedClasses.isNotEmpty
        ? parsedClasses.first.title
        : 'No course assigned yet';

    final List<String> subjectsList = [];
    for (var item in parsedClasses) {
      final parts = item.title.split(':');
      final title = parts.isNotEmpty ? parts.first.trim() : '';
      if (title.isNotEmpty &&
          !subjectsList.contains(title) &&
          title.length < 20) {
        subjectsList.add(title);
      }
    }

    return StudentDashboardData(
      studentName: profile.name,
      userCode: profile.userCode,
      role: profile.role,
      course: courseName,
      subjects: subjectsList,
      classes: parsedClasses,
      schedule: parsedSchedule,
      assignments: const [],
      attendance: const [],
      fees: const [],
      exams: const [],
      results: const [],
      performance: const {},
      performanceData: perfData,
      mentorSessions: _parseMentorSessions(
        _extractList(mentorSessionsResult.data),
      ),
      access: classesResult.error == null
          ? StudentFeatureAccess.fromBatches(enrolledBatchesList)
          : const StudentFeatureAccess.unknown(),
      announcements: const [],
      activities: const [],
      classesError: classesResult.error,
      scheduleError: scheduleResult.error,
    );
  }

  List<MentorSessionItem> _parseMentorSessions(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map((session) {
      final mentor = session['mentorId'];
      final course = session['courseId'];
      final batch = session['batchId'];
      return MentorSessionItem(
        id: session['_id']?.toString() ?? '',
        mentorName: mentor is Map<String, dynamic>
            ? mentor['name']?.toString() ?? 'Mentor'
            : 'Mentor',
        audienceName: course is Map<String, dynamic>
            ? course['name']?.toString() ?? 'Your course'
            : (batch is Map<String, dynamic>
                  ? batch['name']?.toString() ?? 'Your batch'
                  : 'Your mentor session'),
        startAt: DateTime.tryParse(session['startAt']?.toString() ?? ''),
        meetingLink: session['meetingLink']?.toString() ?? '',
      );
    }).toList();
  }

  List<DashboardItem> _parseAnnouncements(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map((item) {
      return DashboardItem(
        title: item['title']?.toString() ?? 'Notification',
        subtitle: item['message']?.toString() ?? '',
        tertiary: item['createdAt']?.toString(),
      );
    }).toList();
  }

  List<DashboardItem> _synthesizeActivities(
    List<dynamic> assignments,
    List<dynamic> results,
  ) {
    final List<DashboardItem> acts = [];

    for (var a in assignments.take(2)) {
      if (a is Map<String, dynamic>) {
        acts.add(
          DashboardItem(
            title: 'Assignment Updated',
            subtitle: a['title']?.toString() ?? 'Recent assignment',
            status: 'warning',
          ),
        );
      }
    }

    for (var r in results.take(2)) {
      if (r is Map<String, dynamic>) {
        acts.add(
          DashboardItem(
            title: 'Result Published',
            subtitle: '${r['examTitle'] ?? 'Exam'} - ${r['grade'] ?? 'A'}',
            status: 'success',
          ),
        );
      }
    }

    return acts;
  }

  Map<String, String> _calculatePerformance(
    List<dynamic> attendance,
    List<dynamic> results,
    String studentId,
  ) {
    // Simple mock calculation logic
    double attendanceRate = 0;
    if (attendance.isNotEmpty) {
      int presentCount = 0;
      for (var day in attendance) {
        final records = day['records'] as List?;
        final myRecord = records?.firstWhere(
          (r) => r['studentId']?.toString() == studentId,
          orElse: () => null,
        );
        if (myRecord?['status'] == 'present') presentCount++;
      }
      attendanceRate = (presentCount / attendance.length) * 100;
    }

    return {
      'attendance': '${attendanceRate.toStringAsFixed(0)}%',
      'gpa': results.isEmpty ? 'N/A' : '3.8',
      'rank': results.isEmpty ? 'N/A' : '5th',
      'points': results.isEmpty ? '0' : '1240',
    };
  }

  List<DashboardItem> _parseFees(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map((item) {
      return DashboardItem(
        title: item['title']?.toString() ?? 'Tuition Fee',
        subtitle: 'Due: ${item['dueDate'] ?? 'N/A'}',
        value: '₹${item['amount'] ?? '0'}',
        status: item['status']?.toString().toUpperCase() ?? 'PENDING',
      );
    }).toList();
  }

  List<DashboardItem> _parseExams(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map((item) {
      return DashboardItem(
        title: item['title']?.toString() ?? 'Final Exam',
        subtitle: '${item['subject'] ?? 'All Subjects'}',
        tertiary: 'Date: ${item['date'] ?? 'Upcoming'}',
      );
    }).toList();
  }

  List<DashboardItem> _parseResults(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map((item) {
      return DashboardItem(
        title: item['examTitle']?.toString() ?? 'Unit Test',
        subtitle: item['subject']?.toString() ?? 'General',
        value: '${item['marks'] ?? '0'}/${item['totalMarks'] ?? '100'}',
        status: item['grade']?.toString() ?? 'A',
      );
    }).toList();
  }

  Future<TeacherDashboardData> getTeacherDashboard({
    required String token,
  }) async {
    final profile = await _loadProfile(token);

    // These are the server routes available to a teacher. The previous
    // implementation requested legacy routes (/classes, /sections and
    // /student-enrollments) that do not exist, then tried to cast their error
    // payloads to List. That produced the generic dashboard load failure.
    final subjectsResult = await _safeGet('/subjects', token: token);
    final classesResult = await _safeGet('/batches/my-batches', token: token);
    final sectionsResult = await _safeGet(
      '/classes-schedule/my-schedule',
      token: token,
    );
    final studentsResult = await _safeGet(
      '/users',
      token: token,
      queryParameters: {'role': 'student'},
    );
    final enrollmentsResult = await _safeGet(
      '/live-classes?status=ONGOING',
      token: token,
    );

    return TeacherDashboardData(
      teacherName: profile.name,
      userCode: profile.userCode,
      role: profile.role,
      subjects: _parseSubjects(_extractList(subjectsResult.data)),
      classes: _parseSimpleList(
        _extractList(classesResult.data),
        'name',
        'section',
      ),
      sections: _parseTeacherSchedule(_extractList(sectionsResult.data)),
      students: _parseUsers(_extractList(studentsResult.data)),
      enrollments: _parseLiveClasses(_extractList(enrollmentsResult.data)),
      subjectsError: subjectsResult.error,
      classesError: classesResult.error,
      sectionsError: sectionsResult.error,
      studentsError: studentsResult.error,
      enrollmentsError: enrollmentsResult.error,
    );
  }

  Future<ParentDashboardData> getParentDashboard({
    required String token,
  }) async {
    final profileFuture = _safeGet('/users/me', token: token);
    final ptmFuture = _safeGet('/ptm-booking/slots', token: token);
    final feesFuture = _safeGet('/fees-payments/my-children', token: token);
    final hwFuture = _safeGet('/homework/my-children', token: token);
    final dashFuture = _safeGet('/dashboard', token: token);

    final results = await Future.wait([
      profileFuture,
      ptmFuture,
      feesFuture,
      hwFuture,
      dashFuture,
    ]);

    final meResult = results[0];
    final ptmResult = results[1];
    final feesResult = results[2];
    final hwResult = results[3];
    final dashResult = results[4];

    String parentName = 'Parent';
    dynamic rawChildren;

    if (meResult.data is Map<String, dynamic>) {
      final meData = meResult.data as Map<String, dynamic>;
      final userObj = meData['user'] is Map<String, dynamic>
          ? meData['user'] as Map<String, dynamic>
          : meData;
      final firstName = userObj['firstName']?.toString() ?? '';
      final lastName = userObj['lastName']?.toString() ?? '';
      parentName = '$firstName $lastName'.trim();
      if (parentName.isEmpty)
        parentName = userObj['name']?.toString() ?? 'Parent';

      if (userObj['childrenIds'] is List &&
          (userObj['childrenIds'] as List).isNotEmpty) {
        rawChildren = userObj['childrenIds'];
      }
    }

    if ((rawChildren == null || (rawChildren is List && rawChildren.isEmpty)) &&
        dashResult.data is Map<String, dynamic>) {
      final dashData = dashResult.data as Map<String, dynamic>;
      rawChildren = dashData['wards'] ?? dashData['children'];
    }

    final children = _parseChildrenList(rawChildren ?? []);

    int upcomingPTM = 0;
    if (ptmResult.data is List) {
      for (var slot in ptmResult.data) {
        if (slot is Map<String, dynamic> && slot['isBooked'] == true) {
          upcomingPTM++;
        }
      }
    }

    double pendingFees = 0;
    if (feesResult.data is List) {
      for (var fee in feesResult.data) {
        if (fee is Map<String, dynamic>) {
          pendingFees += (fee['amountDue'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    int pendingHomework = (hwResult.data is List)
        ? (hwResult.data as List).length
        : 0;

    return ParentDashboardData(
      parentName: parentName.isNotEmpty ? parentName : 'Parent',
      children: children,
      upcomingPTM: upcomingPTM,
      pendingFees: pendingFees,
      pendingHomework: pendingHomework,
      childrenError: meResult.error,
    );
  }

  Future<void> linkStudent({
    required String token,
    required String identifier,
  }) async {
    final cleanIdentifier = identifier.trim();
    try {
      await _apiClient.post(
        '/users/link-parent-student',
        token: token,
        data: {
          'identifier': cleanIdentifier,
          'rollNo': cleanIdentifier,
          'phone': cleanIdentifier,
        },
      );
    } catch (_) {
      try {
        await _apiClient.put(
          '/users/me',
          token: token,
          data: {'linkStudentIdentifier': cleanIdentifier},
        );
      } catch (_) {}
    }
  }

  /// Topic-level flags are the source of truth for the student/parent remedy view.
  Future<List<Map<String, dynamic>>> getTopicFlags({
    required String token,
    String? childId,
  }) async {
    final path = childId == null
        ? '/performance-flags/me'
        : '/performance-flags/children/$childId';
    final response = await _apiClient.get(path, token: token);
    final raw = response['data'] ?? response;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((flag) => Map<String, dynamic>.from(flag))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getStudentAttendance({
    required String token,
  }) async {
    if (token.startsWith('mock-')) {
      return const [];
    }
    try {
      final response = await _apiClient.get(
        '/attendance/my-attendance',
        token: token,
      );
      final raw = response['data'] ?? response;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((reg) => Map<String, dynamic>.from(reg))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<DashboardItem> _parseChildrenList(dynamic rawList) {
    if (rawList is! List) return [];
    return rawList.whereType<Map<String, dynamic>>().map((c) {
      final firstName = c['firstName']?.toString() ?? '';
      final lastName = c['lastName']?.toString() ?? '';
      final name = '$firstName $lastName'.trim();
      final phone = c['phone']?.toString() ?? '';
      final metadata = c['metadata'] is Map<String, dynamic>
          ? (c['metadata'] as Map<String, dynamic>)
          : <String, dynamic>{};
      final cls =
          metadata['class']?.toString() ??
          metadata['studentClass']?.toString() ??
          '';
      final sec = metadata['section']?.toString() ?? '';
      final classSec = [cls, if (sec.isNotEmpty) '- $sec'].join(' ').trim();
      final rollNo = metadata['rollNo']?.toString() ?? '';
      final avatar = c['profilePictureUrl']?.toString() ?? '';
      final id = (c['_id'] ?? c['id'])?.toString();

      return DashboardItem(
        title: name.isNotEmpty ? name : 'Child',
        subtitle: phone,
        tertiary: classSec,
        value: rollNo,
        status: avatar,
        id: id,
      );
    }).toList();
  }

  Future<ProfileDetails> _loadProfile(String token) async {
    try {
      final response = await _apiClient.get('/users/me', token: token);
      final data = response['data'];
      final user = response['user'];

      if (data is Map<String, dynamic>) {
        if (data.containsKey('user') && data['user'] is Map<String, dynamic>) {
          return ProfileDetails.fromJson(data['user'] as Map<String, dynamic>);
        }
        return ProfileDetails.fromJson(data);
      }

      if (user is Map<String, dynamic>) {
        return ProfileDetails.fromJson(user);
      }

      return ProfileDetails.fromJson(response);
    } catch (e) {
      print('Warning: /me endpoint failed, using fallback empty profile: $e');
      return const ProfileDetails(
        id: '',
        name: 'Student',
        email: '',
        mobile: '',
        role: 'STUDENT',
        userCode: '',
        gender: '',
        status: '',
        instituteId: '',
        branchId: '',
        address: '',
      );
    }
  }

  Future<_EndpointResult> _safeGet(
    String path, {
    required String token,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _apiClient.get(
        path,
        token: token,
        queryParameters: queryParameters,
      );
      final rawData = response['data'] ?? response;
      return _EndpointResult(data: rawData);
    } on ApiException catch (error) {
      print('Dashboard Section Error [$path]: ${error.message}');
      return _EndpointResult(data: null, error: error.message);
    } catch (e) {
      print('Dashboard Section Unexpected Error [$path]: $e');
      return const _EndpointResult(
        data: null,
        error: 'Unable to load this section.',
      );
    }
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) return data;
      final items = response['items'];
      if (items is List) return items;
    }
    return const <dynamic>[];
  }

  List<DashboardItem> _parseStudentClasses(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map((item) {
      return DashboardItem(
        title: item['name']?.toString() ?? 'Class',
        subtitle: 'Section ${item['section'] ?? 'N/A'}',
        tertiary: item['type']?.toString().toUpperCase(),
      );
    }).toList();
  }

  List<DashboardItem> _parseSchedule({
    required List<dynamic> scheduleList,
    required List<dynamic> liveList,
    required List<dynamic> enrolledBatches,
  }) {
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final enrolledBatchIds = <String>{};
    final enrolledCourseNames = <String>{};

    for (var b in enrolledBatches) {
      if (b is Map<String, dynamic>) {
        if (b['_id'] != null) enrolledBatchIds.add(b['_id'].toString());
        if (b['id'] != null) enrolledBatchIds.add(b['id'].toString());
        if (b['batchId'] != null) {
          final bId = b['batchId'] is Map ? b['batchId']['_id'] : b['batchId'];
          if (bId != null) enrolledBatchIds.add(bId.toString());
        }
        if (b['courseId'] != null) {
          final cId = b['courseId'] is Map
              ? b['courseId']['_id']
              : b['courseId'];
          if (cId != null) enrolledBatchIds.add(cId.toString());
          final cName = b['courseId'] is Map ? b['courseId']['name'] : null;
          if (cName != null)
            enrolledCourseNames.add(cName.toString().trim().toLowerCase());
        }
        if (b['name'] != null)
          enrolledCourseNames.add(b['name'].toString().trim().toLowerCase());
        if (b['courseName'] != null)
          enrolledCourseNames.add(
            b['courseName'].toString().trim().toLowerCase(),
          );
      }
    }

    final items = <DashboardItem>[];

    // 1. Add ONGOING live classes for enrolled courses at the top
    for (var lc in liveList) {
      if (lc is! Map<String, dynamic>) continue;
      final scheduleObj = lc['classScheduleId'] is Map
          ? lc['classScheduleId']
          : {};
      final batchObj = scheduleObj['batchId'] is Map
          ? scheduleObj['batchId']
          : {};
      final classObj = scheduleObj['classId'] is Map
          ? scheduleObj['classId']
          : {};
      final subjectObj = scheduleObj['subjectId'] is Map
          ? scheduleObj['subjectId']
          : {};
      final teacherObj = lc['teacherId'] is Map ? lc['teacherId'] : {};

      final batchId = (batchObj['_id'] ?? batchObj['id'] ?? lc['batchId'])
          ?.toString();
      final courseName =
          (classObj['name'] ?? batchObj['name'] ?? subjectObj['name'])
              ?.toString()
              .trim()
              .toLowerCase();

      bool isEnrolled = enrolledBatchIds.isEmpty && enrolledCourseNames.isEmpty;
      if (batchId != null && enrolledBatchIds.contains(batchId))
        isEnrolled = true;
      if (courseName != null &&
          enrolledCourseNames.any(
            (cn) => cn.contains(courseName) || courseName.contains(cn),
          ))
        isEnrolled = true;

      if (isEnrolled) {
        final subjectName =
            subjectObj['name']?.toString() ??
            classObj['name']?.toString() ??
            'Live Class';
        final teacherName =
            '${teacherObj['firstName'] ?? ''} ${teacherObj['lastName'] ?? ''}'
                .trim();
        final link =
            lc['meetingLink']?.toString() ??
            lc['startUrl']?.toString() ??
            lc['roomCode']?.toString() ??
            lc['_id']?.toString();

        items.add(
          DashboardItem(
            title: subjectName,
            subtitle: teacherName.isNotEmpty
                ? 'Live Now • $teacherName'
                : 'Live Session in Progress',
            tertiary: 'LIVE NOW',
            status: 'ONGOING',
            value: link,
            id: lc['_id']?.toString() ?? lc['id']?.toString(),
          ),
        );
      }
    }

    // 2. Add recurring schedules matching enrolled courses
    final filteredSchedule = scheduleList
        .whereType<Map<String, dynamic>>()
        .where((item) {
          if (enrolledBatchIds.isEmpty && enrolledCourseNames.isEmpty)
            return true;
          final batch = item['batchId'];
          final batchId = (batch is Map ? (batch['_id'] ?? batch['id']) : batch)
              ?.toString();
          final course = item['courseId'];
          final courseId =
              (course is Map ? (course['_id'] ?? course['id']) : course)
                  ?.toString();
          final subject = item['subjectId'];
          final subjectName =
              (subject is Map ? subject['name'] : item['subjectName'])
                  ?.toString()
                  .trim()
                  .toLowerCase();

          if (batchId != null && enrolledBatchIds.contains(batchId))
            return true;
          if (courseId != null && enrolledBatchIds.contains(courseId))
            return true;
          if (subjectName != null &&
              enrolledCourseNames.any(
                (cn) => cn.contains(subjectName) || subjectName.contains(cn),
              ))
            return true;

          if (batchId != null || courseId != null) {
            return enrolledBatchIds.contains(batchId) ||
                enrolledBatchIds.contains(courseId);
          }
          return true;
        })
        .toList();

    for (var item in filteredSchedule) {
      final teacher = item['teacherId'];
      String teacherName = 'Teacher';
      if (teacher is Map<String, dynamic>) {
        teacherName =
            '${teacher['firstName'] ?? ''} ${teacher['lastName'] ?? ''}'.trim();
      }
      final subject = item['subjectId'];
      String subjectName = '';
      if (subject is Map<String, dynamic>) {
        subjectName = subject['name']?.toString() ?? '';
      } else if (item['subjectName'] != null) {
        subjectName = item['subjectName'].toString();
      }

      final int? dayIdx = item['dayOfWeek'] as int?;
      final day = (dayIdx != null && dayIdx >= 0 && dayIdx < days.length)
          ? days[dayIdx]
          : '';
      final link =
          item['meetingLink']?.toString() ??
          item['startUrl']?.toString() ??
          item['roomCode']?.toString() ??
          item['_id']?.toString();

      items.add(
        DashboardItem(
          title: subjectName.isNotEmpty
              ? subjectName
              : '${item['startTime']} - ${item['endTime']}',
          subtitle:
              '${item['startTime']} - ${item['endTime']}' +
              (teacherName.isNotEmpty ? ' • $teacherName' : ''),
          tertiary: day.isNotEmpty ? day : 'Scheduled',
          status: item['status']?.toString() ?? 'SCHEDULED',
          value: link,
          id: item['_id']?.toString() ?? item['id']?.toString(),
        ),
      );
    }

    return items;
  }

  List<DashboardItem> _parseAssignments(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map((item) {
      final dueDateStr = item['dueDate']?.toString() ?? '';
      String formattedDate = '';
      if (dueDateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dueDateStr);
          formattedDate = '${date.day}/${date.month}';
        } catch (_) {
          formattedDate = dueDateStr;
        }
      }

      return DashboardItem(
        title: item['title']?.toString() ?? 'Assignment',
        subtitle: 'Due: $formattedDate',
        tertiary: 'Marks: ${item['maxMarks'] ?? 'N/A'}',
      );
    }).toList();
  }

  List<DashboardItem> _parseAttendance(List<dynamic> list, String studentId) {
    return list.whereType<Map<String, dynamic>>().map((item) {
      final records = item['records'] as List?;
      final myRecord = records?.firstWhere(
        (r) => r['studentId']?.toString() == studentId,
        orElse: () => null,
      );

      final dateStr = item['date']?.toString() ?? '';
      String formattedDate = '';
      if (dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          formattedDate = '${date.day}/${date.month}';
        } catch (_) {
          formattedDate = dateStr;
        }
      }

      return DashboardItem(
        title: formattedDate,
        subtitle: myRecord?['status']?.toString().toUpperCase() ?? 'PENDING',
      );
    }).toList();
  }

  List<DashboardItem> _parseEnrollments(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map((item) {
      final className = _readNestedName(item['classId'], fallback: 'Class');
      final sectionName = _readNestedName(
        item['sectionId'],
        fallback: 'Section',
      );
      final rollNumber = item['rollNumber']?.toString() ?? 'N/A';
      return DashboardItem(
        title: className,
        subtitle: '$sectionName • Roll $rollNumber',
        tertiary: item['status']?.toString(),
      );
    }).toList();
  }

  List<DashboardItem> _parseSubjects(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map((item) {
      // Current API returns the subject itself; subjectId is retained for
      // backward compatibility with older subject-assignment records.
      final subject = item['subjectId'] ?? item;
      final teacher = item['teacherId'];
      return DashboardItem(
        title: _readNestedName(subject, fallback: 'Subject'),
        subtitle: _readNestedCode(subject).isNotEmpty
            ? _readNestedCode(subject)
            : item['batchId'] is Map
            ? _readNestedName(item['batchId'], fallback: '')
            : '',
        tertiary: _readNestedName(teacher, fallback: ''),
      );
    }).toList();
  }

  List<DashboardItem> _parseTeacherSchedule(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map((item) {
      final subject = item['subjectId'];
      final batch = item['batchId'];
      final time =
          '${item['startTime'] ?? '--:--'} - ${item['endTime'] ?? '--:--'}';
      return DashboardItem(
        title: _readNestedName(subject, fallback: 'Scheduled class'),
        subtitle: time,
        tertiary: _readNestedName(batch, fallback: ''),
      );
    }).toList();
  }

  List<DashboardItem> _parseLiveClasses(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map((item) {
      final schedule = item['classScheduleId'];
      final batch = schedule is Map<String, dynamic>
          ? schedule['batchId']
          : null;
      final subject = schedule is Map<String, dynamic>
          ? schedule['subjectId']
          : null;
      return DashboardItem(
        title: _readNestedName(subject, fallback: 'Live class'),
        subtitle: _readNestedName(batch, fallback: 'In progress'),
        tertiary: item['roomCode']?.toString(),
      );
    }).toList();
  }

  List<DashboardItem> _parseUsers(List<dynamic> list) {
    return list.whereType<Map<String, dynamic>>().map((item) {
      return DashboardItem(
        title: '${item['firstName'] ?? ''} ${item['lastName'] ?? ''}'.trim(),
        subtitle: item['email']?.toString() ?? '',
        tertiary: item['role']?.toString().toUpperCase(),
      );
    }).toList();
  }

  List<DashboardItem> _parseSimpleList(
    List<dynamic> list,
    String titleKey,
    String subtitleKey,
  ) {
    return list.whereType<Map<String, dynamic>>().map((item) {
      return DashboardItem(
        title: item[titleKey]?.toString() ?? 'Item',
        subtitle: item[subtitleKey]?.toString() ?? '',
      );
    }).toList();
  }

  String _readNestedName(dynamic value, {required String fallback}) {
    if (value is Map<String, dynamic>) {
      return value['name']?.toString() ??
          value['title']?.toString() ??
          value['code']?.toString() ??
          fallback;
    }
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return fallback;
  }

  String _readNestedCode(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value['code']?.toString() ?? '';
    }
    return '';
  }
}

class _EndpointResult {
  const _EndpointResult({required this.data, this.error});

  final dynamic data;
  final String? error;
}
