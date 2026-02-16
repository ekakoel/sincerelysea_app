import 'package:flutter/services.dart';

class UsernameTextInputFormatter extends TextInputFormatter {
  static final RegExp _allowed = RegExp(r'[a-z0-9_]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String lowered = newValue.text.toLowerCase();
    final String filtered = lowered
        .split('')
        .where((String c) => _allowed.hasMatch(c))
        .join();
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
      composing: TextRange.empty,
    );
  }
}
