class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.isAdmin = false,
    this.isActive = true,
    this.departmentIds = const <String>[],
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final bool isAdmin;
  final bool isActive;
  final List<String> departmentIds;
  final DateTime? createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final rawDepartmentIds = json['department_ids'] as List<dynamic>?;
    return AppUser(
      id: json['id'].toString(),
      name: json['name'] as String,
      email: json['email'] as String,
      isAdmin: json['is_admin'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      departmentIds:
          rawDepartmentIds
              ?.map((item) => item.toString())
              .toList(growable: false) ??
          const <String>[],
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  AppUser copyWith({
    String? name,
    String? email,
    bool? isAdmin,
    bool? isActive,
    List<String>? departmentIds,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      isAdmin: isAdmin ?? this.isAdmin,
      isActive: isActive ?? this.isActive,
      departmentIds: departmentIds ?? this.departmentIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'is_admin': isAdmin,
      'is_active': isActive,
      'department_ids': departmentIds,
      'created_at': createdAt?.toUtc().toIso8601String(),
    };
  }
}
