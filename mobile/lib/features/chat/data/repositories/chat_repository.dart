import 'package:lms/core/network/api_client.dart';
import 'package:lms/features/chat/data/models/chat_models.dart';

class ChatRepository {
  ChatRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<ChatRoom>> getChatRooms(String token) async {
    final response = await _apiClient.get('/chat/rooms', token: token);
    final data = response['data'] ?? [];
    if (data is List) {
      return data.map((e) => ChatRoom.fromJson(e)).toList();
    }
    return [];
  }

  Future<ChatRoom> createChatRoom(String token, String targetUserId) async {
    final response = await _apiClient.post(
      '/chat/rooms',
      token: token,
      data: {'targetUserId': targetUserId},
    );
    return ChatRoom.fromJson(response['data']);
  }

  Future<List<ChatMessage>> getChatMessages(String token, String roomId) async {
    final response = await _apiClient.get(
      '/chat/rooms/$roomId/messages',
      token: token,
    );
    final data = response['data'] ?? [];
    if (data is List) {
      return data.map((e) => ChatMessage.fromJson(e)).toList();
    }
    return [];
  }

  Future<ChatMessage> sendMessage(
    String token,
    String roomId,
    String content,
  ) async {
    final response = await _apiClient.post(
      '/chat/rooms/$roomId/messages',
      token: token,
      data: {'content': content},
    );
    return ChatMessage.fromJson(response['data']);
  }

  Future<List<Map<String, dynamic>>> getUsers(
    String token, {
    String? role,
  }) async {
    final queryParams = role != null ? {'role': role} : null;
    final response = await _apiClient.get(
      '/users',
      token: token,
      queryParameters: queryParams,
    );
    final data = response['data'] ?? [];
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    } else if (data is Map && data['users'] is List) {
      return List<Map<String, dynamic>>.from(data['users']);
    }
    return [];
  }
}
