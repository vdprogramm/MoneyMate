import 'package:flutter_test/flutter_test.dart';
import 'package:moneymate/receipt_parser.dart';

void main() {
  test('Vietnamese total is preferred over a unit price', () {
    final r=parseReceiptText('Cửa hàng An Nhiên\nGiá: 35.000\nVAT: 3.500\nTỔNG TIỀN: 125.000đ');
    expect(r.amount,125000);
    expect(r.hasTotalLabel,true);
    expect(r.merchant,'Cửa hàng An Nhiên');
  });
  test('Decimal cents in grand total', () {
    final r=parseReceiptText('Cafe ABC\nGrand Total 125.000,00 VND\nInvoice No 23056012');
    expect(r.amount,125000);
  });
  test('No valid amount', () {
    final r=parseReceiptText('Hóa đơn không đọc được');
    expect(r.amount,isNull);
  });
  test('Ignore tax ID', () {
    final r=parseReceiptText('Cửa hàng X\nMST: 1234567890\nTổng cộng: 75.000');
    expect(r.amount,75000);
  });
}
