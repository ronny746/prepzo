import 'dart:typed_data';

import 'package:lms/core/network/api_client.dart';
import 'package:lms/features/extras/data/models/extras_models.dart';

class ExtrasRepository {
  ExtrasRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<LiveClassModel>> getLiveClasses(String token) async {
    final response = await _apiClient.get('/live-classes', token: token);
    final data = response['data'] ?? [];
    if (data is List) {
      return data.map((e) => LiveClassModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<ResourceModel>> getResources(String token) async {
    final response = await _apiClient.get('/resources', token: token);
    final data = response['data'] ?? [];
    if (data is List) {
      return data.map((e) => ResourceModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getPtmSlots(String token) async {
    final response = await _apiClient.get('/ptm-booking/slots', token: token);
    final data = response['data'] ?? [];
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  Future<void> bookPtmSlot(String token, String slotId, Map<String, dynamic> data) async {
    await _apiClient.post('/ptm-booking/book', token: token, data: {
      'slotId': slotId,
      ...data,
    });
  }

  Future<List<Map<String, dynamic>>> getPtmBookings(String token) async {
    final response = await _apiClient.get('/ptm-booking/bookings', token: token);
    final data = response['data'] ?? [];
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  Future<List<FeeModel>> getFees(String token) async {
    final response = await _apiClient.get('/fees-payments/my-children', token: token);
    final data = response['data'] ?? [];
    if (data is List) {
      return data.map((e) => FeeModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> payFee(String token, String feeId, num amount, String method) async {
    await _apiClient.post('/fees-payments/pay', token: token, data: {
      'feeId': feeId,
      'amount': amount,
      'paymentMethod': method,
    });
  }

  /// PDF receipt for a successful payment (same file the web portal serves).
  Future<Uint8List> downloadReceipt(String token, String paymentId) {
    return _apiClient.getBytes(
      '/payments/${Uri.encodeComponent(paymentId)}/receipt.pdf',
      token: token,
    );
  }

  Future<List<TransactionModel>> getTransactions(String token) async {
    try {
      final response = await _apiClient.get('/fees-payments/transactions', token: token);
      final data = response['data'] ?? [];
      if (data is List) {
        final rawList = data.map((e) => TransactionModel.fromJson(Map<String, dynamic>.from(e))).toList();
        final seen = <String>{};
        final uniqueList = <TransactionModel>[];
        for (var item in rawList) {
          final key = item.transactionId.isNotEmpty ? item.transactionId : item.id;
          if (key.isEmpty || !seen.contains(key)) {
            if (key.isNotEmpty) seen.add(key);
            uniqueList.add(item);
          }
        }
        return uniqueList;
      }
    } catch (_) {
      try {
        final fallbackRes = await _apiClient.get('/fees-payments/records', token: token);
        final data = fallbackRes['data'] ?? [];
        if (data is List) {
          final rawList = data.map((e) => TransactionModel.fromJson(Map<String, dynamic>.from(e))).toList();
          final seen = <String>{};
          final uniqueList = <TransactionModel>[];
          for (var item in rawList) {
            final key = item.transactionId.isNotEmpty ? item.transactionId : item.id;
            if (key.isEmpty || !seen.contains(key)) {
              if (key.isNotEmpty) seen.add(key);
              uniqueList.add(item);
            }
          }
          return uniqueList;
        }
      } catch (e) {
        return [];
      }
    }
    return [];
  }
}
