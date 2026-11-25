import 'package:lms/core/network/api_client.dart';
import 'package:lms/features/courses/data/models/batch_model.dart';
import 'package:lms/features/resources/data/models/resource.dart';

class ResourcesRepository {
  ResourcesRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<Resource>> getResources(String token) async {
    final response = await _apiClient.get('/resources', token: token);
    final data = response['data'] ?? [];
    if (data is List) {
      return data.map((e) => Resource.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<BatchModel>> getMyBatches(String token) async {
    final response = await _apiClient.get('/batches/my-batches', token: token);
    final data = response['data'] ?? [];
    if (data is List) {
      return data.map((e) => BatchModel.fromJson(e)).toList();
    }
    return [];
  }
}
