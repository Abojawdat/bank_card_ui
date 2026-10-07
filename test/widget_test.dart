import 'package:bank_card_3d/bank_card_3d.dart';
import 'package:bank_card_3d/src/card_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final visa = BankCard(number: '4532015112830366', holderName: 'Mohammad Othman', expiryMonth: 8, expiryYear: 2099);
final master = BankCard(
  number: '5425233430109903',
  holderName: 'Sara Kareem',
  expiryMonth: 11,
  expiryYear: 2099,
  tier: CardTier.worldElite,
);

Widget app(Widget child) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: Center(child: child)),
  ),
);

void main() {
  testWidgets('3d card plays its intro and settles', (tester) async {
    await tester.pumpWidget(app(BankCard3D(card: visa, float: false)));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Visa •••• 0366'), findsOneWidget);
  });

  testWidgets('double tap flips and drag spins without throwing', (tester) async {
    await tester.pumpWidget(app(BankCard3D(card: master, intro: false, float: false)));
    final card = find.byType(BankCard3D);
    await tester.tap(card);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.fling(card, const Offset(300, 0), 2000);
    await tester.pumpAndSettle();
  });

  testWidgets('wallet pulls a card out and puts it back', (tester) async {
    int? picked = -1;
    await tester.pumpWidget(
      app(
        BankCardWallet(
          cards: [
            visa,
            master,
            visa.copyWith(tier: CardTier.gold),
          ],
          onSelected: (i) => picked = i,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.tapAt(tester.getTopLeft(find.byType(BankCardWallet)) + const Offset(170, 20));
    await tester.pump(const Duration(seconds: 3));
    expect(picked, 0);
    await tester.tapAt(tester.getTopLeft(find.byType(BankCardWallet)) + const Offset(170, 100));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 3));
    expect(picked, null);
  });

  testWidgets('form formats input, detects the brand and validates', (tester) async {
    final key = GlobalKey<FormState>();
    BankCard? last;
    await tester.pumpWidget(app(BankCardForm(formKey: key, onChanged: (c) => last = c)));
    final fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), '٥٤٢٥٢٣٣٤٣٠١٠٩٩٠٣');
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('5425 2334 3010 9903'), findsOneWidget);
    expect(last!.brand, CardBrand.mastercard);
    expect(find.byType(CardBrandMark), findsOneWidget);

    expect(key.currentState!.validate(), isFalse);

    await tester.enterText(fields.at(1), 'sara kareem');
    await tester.enterText(fields.at(2), '1199');
    await tester.enterText(fields.at(3), '123');
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('11/99'), findsOneWidget);
    expect(key.currentState!.validate(), isTrue);
    expect(last!.entryIssue, isNull);
  });

  testWidgets('form rejects amex in arabic', (tester) async {
    final key = GlobalKey<FormState>();
    BankCardLabels? picked;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: const Locale('ar'),
            child: Builder(builder: (context) => Text('${picked = BankCardLabels.of(context)}')),
          ),
        ),
      ),
    );
    expect(picked, BankCardLabels.arabic);
    await tester.pumpWidget(app(BankCardForm(formKey: key, labels: BankCardLabels.arabic)));
    await tester.enterText(find.byType(TextFormField).first, '378282246310005');
    key.currentState!.validate();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(BankCardLabels.arabic.issue(CardIssue.unsupportedBrand)), findsOneWidget);
  });

  testWidgets('a card at rest paints from the baked image, not live', (tester) async {
    await tester.pumpWidget(app(BankCard3D(card: visa, intro: false, float: false)));
    await tester.pumpAndSettle();
    final painter =
        tester
                .widget<CustomPaint>(find.descendant(of: find.byType(BankCard3D), matching: find.byType(CustomPaint)))
                .painter!
            as CardFacePainter;
    expect(painter.baked, isNotNull);
  });

  testWidgets('every display mode paints, and missing data turns into stars', (tester) async {
    final lonely = BankCard.tryFromJson({'last4': '0005', 'brand': 'mastercard'})!;
    for (final number in NumberDisplay.values) {
      for (final field in FieldDisplay.values) {
        final display = CardDisplay(
          number: number,
          holder: field,
          expiry: field,
          cvv: field,
          chip: false,
          contactless: false,
        );
        for (final side in CardSide.values) {
          await tester.pumpWidget(
            app(
              Column(
                children: [
                  BankCardView(card: visa, display: display, side: side),
                  BankCardView(card: lonely, display: display, side: side, look: CardLook.glass),
                ],
              ),
            ),
          );
        }
      }
    }
    expect(tester.takeException(), isNull);
  });
}
