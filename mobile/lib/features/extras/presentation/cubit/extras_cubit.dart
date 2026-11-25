import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lms/features/extras/data/models/extras_models.dart';
import 'package:lms/features/extras/data/repositories/extras_repository.dart';

enum ExtrasStatus { initial, loading, success, failure }

class ExtrasState extends Equatable {
  const ExtrasState({
    this.status = ExtrasStatus.initial,
    this.liveClasses = const [],
    this.resources = const [],
    this.fees = const [],
    this.transactions = const [],
    this.ptmSlots = const [],
    this.ptmBookings = const [],
    this.error,
  });

  final ExtrasStatus status;
  final List<LiveClassModel> liveClasses;
  final List<ResourceModel> resources;
  final List<FeeModel> fees;
  final List<TransactionModel> transactions;
  final List<Map<String, dynamic>> ptmSlots;
  final List<Map<String, dynamic>> ptmBookings;
  final String? error;

  ExtrasState copyWith({
    ExtrasStatus? status,
    List<LiveClassModel>? liveClasses,
    List<ResourceModel>? resources,
    List<FeeModel>? fees,
    List<TransactionModel>? transactions,
    List<Map<String, dynamic>>? ptmSlots,
    List<Map<String, dynamic>>? ptmBookings,
    String? error,
  }) {
    return ExtrasState(
      status: status ?? this.status,
      liveClasses: liveClasses ?? this.liveClasses,
      resources: resources ?? this.resources,
      fees: fees ?? this.fees,
      transactions: transactions ?? this.transactions,
      ptmSlots: ptmSlots ?? this.ptmSlots,
      ptmBookings: ptmBookings ?? this.ptmBookings,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    liveClasses,
    resources,
    fees,
    transactions,
    ptmSlots,
    ptmBookings,
    error,
  ];
}

class ExtrasCubit extends Cubit<ExtrasState> {
  ExtrasCubit({required ExtrasRepository extrasRepository})
    : _extrasRepository = extrasRepository,
      super(const ExtrasState());

  final ExtrasRepository _extrasRepository;

  Future<void> loadLiveClasses(String token) async {
    emit(state.copyWith(status: ExtrasStatus.loading));
    try {
      final data = await _extrasRepository.getLiveClasses(token);
      emit(state.copyWith(status: ExtrasStatus.success, liveClasses: data));
    } catch (e) {
      emit(state.copyWith(status: ExtrasStatus.failure, error: e.toString()));
    }
  }

  Future<void> loadResources(String token) async {
    emit(state.copyWith(status: ExtrasStatus.loading));
    try {
      final data = await _extrasRepository.getResources(token);
      emit(state.copyWith(status: ExtrasStatus.success, resources: data));
    } catch (e) {
      emit(state.copyWith(status: ExtrasStatus.failure, error: e.toString()));
    }
  }

  Future<void> loadFees(String token) async {
    emit(state.copyWith(status: ExtrasStatus.loading));
    try {
      final data = await _extrasRepository.getFees(token);
      emit(state.copyWith(status: ExtrasStatus.success, fees: data));
    } catch (e) {
      emit(state.copyWith(status: ExtrasStatus.failure, error: e.toString()));
    }
  }

  Future<void> loadTransactions(String token) async {
    emit(state.copyWith(status: ExtrasStatus.loading));
    try {
      final data = await _extrasRepository.getTransactions(token);
      emit(state.copyWith(status: ExtrasStatus.success, transactions: data));
    } catch (e) {
      emit(state.copyWith(status: ExtrasStatus.failure, error: e.toString()));
    }
  }

  Future<Uint8List> downloadReceipt(String token, String paymentId) =>
      _extrasRepository.downloadReceipt(token, paymentId);

  Future<void> loadPtmData(String token) async {
    emit(state.copyWith(status: ExtrasStatus.loading));
    try {
      final slots = await _extrasRepository.getPtmSlots(token);
      final bookings = await _extrasRepository.getPtmBookings(token);
      emit(
        state.copyWith(
          status: ExtrasStatus.success,
          ptmSlots: slots,
          ptmBookings: bookings,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ExtrasStatus.failure, error: e.toString()));
    }
  }

  Future<void> bookPtmSlot(
    String token,
    String slotId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _extrasRepository.bookPtmSlot(token, slotId, data);
      await loadPtmData(token);
    } catch (e) {
      emit(state.copyWith(status: ExtrasStatus.failure, error: e.toString()));
    }
  }
}
