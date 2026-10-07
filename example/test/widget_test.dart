import 'package:bank_card_3d/bank_card_3d.dart';
import 'package:bank_card_3d_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every record in the fake api turns into a card', () {
    expect([for (final json in api) BankCard.fromJson(json).last4], everyElement(hasLength(4)));
  });

  testWidgets('demo opens on all three tabs and in arabic', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const Demo());
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(BankCard3D), findsOneWidget);

    await tester.tap(find.byIcon(Icons.wallet));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(BankCardWallet), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_card));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(BankCardForm), findsOneWidget);

    await tester.tap(find.text('عربي'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('حفظ البطاقة'), findsOneWidget);
  });
}
