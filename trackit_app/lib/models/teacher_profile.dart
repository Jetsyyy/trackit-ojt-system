class TeacherProfile {
  final String name;
  final String email;
  final String position;
  final String? photoUrl;
  final List<String> programs;
  final List<String> sections;
  final String status;
  final DateTime? lastLoginAt;
  final DateTime? passwordChangedAt;
  final List<AccountActivity> activity;

  const TeacherProfile({
    required this.name,
    required this.email,
    required this.position,
    this.photoUrl,
    required this.programs,
    required this.sections,
    this.status = 'active',
    this.lastLoginAt,
    this.passwordChangedAt,
    this.activity = const [],
  });

  factory TeacherProfile.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) => json[key] != null ? DateTime.parse(json[key] as String) : null;
    return TeacherProfile(
      name: json['name'] as String,
      email: json['email'] as String,
      position: json['position'] as String,
      photoUrl: json['photoUrl'] as String?,
      programs: (json['programs'] as List<dynamic>).cast<String>(),
      sections: (json['sections'] as List<dynamic>).cast<String>(),
      status: json['status'] as String? ?? 'active',
      lastLoginAt: date('lastLoginAt'),
      passwordChangedAt: date('passwordChangedAt'),
      activity: ((json['activity'] as List<dynamic>?) ?? const [])
          .map((e) => AccountActivity.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  TeacherProfile copyWith({String? photoUrl, String? email}) {
    return TeacherProfile(
      name: name,
      email: email ?? this.email,
      position: position,
      photoUrl: photoUrl ?? this.photoUrl,
      programs: programs,
      sections: sections,
      status: status,
      lastLoginAt: lastLoginAt,
      passwordChangedAt: passwordChangedAt,
      activity: activity,
    );
  }
}

/// One row of Profile > Recent Account Activity.
class AccountActivity {
  final String action;
  final String? detail;
  final DateTime at;

  const AccountActivity({required this.action, this.detail, required this.at});

  factory AccountActivity.fromJson(Map<String, dynamic> json) {
    return AccountActivity(
      action: json['action'] as String,
      detail: json['detail'] as String?,
      at: DateTime.parse(json['at'] as String),
    );
  }
}
