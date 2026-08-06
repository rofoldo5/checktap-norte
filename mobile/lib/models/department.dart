import 'app_user.dart';

class DepartmentSummary {
  const DepartmentSummary({
    required this.id,
    required this.name,
    this.isActive = true,
    this.memberCount = 0,
  });

  static const DepartmentSummary unknown = DepartmentSummary(
    id: 'pending-department',
    name: 'Equipo',
  );

  final String id;
  final String name;
  final bool isActive;
  final int memberCount;

  factory DepartmentSummary.fromJson(Map<String, dynamic> json) {
    return DepartmentSummary(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Equipo',
      isActive: json['is_active'] as bool? ?? true,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
    );
  }

  DepartmentSummary copyWith({
    String? name,
    bool? isActive,
    int? memberCount,
  }) {
    return DepartmentSummary(
      id: id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'is_active': isActive,
      'member_count': memberCount,
    };
  }
}

class DepartmentDetail {
  const DepartmentDetail({
    required this.id,
    required this.name,
    required this.isActive,
    required this.memberCount,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final bool isActive;
  final int memberCount;
  final List<AppUser> members;
  final DateTime createdAt;
  final DateTime updatedAt;

  DepartmentSummary get summary => DepartmentSummary(
        id: id,
        name: name,
        isActive: isActive,
        memberCount: memberCount,
      );

  factory DepartmentDetail.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List<dynamic>? ?? const <dynamic>[];
    return DepartmentDetail(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Departamento',
      isActive: json['is_active'] as bool? ?? true,
      memberCount: (json['member_count'] as num?)?.toInt() ?? rawMembers.length,
      members: rawMembers
          .map(
            (item) => AppUser.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}
