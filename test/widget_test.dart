import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sincerelysea/utils/username_text_input_formatter.dart';

void main() {
  test('username formatter converts uppercase and removes invalid chars', () {
    final UsernameTextInputFormatter formatter = UsernameTextInputFormatter();

    final TextEditingValue oldValue = const TextEditingValue(text: 'john');
    final TextEditingValue newValue = const TextEditingValue(
      text: 'JoHN.Name!123',
      selection: TextSelection.collapsed(offset: 13),
    );

    final TextEditingValue result = formatter.formatEditUpdate(
      oldValue,
      newValue,
    );

    expect(result.text, 'johnname123');
  });

  test('username formatter keeps underscore', () {
    final UsernameTextInputFormatter formatter = UsernameTextInputFormatter();

    final TextEditingValue result = formatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      const TextEditingValue(
        text: 'A_b',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );

    expect(result.text, 'a_b');
  });
}
