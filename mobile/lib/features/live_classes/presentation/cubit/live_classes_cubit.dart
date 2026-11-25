import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/core/config/app_config.dart';
import 'package:lms/features/live_classes/data/models/live_classes_models.dart';
import 'package:lms/features/live_classes/data/repositories/live_classes_repository.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

abstract class LiveClassesState extends Equatable {
  const LiveClassesState();

  @override
  List<Object?> get props => [];
}

class LiveClassesInitial extends LiveClassesState {}

class LiveClassesLoading extends LiveClassesState {}

class LiveClassesLoaded extends LiveClassesState {
  final List<LiveClass> classes;

  const LiveClassesLoaded(this.classes);

  @override
  List<Object?> get props => [classes];
}

class LiveClassesError extends LiveClassesState {
  final String message;

  const LiveClassesError(this.message);

  @override
  List<Object?> get props => [message];
}

class LiveClassesCubit extends Cubit<LiveClassesState> {
  final LiveClassesRepository _repository;
  io.Socket? _socket;
  Timer? _fallbackRefreshTimer;
  String? _token;
  bool _isFetching = false;

  LiveClassesCubit(this._repository) : super(LiveClassesInitial());

  /// Keeps the visible live-class state in sync without requiring a pull-to-refresh.
  ///
  /// The server emits `live-class:changed` exactly when a teacher starts or
  /// ends a class. A modest fallback refresh also covers a brief socket outage.
  void startRealtimeUpdates(String token) {
    if (token.isEmpty) return;
    _token = token;

    _socket ??= io.io(
      AppConfig.webUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .build(),
    )..on('live-class:changed', (_) => _refreshFromRealtime());

    _fallbackRefreshTimer ??= Timer.periodic(
      const Duration(seconds: 45),
      (_) => _refreshFromRealtime(),
    );
  }

  Future<void> _refreshFromRealtime() async {
    final token = _token;
    if (token == null || token.isEmpty || _isFetching || isClosed) return;
    await fetchLiveClasses(token, silently: true);
  }

  Future<void> fetchLiveClasses(String token, {bool silently = false}) async {
    if (token.isEmpty || _isFetching) return;
    startRealtimeUpdates(token);
    _isFetching = true;

    try {
      if (!silently && state is! LiveClassesLoaded) {
        emit(LiveClassesLoading());
      }
      final classes = await _repository.getActiveClasses(token);
      emit(LiveClassesLoaded(classes));
    } catch (e) {
      if (!silently) emit(LiveClassesError(e.toString()));
    } finally {
      _isFetching = false;
    }
  }

  @override
  Future<void> close() {
    _fallbackRefreshTimer?.cancel();
    _socket?.dispose();
    return super.close();
  }
}
