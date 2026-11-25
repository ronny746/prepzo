class LiveClassModel {
  const LiveClassModel({
    required this.id,
    required this.topic,
    required this.subjectName,
    required this.teacherName,
    required this.startTime,
    required this.endTime,
    required this.meetingLink,
    required this.status,
    required this.participants,
  });

  final String id;
  final String topic;
  final String subjectName;
  final String teacherName;
  final DateTime? startTime;
  final DateTime? endTime;
  final String meetingLink;
  final String status;
  final List<dynamic> participants;

  factory LiveClassModel.fromJson(Map<String, dynamic> json) {
    final tId = json['teacherId'];
    final sId = json['subjectId'] ?? (json['classScheduleId'] != null ? json['classScheduleId']['subjectId'] : null);
    
    return LiveClassModel(
      id: json['_id'] ?? json['id'] ?? '',
      topic: json['topic'] ?? (sId is Map ? sId['name'] : 'Unknown Topic'),
      subjectName: sId is Map ? sId['name'] ?? 'Unknown' : 'Unknown',
      teacherName: tId is Map ? (tId['firstName'] != null ? '${tId['firstName']} ${tId['lastName']}' : tId['name']) ?? 'Unknown' : 'Unknown',
      startTime: json['startTime'] != null ? DateTime.tryParse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime']) : null,
      meetingLink: json['meetingLink'] ?? '',
      status: json['status'] ?? 'scheduled',
      participants: json['participants'] ?? [],
    );
  }
}

class ResourceModel {
  const ResourceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.fileUrl,
    required this.subjectName,
  });

  final String id;
  final String title;
  final String description;
  final String type;
  final String fileUrl;
  final String subjectName;

  factory ResourceModel.fromJson(Map<String, dynamic> json) {
    final sId = json['subjectId'];
    return ResourceModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? 'Untitled Resource',
      description: json['description'] ?? '',
      type: json['type'] ?? 'document',
      fileUrl: json['fileUrl'] ?? '',
      subjectName: sId is Map ? sId['name'] ?? 'Unknown' : 'Unknown',
    );
  }
}

class FeeModel {
  const FeeModel({
    required this.id,
    required this.studentName,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.description,
  });

  final String id;
  final String studentName;
  final num amount;
  final DateTime? dueDate;
  final String status;
  final String description;

  factory FeeModel.fromJson(Map<String, dynamic> json) {
    final sId = json['studentId'];
    return FeeModel(
      id: json['_id'] ?? json['id'] ?? '',
      studentName: sId is Map ? sId['name'] ?? 'Unknown' : 'Unknown',
      amount: json['amount'] ?? 0,
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
      status: json['status'] ?? 'pending',
      description: json['description'] ?? '',
    );
  }
}

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.transactionId,
    required this.studentName,
    required this.courseName,
    required this.batchName,
    required this.amountPaid,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String transactionId;
  final String studentName;
  final String courseName;
  final String batchName;
  final num amountPaid;
  final String paymentMethod;
  final String status;
  final DateTime? createdAt;

  /// Only successful payments have a downloadable receipt.
  bool get hasReceipt => status == 'SUCCESS' && id.isNotEmpty;

  /// File name used when the receipt is saved on the device.
  String get receiptFileName {
    final ref = transactionId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final tail = ref.length > 12 ? ref.substring(ref.length - 12) : ref;
    return 'Prepzo-Receipt-${tail.isEmpty ? 'payment' : tail}.pdf';
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final sId = json['studentId'];
    String sName = 'Student';
    if (sId is Map) {
      final fName = sId['firstName'] ?? '';
      final lName = sId['lastName'] ?? '';
      sName = '$fName $lName'.trim();
      if (sName.isEmpty) sName = sId['name'] ?? 'Student';
    }

    final cId = json['courseId'];
    String cName = json['courseName'] ?? '';
    if (cName.isEmpty && cId is Map) {
      cName = cId['name'] ?? '';
    }
    if (cName.isEmpty) cName = 'General Course';

    final bId = json['batchId'];
    String bName = json['batchName'] ?? '';
    if (bName.isEmpty && bId is Map) {
      final name = bId['name'] ?? '';
      final section = bId['section'];
      bName = '$name${section != null && section.toString().isNotEmpty ? ' (Sec $section)' : ''}';
    }
    if (bName.isEmpty) bName = 'Enrolled Batch';

    final rawTxnId = json['transactionId'];
    final idStr = (json['_id'] ?? json['id'] ?? '').toString();
    final txnId = (rawTxnId != null && rawTxnId.toString().isNotEmpty)
        ? rawTxnId.toString()
        : (idStr.isNotEmpty ? 'REC_${idStr.toUpperCase().substring((idStr.length - 8).clamp(0, idStr.length))}' : 'TXN');

    final rawDate = json['createdAt'] ?? json['dueDate'];
    DateTime? dt;
    if (rawDate != null) {
      dt = DateTime.tryParse(rawDate.toString())?.toLocal();
    }

    final rawStatus = (json['status'] ?? 'SUCCESS').toString().toUpperCase();
    final statusStr = (rawStatus == 'PAID') ? 'SUCCESS' : rawStatus;

    return TransactionModel(
      id: idStr,
      transactionId: txnId,
      studentName: sName,
      courseName: cName,
      batchName: bName,
      amountPaid: json['amountPaid'] ?? json['amountDue'] ?? json['amount'] ?? 0,
      paymentMethod: json['paymentMethod'] ?? 'ONLINE',
      status: statusStr,
      createdAt: dt,
    );
  }
}
