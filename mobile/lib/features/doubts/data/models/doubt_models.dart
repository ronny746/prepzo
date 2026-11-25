class DoubtBatchModel {
  final String id;
  final String name;
  final String section;

  DoubtBatchModel({
    required this.id,
    required this.name,
    required this.section,
  });

  factory DoubtBatchModel.fromJson(Map<String, dynamic> json) {
    return DoubtBatchModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Batch',
      section: json['section']?.toString() ?? '',
    );
  }
}

class TeacherModel {
  final String id;
  final String firstName;
  final String lastName;
  final String name;

  TeacherModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.name,
  });

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    final fn = json['firstName']?.toString() ?? '';
    final ln = json['lastName']?.toString() ?? '';
    final fnLn = [fn, ln].where((s) => s.isNotEmpty).join(' ');
    final full = fnLn.isNotEmpty ? fnLn : (json['name']?.toString() ?? 'Teacher');

    return TeacherModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      firstName: fn.isNotEmpty ? fn : full,
      lastName: ln,
      name: full,
    );
  }
}

class DoubtModel {
  final String id;
  final String studentId;
  final String studentName;
  final String teacherId;
  final String teacherName;
  final String batchId;
  final String question;
  final List<String> attachments;
  final String? solution;
  final List<String> solutionAttachments;
  final String status;
  final DateTime createdAt;

  DoubtModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.teacherName,
    required this.batchId,
    required this.question,
    required this.attachments,
    this.solution,
    required this.solutionAttachments,
    required this.status,
    required this.createdAt,
  });

  factory DoubtModel.fromJson(Map<String, dynamic> json) {
    String sId = '';
    String sName = 'Student';
    if (json['studentId'] is Map<String, dynamic>) {
      final sMap = json['studentId'] as Map<String, dynamic>;
      sId = sMap['_id']?.toString() ?? sMap['id']?.toString() ?? '';
      final fn = sMap['firstName']?.toString() ?? '';
      final ln = sMap['lastName']?.toString() ?? '';
      final combined = [fn, ln].where((s) => s.isNotEmpty).join(' ');
      sName = combined.isNotEmpty ? combined : (sMap['name']?.toString() ?? 'Student');
    } else if (json['studentId'] != null) {
      sId = json['studentId'].toString();
    }

    String tId = '';
    String tName = 'Teacher';
    if (json['teacherId'] is Map<String, dynamic>) {
      final tMap = json['teacherId'] as Map<String, dynamic>;
      tId = tMap['_id']?.toString() ?? tMap['id']?.toString() ?? '';
      final fn = tMap['firstName']?.toString() ?? '';
      final ln = tMap['lastName']?.toString() ?? '';
      final combined = [fn, ln].where((s) => s.isNotEmpty).join(' ');
      tName = combined.isNotEmpty ? combined : (tMap['name']?.toString() ?? 'Teacher');
    } else if (json['teacherId'] != null) {
      tId = json['teacherId'].toString();
    }

    String bId = '';
    if (json['batchId'] is Map<String, dynamic>) {
      bId = json['batchId']['_id']?.toString() ?? json['batchId']['id']?.toString() ?? '';
    } else if (json['batchId'] != null) {
      bId = json['batchId'].toString();
    }

    final attList = <String>[];
    if (json['attachments'] is List) {
      for (final item in json['attachments'] as List) {
        if (item != null) attList.add(item.toString());
      }
    }

    final solAttList = <String>[];
    if (json['solutionAttachments'] is List) {
      for (final item in json['solutionAttachments'] as List) {
        if (item != null) solAttList.add(item.toString());
      }
    }

    DateTime createdDate = DateTime.now();
    if (json['createdAt'] != null) {
      createdDate = DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now();
    }

    return DoubtModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      studentId: sId,
      studentName: sName,
      teacherId: tId,
      teacherName: tName,
      batchId: bId,
      question: json['question']?.toString() ?? '',
      attachments: attList,
      solution: json['solution']?.toString(),
      solutionAttachments: solAttList,
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      createdAt: createdDate,
    );
  }
}
