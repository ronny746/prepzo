import 'package:flutter_test/flutter_test.dart';
import 'package:lms/core/network/api_exception.dart';
import 'package:lms/features/extras/data/models/extras_models.dart';
import 'package:lms/features/extras/presentation/widgets/receipt_download.dart';

void main() {
  TransactionModel txn(Map<String, dynamic> extra) =>
      TransactionModel.fromJson({
        '_id': '6650aa11bb22cc33dd44ee55',
        'transactionId': 'order_PqR7sT9uVwXyZ1',
        'courseName': 'JEE 2027',
        'amountPaid': 4999,
        'paymentMethod': 'RAZORPAY',
        ...extra,
      });

  test('only successful / paid transactions offer a receipt', () {
    expect(txn({'status': 'SUCCESS'}).hasReceipt, isTrue);
    expect(txn({'status': 'PAID'}).hasReceipt, isTrue);
    expect(txn({'status': 'PENDING'}).hasReceipt, isFalse);
    expect(txn({'status': 'FAILED'}).hasReceipt, isFalse);
    expect(txn({'status': 'PARTIAL'}).hasReceipt, isFalse);
  });

  test('a transaction without an id has no receipt', () {
    final t = TransactionModel.fromJson({
      'status': 'SUCCESS',
      'amountPaid': 10,
    });
    expect(t.hasReceipt, isFalse);
  });

  test('receipt file name is safe and ends in .pdf', () {
    expect(
      txn({'status': 'SUCCESS'}).receiptFileName,
      'Prepzo-Receipt-R7sT9uVwXyZ1.pdf',
    );
    final weird = txn({'status': 'SUCCESS', 'transactionId': 'a/b c:d'});
    expect(weird.receiptFileName, 'Prepzo-Receipt-abcd.pdf');
  });

  test('download errors become short friendly messages', () {
    expect(
      receiptErrorMessage(const ApiException('long dio text', statusCode: 404)),
      'Receipt is not available yet. Please try again later.',
    );
    expect(
      receiptErrorMessage(const ApiException('x', statusCode: 403)),
      'This receipt belongs to another account.',
    );
    expect(
      receiptErrorMessage(Exception('boom')),
      'Could not download the receipt. Please try again.',
    );
  });
}
