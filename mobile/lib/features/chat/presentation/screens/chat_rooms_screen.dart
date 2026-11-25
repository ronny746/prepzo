import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/theme/app_theme.dart';
import 'package:lms/core/widgets/app_scaffold.dart';
import 'package:lms/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:lms/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:lms/routes/app_router.dart';

class ChatRoomsScreen extends StatefulWidget {
  const ChatRoomsScreen({super.key, this.drawer});
  
  final Widget? drawer;

  @override
  State<ChatRoomsScreen> createState() => _ChatRoomsScreenState();
}

class _ChatRoomsScreenState extends State<ChatRoomsScreen> {
  @override
  void initState() {
    super.initState();
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    context.read<ChatCubit>().loadRooms(token);
  }

  void _showNewChatModal(BuildContext context, String token) {
    context.read<ChatCubit>().loadTeachers(token);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return BlocBuilder<ChatCubit, ChatState>(
          builder: (context, state) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Start New Chat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text('Select a teacher to start chatting:'),
                  const SizedBox(height: 20),
                  if (state.teachers.isEmpty)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: state.teachers.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final teacher = state.teachers[index];
                          final id = teacher['_id'] ?? teacher['id'];
                          final name = '${teacher['firstName'] ?? ''} ${teacher['lastName'] ?? ''}'.trim();
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(name.isNotEmpty ? name : 'Unknown Teacher'),
                            subtitle: Text(teacher['email'] ?? ''),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final newRoom = await context.read<ChatCubit>().createRoom(token, id);
                              if (newRoom != null && mounted) {
                                Navigator.pushNamed(context, AppRoutes.chatRoom, arguments: newRoom);
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = context.read<AuthBloc>().state.session?.accessToken ?? '';
    return AppScaffold(
      title: 'Messages',
      showAppBar: true,
      drawer: widget.drawer,
      actions: [
        IconButton(
          icon: const Icon(Icons.add, color: AppTheme.primary),
          onPressed: () => _showNewChatModal(context, token),
        ),
      ],
      body: BlocBuilder<ChatCubit, ChatState>(
        builder: (context, state) {
          if (state.status == ChatStatus.loading && state.rooms.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null) {
            return Center(child: Text(state.error!, style: const TextStyle(color: AppTheme.error)));
          }

          if (state.rooms.isEmpty) {
            return const Center(child: Text('No active conversations.'));
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.rooms.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final room = state.rooms[index];
              String getChatName() {
                if (room.type.toUpperCase() == 'GROUP') return room.name;
                try {
                  final currentUserId = context.read<AuthBloc>().state.session?.user.id ?? '';
                  final other = room.participants.firstWhere((p) => p.id != currentUserId);
                  return '${other.name} (${other.role.toUpperCase()})';
                } catch (_) {
                  return 'Direct Message';
                }
              }
              final chatTitle = getChatName();
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      chatTitle.isNotEmpty ? chatTitle[0].toUpperCase() : 'U',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(chatTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Tap to view ${room.type.toLowerCase()} chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: room.unreadCount > 0
                      ? Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            room.unreadCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        )
                      : null,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.chatRoom,
                      arguments: room,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
