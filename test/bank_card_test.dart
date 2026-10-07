import 'package:bank_card_3d/bank_card_3d.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects the brand from the prefix', () {
    expect(CardBrand.detect('4'), CardBrand.visa);
    expect(CardBrand.detect('51'), CardBrand.mastercard);
    expect(CardBrand.detect('5'), isNull);
    expect(CardBrand.detect('56'), isNull);
    expect(CardBrand.detect('2221'), CardBrand.mastercard);
    expect(CardBrand.detect('2720 99'), CardBrand.mastercard);
    expect(CardBrand.detect('2721'), isNull);
    expect(CardBrand.detect('2220'), isNull);
    expect(CardBrand.detect('24'), CardBrand.mastercard);
    expect(CardBrand.detect('22'), isNull);
    expect(CardBrand.detect('3782 822463 10005'), isNull);
    expect(CardBrand.detect('•••• •••• •••• 4242'), isNull);
    expect(CardBrand.detect('٤٢٤٢'), CardBrand.visa);
  });

  test('parses brand, tier and kind names', () {
    expect(CardBrand.tryParse('MasterCard'), CardBrand.mastercard);
    expect(CardBrand.tryParse('master_card'), CardBrand.mastercard);
    expect(CardBrand.tryParse('VISA'), CardBrand.visa);
    expect(CardBrand.tryParse('amex'), isNull);
    expect(CardTier.tryParse('World Elite'), CardTier.worldElite);
    expect(CardTier.tryParse('VISA_SIGNATURE'), CardTier.signature);
    expect(CardTier.tryParse('classic'), CardTier.standard);
    expect(CardKind.tryParse('DEBIT'), CardKind.debit);
  });

  test('luhn and length', () {
    expect(BankCard(number: '4532 0151 1283 0366').numberIssue, isNull);
    expect(BankCard(number: '4532 0151 1283 0367').numberIssue, CardIssue.failedChecksum);
    expect(BankCard(number: '4532 0151').numberIssue, CardIssue.incompleteNumber);
    expect(BankCard(number: '5425233430109903').numberIssue, isNull);
    expect(BankCard(number: '378282246310005').numberIssue, CardIssue.unsupportedBrand);
    expect(BankCard(number: '4222222222222').numberIssue, isNull);
    expect(BankCard(number: '4242 •••• •••• 4242').numberIssue, isNull);
  });

  test('expiry', () {
    final now = DateTime(2026, 10, 7);
    BankCard card(int m, int y) => BankCard(number: '4242424242424242', expiryMonth: m, expiryYear: y);
    expect(card(10, 26).expiryIssueAt(now), isNull);
    expect(card(9, 26).expiryIssueAt(now), CardIssue.expired);
    expect(card(13, 30).expiryIssueAt(now), CardIssue.invalidExpiry);
    expect(card(8, 29).expiry, '08/29');
    expect(BankCard.parseExpiry('08/29'), (8, 2029));
    expect(BankCard.parseExpiry('8/2029'), (8, 2029));
    expect(BankCard.parseExpiry('2029-08-31'), (8, 2029));
    expect(BankCard.parseExpiry('0829'), (8, 2029));
    expect(BankCard.parseExpiry('٠٨/٢٩'), (8, 2029));
    expect(BankCard.parseExpiry(''), (null, null));
  });

  test('formats and masks', () {
    final card = BankCard(number: '4532-0151-1283-0366');
    expect(card.number, '4532015112830366');
    expect(card.formatted(), '4532 0151 1283 0366');
    expect(card.formatted(masked: true), '•••• •••• •••• 0366');
    expect(BankCard(number: '4111 1111 1111 1111 003').formatted(), '4111 1111 1111 1111 003');
    expect(BankCard(number: '424242******4242').number, '424242••••••4242');
  });

  test('reads stripe shaped json', () {
    final card = BankCard.tryFromJson({
      'id': 'pm_1',
      'card': {'brand': 'visa', 'last4': '4242', 'exp_month': 8, 'exp_year': 2029, 'funding': 'credit'},
      'billing_details': {'name': null},
    })!;
    expect(card.brand, CardBrand.visa);
    expect(card.number, '••••••••••••4242');
    expect(card.expiry, '08/29');
    expect(card.kind, CardKind.credit);
  });

  test('reads a typical bank api record', () {
    final card = BankCard.tryFromJson({
      'masked_pan': '542523******9903',
      'cardholder_name': 'SARA KAREEM',
      'expiry': '11/28',
      'scheme': 'MASTERCARD',
      'product': 'World Elite',
      'card_type': 'debit',
      'bank_name': 'Baghdad Bank',
    })!;
    expect(card.brand, CardBrand.mastercard);
    expect(card.holderName, 'SARA KAREEM');
    expect(card.expiryYear, 2028);
    expect(card.tier, CardTier.worldElite);
    expect(card.kind, CardKind.debit);
    expect(card.isMasked, isTrue);
  });

  test('json with bin + last4, and records we cant draw', () {
    expect(BankCard.tryFromJson({'bin': '520000', 'last4': '0007'})!.number, '520000••••••0007');
    expect(BankCard.tryFromJson({'last4': '0005', 'brand': 'amex'}), isNull);
    expect(BankCard.tryFromJson({'name': 'no number'}), isNull);
    expect(BankCard.tryFromJson({'number': '6011111111111117'}), isNull);
  });

  test('toJson leaves the cvv out and round trips', () {
    final card = BankCard(
      number: '4532015112830366',
      cvv: '123',
      expiryMonth: 8,
      expiryYear: 2029,
      tier: CardTier.gold,
    );
    final json = card.toJson();
    expect(json.containsKey('cvv'), isFalse);
    expect(BankCard.tryFromJson(json), card.copyWith(cvv: ''));
  });

  test('skins', () {
    expect(CardSkin.of(CardBrand.visa, CardTier.infinite).finish, CardFinish.metal);
    expect(CardSkin.of(null, CardTier.standard), CardSkin.blank);
    final a = CardSkin.of(CardBrand.visa, CardTier.standard);
    final b = CardSkin.of(CardBrand.mastercard, CardTier.gold);
    expect(CardSkin.lerp(a, b, 0), a);
    expect(CardSkin.lerp(a, b, 1), b);
    expect(CardSkin.branded(const Color(0xFFFFFFFF)).ink, const Color(0xFF15181D));
  });
}
