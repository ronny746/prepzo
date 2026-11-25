class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.name,
    required this.type,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final String id;
  final String name;
  final String type; // 'direct' or 'group'
  final List<ChatParticipant> participants;
  final ChatMessage? lastMessage;
  final int unreadCount;

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'direct',
      participants:
          (json['participants'] as List?)
              ?.map((e) => ChatParticipant.fromJson(e))
              .toList() ??
          [],
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}

class ChatParticipant {
  const ChatParticipant({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;
  final String role;

  factory ChatParticipant.fromJson(dynamic jsonData) {
    if (jsonData is String) {
      return ChatParticipant(id: jsonData, name: 'Unknown User', role: 'user');
    }
    final json = jsonData as Map<String, dynamic>;
    print('DEBUG ChatParticipant.fromJson: $json');
    String fullName = 'Unknown User';
    if (json['firstName'] != null) {
      fullName = '${json['firstName']} ${json['lastName'] ?? ''}'.trim();
    } else if (json['name'] != null) {
      fullName = json['name'];
    } else {
      fullName = 'Keys: ${json.keys.join(', ')}';
    }

    return ChatParticipant(
      id: json['_id'] ?? json['id'] ?? '',
      name: fullName,
      role: json['role'] ?? 'user',
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
  });

  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime? timestamp;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['senderId'];
    return ChatMessage(
      id: json['_id'] ?? json['id'] ?? '',
      roomId: json['roomId'] ?? '',
      senderId: sender is Map ? sender['_id'] ?? '' : sender ?? '',
      senderName: sender is Map ? sender['name'] ?? 'Unknown' : 'Unknown',
      content: json['content'] ?? '',
      timestamp: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : null,
    );
  }
}
