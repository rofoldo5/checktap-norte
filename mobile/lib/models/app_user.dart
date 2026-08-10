class AppUser {
  static const String pendingStatus = 'PENDING';
  static const String approvedStatus = 'APPROVED';
  static const String rejectedStatus = 'REJECTED';
  static const String suspendedStatus = 'SUSPENDED';

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.isAdmin = false,
    this.isActive = true,
    this.accountStatus = approvedStatus,
    this.departmentIds = const <String>[],
    this.createdAt,
    this.reviewedAt,
    this.reviewNote,
  });

  final String id;
  final String name;
  final String email;
  final bool isAdmin;
  final bool isActive;
  final String accountStatus;
  final List<String> departmentIds;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewNote;

  bool get isPending => accountStatus == pendingStatus;
  bool get isApproved => accountStatus == approvedStatus;
  bool get isRejected => accountStatus == rejectedStatus;
  bool get isSuspended => accountStatus == suspendedStatus;

  String get accountStatusLabel {
    switch (accountStatus) {
      case pendingStatus:
        return 'Pendiente';
      case rejectedStatus:
        return 'Rechazada';
      case suspendedStatus:
        return 'Suspendida';
      default:
        return isActive ? 'Activa' : 'Inactiva';
    }
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final rawDepartmentIds = json['department_ids'] as List<dynamic>?;
    final isActive = json['is_active'] as bool? ?? true;
    return AppUser(
      id: json['id'].toString(),
      name: json['name'] as String,
      email: json['email'] as String,
      isAdmin: json['is_admin'] as bool? ?? false,
      isActive: isActive,
      accountStatus:
          json['account_status']?.toString() ??
          (isActive ? AppUser.approvedStatus : AppUser.suspendedStatus),
      departmentIds:
          rawDepartmentIds
              ?.map((item) => item.toString())
              .toList(growable: false) ??
          const <String>[],
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.tryParse(json['reviewed_at'].toString()),
      reviewNote: json['review_note']?.toString(),
    );
  }

  AppUser copyWith({
    String? name,
    String? email,
    bool? isAdmin,
    bool? isActive,
    String? accountStatus,
    List<String>? departmentIds,
    DateTime? createdAt,
    DateTime? reviewedAt,
    String? reviewNote,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      isAdmin: isAdmin ?? this.isAdmin,
      isActive: isActive ?? this.isActive,
      accountStatus: accountStatus ?? this.accountStatus,
      departmentIds: departmentIds ?? this.departmentIds,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNote: reviewNote ?? this.reviewNote,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'is_admin': isAdmin,
      'is_active': isActive,
      'account_status': accountStatus,
      'department_ids': departmentIds,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'reviewed_at': reviewedAt?.toUtc().toIso8601String(),
      'review_note': reviewNote,
    };
  }
}
