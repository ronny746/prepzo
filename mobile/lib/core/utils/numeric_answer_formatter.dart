import 'package:flutter/services.dart';

/// Accepts only an optional leading '-', digits and a single '.', so integer /
/// numerical answers cannot contain letters. A rejected edit keeps old text.
class NumericAnswerFormatter extends TextInputFormatter {
  static final RegExp _pattern = RegExp(r'^-?\d*\.?\d*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _pattern.hasMatch(newValue.text) ? newValue : oldValue;
}
