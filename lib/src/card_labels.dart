import 'package:flutter/widgets.dart';

import 'bank_card.dart';

/// Every word on screen, english or arabic. Picked from the app locale.
@immutable
class BankCardLabels {
  const BankCardLabels({
    required this.validThru,
    required this.signature,
    required this.backNotice,
    required this.holderPlaceholder,
    required this.number,
    required this.holder,
    required this.expiry,
    required this.cvv,
    required this.kinds,
    required this.issues,
  });

  /// Printed beside the expiry, on two lines.
  final String validThru;

  /// Printed above the signature panel.
  final String signature;

  /// The small print on the back.
  final String backNotice;

  /// Shown faintly on a card whose holder is still blank.
  final String holderPlaceholder;

  // Form field labels.
  final String number;
  final String holder;
  final String expiry;
  final String cvv;

  final Map<CardKind, String> kinds;
  final Map<CardIssue, String> issues;

  String issue(CardIssue issue) => issues[issue]!;

  static const english = BankCardLabels(
    validThru: 'VALID\nTHRU',
    signature: 'AUTHORIZED SIGNATURE — NOT VALID UNLESS SIGNED',
    backNotice:
        'This card remains the property of the issuing bank and must be '
        'returned on request. Use of this card is subject to the cardholder '
        'agreement. If found, please return it to the bank that issued it.',
    holderPlaceholder: 'CARDHOLDER NAME',
    number: 'Card number',
    holder: 'Cardholder name',
    expiry: 'Expiry (MM/YY)',
    cvv: 'CVV',
    kinds: {CardKind.debit: 'DEBIT', CardKind.credit: 'CREDIT', CardKind.prepaid: 'PREPAID'},
    issues: {
      CardIssue.unsupportedBrand: 'Only Visa and Mastercard are accepted',
      CardIssue.incompleteNumber: 'The card number is incomplete',
      CardIssue.failedChecksum: 'This card number is not valid',
      CardIssue.invalidExpiry: 'Enter the expiry as MM/YY',
      CardIssue.expired: 'This card has expired',
      CardIssue.missingHolder: "Enter the cardholder's name",
      CardIssue.invalidCvv: 'Enter the 3-digit security code',
    },
  );

  static const arabic = BankCardLabels(
    validThru: 'صالحة\nحتى',
    signature: 'توقيع حامل البطاقة — لا تكون صالحة دون توقيع',
    backNotice:
        'هذه البطاقة ملك للمصرف المُصدِر ويجب إعادتها عند الطلب. يخضع استخدامها '
        'لاتفاقية حامل البطاقة. في حال العثور عليها يرجى تسليمها إلى أقرب فرع '
        'للمصرف.',
    holderPlaceholder: 'اسم حامل البطاقة',
    number: 'رقم البطاقة',
    holder: 'اسم حامل البطاقة',
    expiry: 'تاريخ الانتهاء (شهر/سنة)',
    cvv: 'رمز الأمان',
    kinds: {CardKind.debit: 'خصم مباشر', CardKind.credit: 'ائتمان', CardKind.prepaid: 'مسبقة الدفع'},
    issues: {
      CardIssue.unsupportedBrand: 'نقبل بطاقات فيزا وماستركارد فقط',
      CardIssue.incompleteNumber: 'رقم البطاقة غير مكتمل',
      CardIssue.failedChecksum: 'رقم البطاقة غير صحيح',
      CardIssue.invalidExpiry: 'أدخل تاريخ الانتهاء بالشكل MM/YY',
      CardIssue.expired: 'انتهت صلاحية هذه البطاقة',
      CardIssue.missingHolder: 'أدخل اسم حامل البطاقة',
      CardIssue.invalidCvv: 'أدخل رمز الأمان المكوّن من ٣ أرقام',
    },
  );

  /// [arabic] under an Arabic locale, [english] otherwise.
  static BankCardLabels of(BuildContext context) =>
      Localizations.maybeLocaleOf(context)?.languageCode == 'ar' ? arabic : english;

  BankCardLabels copyWith({
    String? validThru,
    String? signature,
    String? backNotice,
    String? holderPlaceholder,
    String? number,
    String? holder,
    String? expiry,
    String? cvv,
    Map<CardKind, String>? kinds,
    Map<CardIssue, String>? issues,
  }) => BankCardLabels(
    validThru: validThru ?? this.validThru,
    signature: signature ?? this.signature,
    backNotice: backNotice ?? this.backNotice,
    holderPlaceholder: holderPlaceholder ?? this.holderPlaceholder,
    number: number ?? this.number,
    holder: holder ?? this.holder,
    expiry: expiry ?? this.expiry,
    cvv: cvv ?? this.cvv,
    kinds: kinds ?? this.kinds,
    issues: issues ?? this.issues,
  );
}
