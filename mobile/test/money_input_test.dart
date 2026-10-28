import 'package:flutter_test/flutter_test.dart';
import 'package:moneymate/screens.dart';

void main() {
  test('parses integer VND amounts', () {
    expect(parseMoneyInput('125000'), 125000);
  });

  test('accepts a decimal comma from Vietnamese keyboards', () {
    expect(parseMoneyInput('125000,50'), 125000.50);
  });

  test('accepts a decimal point', () {
    expect(parseMoneyInput('125000.50'), 125000.50);
  });

  test('rejects blank and invalid amounts', () {
    expect(parseMoneyInput(''), isNull);
    expect(parseMoneyInput('abc'), isNull);
  });
}
