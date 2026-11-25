class CourseAccessModel {
  final bool liveClasses;
  final bool testSeries;
  final bool studyMaterials;
  final bool dpps;

  const CourseAccessModel({
    this.liveClasses = true,
    this.testSeries = true,
    this.studyMaterials = true,
    this.dpps = true,
  });

  factory CourseAccessModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CourseAccessModel();
    return CourseAccessModel(
      liveClasses: json['liveClasses'] as bool? ?? true,
      testSeries: json['testSeries'] as bool? ?? true,
      studyMaterials: json['studyMaterials'] as bool? ?? true,
      dpps: json['dpps'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'liveClasses': liveClasses,
        'testSeries': testSeries,
        'studyMaterials': studyMaterials,
        'dpps': dpps,
      };
}

class CourseModel {
  final String id;

  /// URL name used by the website (`/course/<slug>`).
  final String? slug;
  final String name;
  final String? subtitle;
  final String? description;
  final num fee;
  final num? actualFee;
  final String? targetExam;
  final dynamic year;
  final String? tag;
  final String? duration;
  final String? badge;
  final String? color;
  final List<String> features;
  final List<String> bestFor;
  final CourseAccessModel access;
  final String? startDate;
  final String? endDate;

  const CourseModel({
    required this.id,
    this.slug,
    required this.name,
    this.subtitle,
    this.description,
    this.fee = 0,
    this.actualFee,
    this.targetExam,
    this.year,
    this.tag,
    this.duration,
    this.badge,
    this.color,
    this.features = const [],
    this.bestFor = const [],
    this.access = const CourseAccessModel(),
    this.startDate,
    this.endDate,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString(),
      fee: json['fee'] is num ? json['fee'] : (num.tryParse(json['fee']?.toString() ?? '0') ?? 0),
      actualFee: json['actualFee'] is num ? json['actualFee'] : num.tryParse(json['actualFee']?.toString() ?? ''),
      targetExam: json['targetExam']?.toString(),
      year: json['year'],
      tag: json['tag']?.toString(),
      duration: json['duration']?.toString(),
      badge: json['badge']?.toString(),
      color: json['color']?.toString(),
      slug: json['slug']?.toString(),
      features: (json['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      bestFor: (json['bestFor'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      access: CourseAccessModel.fromJson(json['access'] as Map<String, dynamic>?),
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'subtitle': subtitle,
        'description': description,
        'fee': fee,
        'actualFee': actualFee,
        'targetExam': targetExam,
        'year': year,
        'tag': tag,
        'duration': duration,
        'badge': badge,
        'color': color,
        'features': features,
        'bestFor': bestFor,
        'access': access.toJson(),
        'startDate': startDate,
        'endDate': endDate,
      };
}
