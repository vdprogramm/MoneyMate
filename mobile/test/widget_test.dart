import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneymate/main.dart';

void main() {
  testWidgets('Cloud configuration screen appears correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CloudSetupScreen()),
    );

    expect(find.text('MoneyMate cần API cloud'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.textContaining('API_BASE_URL'), findsOneWidget);
  });
}
