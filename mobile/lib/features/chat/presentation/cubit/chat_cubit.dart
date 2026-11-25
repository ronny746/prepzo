import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/features/chat/data/models/chat_models.dart';
import 'package:lms/features/chat/data/repositories/chat_repository.dart';

enum ChatStatus { initial, loading, success, failure }

class ChatState extends Equatable {
  const ChatState({
    this.status = ChatStatus.initial,
    this.rooms = const [],
    this.teachers = const [],
    this.error,
  });

  final ChatStatus status;
  final List<ChatRoom> rooms;
  final List<Map<String, dynamic>> teachers;
  final String? error;

  ChatState copyWith({
    ChatStatus? status,
    List<ChatRoom>? rooms,
    List<Map<String, dynamic>>? teachers,
    String? error,
  }) {
    return ChatState(
      status: status ?? this.status,
      rooms: rooms ?? this.rooms,
      teachers: teachers ?? this.teachers,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, rooms, teachers, error];
}

class ChatCubit extends Cubit<ChatState> {
  ChatCubit({required ChatRepository chatRepository})
      : _chatRepository = chatRepository,
        super(const ChatState());

  final ChatRepository _chatRepository;

  Future<void> loadRooms(String token) async {
    emit(state.copyWith(status: ChatStatus.loading));
    try {
      final rooms = await _chatRepository.getChatRooms(token);
      emit(state.copyWith(status: ChatStatus.success, rooms: rooms));
    } catch (e) {
      emit(state.copyWith(status: ChatStatus.failure, error: e.toString()));
    }
  }

  Future<void> loadTeachers(String token) async {
    try {
      final teachers = await _chatRepository.getUsers(token, role: 'TEACHER');
      emit(state.copyWith(teachers: teachers));
    } catch (e) {
      // Handle error gracefully or ignore if not critical
    }
  }

  Future<ChatRoom?> createRoom(String token, String targetUserId) async {
    try {
      final newRoom = await _chatRepository.createChatRoom(token, targetUserId);
      await loadRooms(token);
      return newRoom;
    } catch (e) {
      emit(state.copyWith(status: ChatStatus.failure, error: e.toString()));
      return null;
    }
  }
}
