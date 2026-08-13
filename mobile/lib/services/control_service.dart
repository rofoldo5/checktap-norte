import '../core/api_client.dart';
import '../models/control_item.dart';

class ControlSnapshotData {
  const ControlSnapshotData({required this.sections, required this.checks});

  final List<ControlSectionItem> sections;
  final List<ControlCheckItem> checks;
}

class ControlService {
  ControlService(this.apiClient);

  final ApiClient apiClient;

  Future<ControlSnapshotData> snapshot() async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/controls/snapshot',
    );
    final data = response.data!;
    final sections = (data['sections'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (item) => ControlSectionItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
    final checks = (data['checks'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (item) => ControlCheckItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
    return ControlSnapshotData(sections: sections, checks: checks);
  }

  Future<ControlCheckItem> getCheck(String checkId) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/controls/checks/$checkId',
    );
    return ControlCheckItem.fromJson(response.data!);
  }
}
