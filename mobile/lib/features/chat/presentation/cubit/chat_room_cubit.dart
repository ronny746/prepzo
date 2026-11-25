import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/features/chat/data/models/chat_models.dart';
import 'package:lms/features/chat/data/repositories/chat_repository.dart';

enum ChatRoomStatus { initial, loading, success, failure }

class ChatRoomState extends Equatable {
  const ChatRoomState({
    this.status = ChatRoomStatus.initial,
    this.messages = const [],
    this.error,
  });

  final ChatRoomStatus status;
  final List<ChatMessage> messages;
  final String? error;

  ChatRoomState copyWith({
    ChatRoomStatus? status,
    List<ChatMessage>? messages,
    String? error,
  }) {
    return ChatRoomState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, messages, error];
}

class ChatRoomCubit extends Cubit<ChatRoomState> {
  ChatRoomCubit({required ChatRepository chatRepository})
      : _chatRepository = chatRepository,
        super(const ChatRoomState());

  final ChatRepository _chatRepository;

  Future<void> loadMessages(String token, String roomId) async {
    emit(state.copyWith(status: ChatRoomStatus.loading));
    try {
      final messages = await _chatRepository.getChatMessages(token, roomId);
      emit(state.copyWith(status: ChatRoomStatus.success, messages: messages));
    } catch (e) {
      emit(state.copyWith(status: ChatRoomStatus.failure, error: e.toString()));
    }
  }

  Future<void> sendMessage(String token, String roomId, String content) async {
    try {
      final newMessage = await _chatRepository.sendMessage(token, roomId, content);
      final updatedMessages = List<ChatMessage>.from(state.messages)..add(newMessage);
      emit(state.copyWith(messages: updatedMessages));
    } catch (e) {
      emit(state.copyWith(status: ChatRoomStatus.failure, error: e.toString()));
    }
  }
}
