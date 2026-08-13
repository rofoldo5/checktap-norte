import 'dart:convert';

class SyncOperation {
  const SyncOperation({
    this.localId,
    required this.operationId,
    required this.entityId,
    required this.operationType,
    required this.baseVersion,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
    this.nextRetryAt,
    this.state = 'PENDING',
  });

  final int? localId;
  final String operationId;
  final String entityId;
  final String operationType;
  final int baseVersion;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  final DateTime? nextRetryAt;
  final String state;

  factory SyncOperation.fromDatabase(Map<String, Object?> row) {
    return SyncOperation(
      localId: row['id'] as int?,
      operationId: row['operation_id'] as String,
      entityId: row['entity_id'] as String,
      operationType: row['operation_type'] as String,
      baseVersion: row['base_version'] as int? ?? 0,
      payload: Map<String, dynamic>.from(
        jsonDecode(row['payload_json'] as String) as Map,
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
      attempts: row['attempts'] as int? ?? 0,
      lastError: row['last_error'] as String?,
      nextRetryAt: row['next_retry_at'] == null
          ? null
          : DateTime.tryParse(row['next_retry_at'] as String),
      state: row['state'] as String? ?? 'PENDING',
    );
  }

  Map<String, Object?> toDatabase() {
    return <String, Object?>{
      'operation_id': operationId,
      'entity_id': entityId,
      'operation_type': operationType,
      'base_version': baseVersion,
      'payload_json': jsonEncode(payload),
      'created_at': createdAt.toUtc().toIso8601String(),
      'attempts': attempts,
      'last_error': lastError,
      'next_retry_at': nextRetryAt?.toUtc().toIso8601String(),
      'state': state,
    };
  }

  Map<String, dynamic> toApiJson() {
    return <String, dynamic>{
      'operation_id': operationId,
      'operation_type': operationType,
      'entity_id': entityId,
      'base_version': baseVersion,
      'payload': payload,
    };
  }
}

class SyncOperationResult {
  const SyncOperationResult({
    required this.operationId,
    required this.status,
    this.detail,
    this.taskJson,
    this.controlSectionJson,
    this.controlCheckJson,
    this.deletedEntityId,
  });

  final String operationId;
  final String status;
  final String? detail;
  final Map<String, dynamic>? taskJson;
  final Map<String, dynamic>? controlSectionJson;
  final Map<String, dynamic>? controlCheckJson;
  final String? deletedEntityId;

  factory SyncOperationResult.fromJson(Map<String, dynamic> json) {
    return SyncOperationResult(
      operationId: json['operation_id'].toString(),
      status: json['status'] as String,
      detail: json['detail'] as String?,
      taskJson: json['task'] == null
          ? null
          : Map<String, dynamic>.from(json['task'] as Map),
      controlSectionJson: json['control_section'] == null
          ? null
          : Map<String, dynamic>.from(json['control_section'] as Map),
      controlCheckJson: json['control_check'] == null
          ? null
          : Map<String, dynamic>.from(json['control_check'] as Map),
      deletedEntityId: json['deleted_entity_id']?.toString(),
    );
  }
}
