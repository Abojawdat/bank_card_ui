// renders the readme pictures, stills go to art/ and animation frames to build/frames/
//   flutter test --update-goldens tool/render.dart && python3 tool/pack.py
import 'dart:io';

import 'package:bank_card_3d/bank_card_3d.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final cards = [
  BankCard(
    number: '4532 0151 1283 0366',
    holderName: 'Mohammad Othman',
    expiryMonth: 8,
    expiryYear: 29,
    kind: CardKind.debit,
  ),
  BankCard(number: '5425 2334 3010 9903', holderName: 'Sara Kareem', expiryMonth: 11, expiryYear: 28),
  BankCard(
    number: '4916 3385 0608 2832',
    holderName: 'Ali Hassan',
    expiryMonth: 3,
    expiryYear: 30,
    tier: CardTier.gold,
    kind: CardKind.credit,
  ),
  BankCard(
    number: '2223 0031 2200 3222',
    holderName: 'Noor Al-Huda',
    expiryMonth: 6,
    expiryYear: 27,
    tier: CardTier.platinum,
  ),
  BankCard(
    number: '4024 0071 6305 3426',
    holderName: 'Zaid Mahmoud',
    expiryMonth: 1,
    expiryYear: 31,
    tier: CardTier.signature,
  ),
  BankCard(
    number: '4111 1111 1111 1111',
    holderName: 'Mustafa Jawad',
    expiryMonth: 9,
    expiryYear: 29,
    tier: CardTier.infinite,
    kind: CardKind.credit,
  ),
  BankCard(
    number: '5555 5555 5555 4444',
    holderName: 'Hiba Salman',
    expiryMonth: 4,
    expiryYear: 28,
    tier: CardTier.world,
  ),
  BankCard(
    number: '5105 1051 0510 5100',
    holderName: 'Omar Abbas',
    expiryMonth: 12,
    expiryYear: 30,
    tier: CardTier.worldElite,
  ),
];

// the test engine draws boxes for text, so borrow the mac's fonts
Future<void> _fonts() async {
  final loader = FontLoader('Roboto');
  for (final f in [
    'Arial.ttf',
    'Arial Bold.ttf',
    'Arial Italic.ttf',
    'Arial Bold Italic.ttf',
    'Arial Black.ttf',
    '../SFArabic.ttf',
  ]) {
    final file = File('/System/Library/Fonts/Supplemental/$f');
    if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

Widget stage(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Roboto', colorSchemeSeed: const Color(0xFF3D5AFE)),
  home: DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(center: Alignment(0, -0.5), radius: 1.2, colors: [Color(0xFF1B2050), Color(0xFF07080F)]),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Center(child: child),
    ),
  ),
);

void size(WidgetTester tester, Size s) {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
}

Future<void> still(WidgetTester tester, String name, Size s, Widget child) async {
  size(tester, s);
  await tester.pumpWidget(stage(child));
  await tester.pump(const Duration(seconds: 4));
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../art/$name.png'));
}

class Film {
  Film(this.tester, this.name);
  final WidgetTester tester;
  final String name;
  var frame = 0;

  Future<void> roll(int frames) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../build/frames/$name/${'${frame++}'.padLeft(4, '0')}.png'),
      );
    }
  }

  Future<void> doubleTap(Finder f) async {
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(f);
  }
}

