import 'department.dart';

class DailyReportItem {
  const DailyReportItem({
    required this.id,
    required this.department,
    required this.reportDate,
    required this.status,
    required this.fileSize,
    required this.createdCount,
    required this.completedCount,
    required this.pendingCount,
    required this.inProgressCount,
    required this.generatedAt,
    this.error,
  });

  final String id;
  final DepartmentSummary department;
  final DateTime reportDate;
  final String status;
  final int fileSize;
  final int createdCount;
  final int completedCount;
  final int pendingCount;
  final int inProgressCount;
  final String? error;
  final DateTime generatedAt;

  factory DailyReportItem.fromJson(Map<String, dynamic> json) {
    return DailyReportItem(
      id: json['id'].toString(),
      department: DepartmentSummary.fromJson(
        Map<String, dynamic>.from(json['department'] as Map),
      ),
      reportDate: DateTime.parse(json['report_date'].toString()),
      status: json['status'].toString(),
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      createdCount: (json['created_count'] as num?)?.toInt() ?? 0,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      inProgressCount: (json['in_progress_count'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
      generatedAt: DateTime.parse(json['generated_at'].toString()),
    );
  }
}