void main() {
  setUpAll(_fonts);

  testWidgets('tiers', (tester) async {
    await still(
      tester,
      'tiers',
      const Size(1400, 500),
      Wrap(
        spacing: 28,
        runSpacing: 28,
        alignment: WrapAlignment.center,
        children: [for (final c in cards) BankCardView(card: c, width: 300, display: CardDisplay.everything)],
      ),
    );
  });

  testWidgets('glass', (tester) async {
    await still(
      tester,
      'glass',
      const Size(1400, 500),
      Wrap(
        spacing: 28,
        runSpacing: 28,
        alignment: WrapAlignment.center,
        children: [
          for (final c in [cards[0], cards[1], cards[2], cards[7]])
            BankCardView(card: c, width: 300, look: CardLook.glass, display: CardDisplay.everything),
          BankCardView(card: cards[0], width: 300, side: CardSide.back),
          BankCardView(card: cards[1], width: 300, side: CardSide.back),
          BankCardView(card: cards[5], width: 300, side: CardSide.back),
          BankCardView(card: cards[1], width: 300, side: CardSide.back, look: CardLook.glass),
        ],
      ),
    );
  });

  testWidgets('privacy', (tester) async {
    final lonely = BankCard.tryFromJson({'last4': '0005', 'brand': 'mastercard', 'tier': 'world'})!;
    await still(
      tester,
      'privacy',
      const Size(1400, 500),
      Wrap(
        spacing: 28,
        runSpacing: 28,
        alignment: WrapAlignment.center,
        children: [
          BankCardView(card: cards[0], width: 300, display: CardDisplay.everything),
          BankCardView(card: cards[0], width: 300),
          BankCardView(card: cards[0], width: 300, display: CardDisplay.private),
          BankCardView(card: lonely, width: 300),
          BankCardView(
            card: cards[1].copyWith(cvv: '742'),
            width: 300,
            side: CardSide.back,
            display: CardDisplay.everything,
          ),
          BankCardView(card: cards[1], width: 300, side: CardSide.back),
          BankCardView(
            card: cards[1],
            width: 300,
            side: CardSide.back,
            display: const CardDisplay(holder: FieldDisplay.hide, cvv: FieldDisplay.hide),
          ),
          BankCardView(card: lonely, width: 300, side: CardSide.back),
        ],
      ),
    );
  });

  testWidgets('hero', (tester) async {
    size(tester, const Size(900, 520));
    final film = Film(tester, 'hero');
    await tester.pumpWidget(stage(BankCard3D(card: cards[5], width: 500, display: CardDisplay.everything)));
    await film.roll(80);
    await film.doubleTap(find.byType(BankCard3D));
    await film.roll(40);
    await film.doubleTap(find.byType(BankCard3D));
    await film.roll(30);
    await tester.fling(find.byType(BankCard3D), const Offset(-400, 0), 2600);
    await film.roll(55);
  });

  testWidgets('wallet', (tester) async {
    size(tester, const Size(560, 640));
    final film = Film(tester, 'wallet');
    await tester.pumpWidget(
      stage(BankCardWallet(cards: [cards[5], cards[1], cards[2], cards[3], cards[0]], width: 380)),
    );
    await film.roll(50);
    final top = tester.getTopLeft(find.byType(BankCardWallet));
    await tester.tapAt(top + const Offset(190, 152));
    await film.roll(38);
    await film.doubleTap(find.byType(BankCard3D).last);
    await film.roll(36);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(top + const Offset(190, 80));
    await film.roll(36);
  });

  testWidgets('form', (tester) async {
    size(tester, const Size(520, 640));
    final film = Film(tester, 'form');
    await tester.pumpWidget(stage(const SizedBox(width: 420, child: BankCardForm(cardWidth: 400))));
    await film.roll(72);
    final fields = find.byType(TextFormField);
    const number = '4532015112830366';
    for (var i = 1; i <= number.length; i++) {
      await tester.enterText(fields.at(0), number.substring(0, i));
      await film.roll(i == 1 ? 14 : 3);
    }
    const name = 'Mohammad Othman';
    for (var i = 2; i <= name.length; i += 2) {
      await tester.enterText(fields.at(1), name.substring(0, i));
      await film.roll(2);
    }
    await tester.enterText(fields.at(1), name);
    await tester.enterText(fields.at(2), '0829');
    await film.roll(14);
    await tester.tap(fields.at(3));
    await tester.enterText(fields.at(3), '742');
    await film.roll(40);
    await tester.tap(fields.at(0));
    await film.roll(36);
  });
}
