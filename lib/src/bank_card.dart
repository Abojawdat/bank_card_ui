/// The two payment networks this package draws.
enum CardBrand {
  visa('Visa'),
  mastercard('Mastercard');

  const CardBrand(this.label);

  /// The network's name as it is written in English.
  final String label;

  /// brand from the first digits, null if its not visa/mastercard or too short to tell
  static CardBrand? detect(String number) {
    final prefix = RegExp(r'^\d*').stringMatch(BankCard.normalize(number))!;
    if (prefix.isEmpty) return null;
    if (prefix.startsWith('4')) return visa;
    if (prefix.length < 2) return null;

    final two = int.parse(prefix.substring(0, 2));
    if (two >= 51 && two <= 55) return mastercard;
    // The 2-series runs 2221–2720. With fewer than four digits only the
    // prefixes wholly inside that range are certain.
    if (prefix.length >= 4) {
      final four = int.parse(prefix.substring(0, 4));
      return four >= 2221 && four <= 2720 ? mastercard : null;
    }
    return two >= 23 && two <= 26 ? mastercard : null;
  }

  /// reads `visa`, `VISA`, `MasterCard`, `mc`... null for anything else
  static CardBrand? tryParse(String? name) {
    final key = name?.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
    return switch (key) {
      'visa' => visa,
      'mastercard' || 'master' || 'mc' => mastercard,
      _ => null,
    };
  }
}

/// the tier printed on the card, it also picks the material (plastic, foil, metal)
enum CardTier {
  standard,
  gold,
  platinum,
  signature,
  infinite,
  world,
  worldElite;

  /// empty for the entry tier, nobody prints that one
  String printedName(CardBrand? brand) => switch (this) {
    standard => '',
    gold => 'GOLD',
    platinum => 'PLATINUM',
    signature => 'SIGNATURE',
    infinite => 'INFINITE',
    world => 'World',
    worldElite => 'World Elite',
  };

  /// reads `platinum`, `World Elite`, `VISA_SIGNATURE` and so on
  static CardTier? tryParse(String? name) {
    final key = name?.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
    if (key == null || key.isEmpty) return null;
    if (key.contains('elite')) return worldElite;
    if (key.contains('infinite')) return infinite;
    if (key.contains('signature')) return signature;
    if (key.contains('platinum')) return platinum;
    if (key.contains('gold')) return gold;
    if (key.contains('world')) return world;
    if (key.contains('classic') || key.contains('standard')) return standard;
    return null;
  }
}

/// debit / credit / prepaid, printed top right
enum CardKind {
  debit,
  credit,
  prepaid;

  static CardKind? tryParse(String? name) {
    final key = name?.toLowerCase() ?? '';
    for (final kind in values) {
      if (key.contains(kind.name)) return kind;
    }
    return null;
  }
}

/// why a card failed validation, [BankCardLabels.issue] turns it into a sentence
enum CardIssue { unsupportedBrand, incompleteNumber, failedChecksum, invalidExpiry, expired, missingHolder, invalidCvv }

/// One Visa or Mastercard card. The number can be masked like `424242******4242`.
class BankCard {
  BankCard({
    required String number,
    String holderName = '',
    this.expiryMonth,
    int? expiryYear,
    String cvv = '',
    CardBrand? brand,
    this.tier = CardTier.standard,
    this.kind,
  }) : number = normalize(number),
       holderName = holderName.trim(),
       expiryYear = expiryYear != null && expiryYear < 100 ? 2000 + expiryYear : expiryYear,
       cvv = normalize(cvv),
       _brand = brand;

  /// Digits, with `•` standing for each masked position. No spaces.
  final String number;
  final String holderName;
  final int? expiryMonth;

  /// Four digits. A two-digit year passed in is read as 20xx.
  final int? expiryYear;

  /// never goes out in [toJson]
  final String cvv;
  final CardTier tier;
  final CardKind? kind;

  final CardBrand? _brand;

  /// The brand passed in, or the one detected from [number].
  CardBrand? get brand => _brand ?? CardBrand.detect(number);

  bool get isMasked => number.contains('•');

  String get last4 => number.length < 4 ? number : number.substring(number.length - 4);

  /// The lengths the brand issues: Visa 13, 16 or 19; Mastercard 16.
  List<int> get validLengths => switch (brand) {
    CardBrand.visa => const [13, 16, 19],
    _ => const [16],
  };

  /// `MM/YY`, or an empty string when either part is missing.
  String get expiry {
    if (expiryMonth == null || expiryYear == null) return '';
    final month = '$expiryMonth'.padLeft(2, '0');
    return '$month/${'${expiryYear! % 100}'.padLeft(2, '0')}';
  }

  /// Cards are valid through the last day of their expiry month.
  bool isExpired([DateTime? now]) {
    if (expiryMonth == null || expiryYear == null) return false;
    now ??= DateTime.now();
    return !now.isBefore(DateTime(expiryYear!, expiryMonth! + 1));
  }

  /// The Luhn check digit. Masked numbers cannot be checked and return false.
  bool get passesLuhn {
    if (number.isEmpty || isMasked) return false;
    var sum = 0;
    for (var i = 0; i < number.length; i++) {
      var d = number.codeUnitAt(number.length - 1 - i) - 48;
      if (i.isOdd) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
    }
    return sum % 10 == 0;
  }

  CardIssue? get numberIssue {
    if (brand == null) return CardIssue.unsupportedBrand;
    if (isMasked) return null;
    if (!validLengths.contains(number.length)) {
      return CardIssue.incompleteNumber;
    }
    return passesLuhn ? null : CardIssue.failedChecksum;
  }

  CardIssue? expiryIssueAt([DateTime? now]) {
    final month = expiryMonth;
    if (month == null || expiryYear == null || month < 1 || month > 12) {
      return CardIssue.invalidExpiry;
    }
    return isExpired(now) ? CardIssue.expired : null;
  }

  CardIssue? get expiryIssue => expiryIssueAt();

  /// Both networks use a three-digit code.
  CardIssue? get cvvIssue => RegExp(r'^\d{3}$').hasMatch(cvv) ? null : CardIssue.invalidCvv;

  CardIssue? get holderIssue => holderName.isEmpty ? CardIssue.missingHolder : null;

  /// first problem with the number or expiry, null when its fine
  CardIssue? get issue => numberIssue ?? expiryIssue;

  /// same as [issue] but also checks holder and cvv, for the form
  CardIssue? get entryIssue => issue ?? holderIssue ?? cvvIssue;

  /// groups of four, [masked] keeps only the last four
  String formatted({bool masked = false}) {
    var digits = number;
    if (masked && digits.length > 4) {
      digits = '•' * (digits.length - 4) + last4;
    }
    final groups = <String>[];
    for (var i = 0; i < digits.length; i += 4) {
      groups.add(digits.substring(i, i + 4 > digits.length ? digits.length : i + 4));
    }
    return groups.join(' ');
  }

  /// arabic digits to ascii, any mask char (* x # ●) to •, drops the rest
  static String normalize(String raw) {
    final out = StringBuffer();
    for (final rune in raw.runes) {
      if (rune >= 0x30 && rune <= 0x39) {
        out.writeCharCode(rune);
      } else if (rune >= 0x660 && rune <= 0x669) {
        out.writeCharCode(rune - 0x660 + 0x30);
      } else if (rune >= 0x6F0 && rune <= 0x6F9) {
        out.writeCharCode(rune - 0x6F0 + 0x30);
      } else if ('*xX#•●·'.runes.contains(rune)) {
        out.write('•');
      }
    }
    return out.toString();
  }

  /// null when the number isnt visa or mastercard
  static BankCard? tryParse(
    String number, {
    String holderName = '',
    String expiry = '',
    CardTier tier = CardTier.standard,
    CardKind? kind,
  }) {
    final (month, year) = parseExpiry(expiry);
    final card = BankCard(
      number: number,
      holderName: holderName,
      expiryMonth: month,
      expiryYear: year,
      tier: tier,
      kind: kind,
    );
    return card.brand == null ? null : card;
  }

  /// Reads whatever shape your backend sends (stripe, masked_pan, exp_month...). Null if theres no usable number.
  static BankCard? tryFromJson(Map<String, dynamic> json) {
    final nested = json['card'];
    final source = {...json, if (nested is Map) ...nested};

    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = source[key];
        if (value != null && '$value'.trim().isNotEmpty) return '$value'.trim();
      }
      return null;
    }

    var number = pick(const [
      'number',
      'card_number',
      'cardNumber',
      'pan',
      'masked_pan',
      'maskedPan',
      'masked_number',
      'maskedNumber',
      'card_no',
      'cardNo',
    ]);
    if (number == null) {
      final last4 = pick(const ['last4', 'last_4', 'last_four', 'lastFour']);
      if (last4 == null) return null;
      final bin = normalize(pick(const ['bin', 'iin', 'first6', 'first_six']) ?? '');
      final hidden = 16 - bin.length - last4.length;
      number = '$bin${'•' * (hidden < 0 ? 0 : hidden)}$last4';
    }

    var (month, year) = parseExpiry(
      pick(const [
            'expiry',
            'expiry_date',
            'expiryDate',
            'exp',
            'exp_date',
            'expDate',
            'expires',
            'expiration',
            'expiration_date',
            'valid_thru',
            'validThru',
          ]) ??
          '',
    );
    month ??= int.tryParse(
      normalize(pick(const ['exp_month', 'expiry_month', 'expMonth', 'expiryMonth', 'month']) ?? ''),
    );
    year ??= int.tryParse(normalize(pick(const ['exp_year', 'expiry_year', 'expYear', 'expiryYear', 'year']) ?? ''));

    final card = BankCard(
      number: number,
      holderName:
          pick(const [
            'holder_name',
            'holderName',
            'cardholder_name',
            'cardholderName',
            'card_holder',
            'cardHolder',
            'name_on_card',
            'nameOnCard',
            'holder',
            'name',
          ]) ??
          '',
      expiryMonth: month,
      expiryYear: year,
      brand: CardBrand.tryParse(
        pick(const ['brand', 'scheme', 'network', 'card_brand', 'cardBrand', 'card_scheme', 'type']),
      ),
      tier:
          CardTier.tryParse(
            pick(const ['tier', 'level', 'product', 'card_level', 'cardLevel', 'category', 'product_name']),
          ) ??
          CardTier.standard,
      kind: CardKind.tryParse(pick(const ['funding', 'kind', 'card_type', 'cardType', 'type'])),
    );
    return card.brand == null ? null : card;
  }

  /// The card as snake_case JSON. The CVV is left out on purpose.
  Map<String, dynamic> toJson() => {
    'number': number,
    'holder_name': holderName,
    'expiry_month': expiryMonth,
    'expiry_year': expiryYear,
    'brand': brand?.name,
    'tier': tier.name,
    'kind': kind?.name,
  };

  BankCard copyWith({
    String? number,
    String? holderName,
    int? expiryMonth,
    int? expiryYear,
    String? cvv,
    CardBrand? brand,
    CardTier? tier,
    CardKind? kind,
  }) => BankCard(
    number: number ?? this.number,
    holderName: holderName ?? this.holderName,
    expiryMonth: expiryMonth ?? this.expiryMonth,
    expiryYear: expiryYear ?? this.expiryYear,
    cvv: cvv ?? this.cvv,
    brand: brand ?? _brand,
    tier: tier ?? this.tier,
    kind: kind ?? this.kind,
  );

  @override
  bool operator ==(Object other) =>
      other is BankCard &&
      other.number == number &&
      other.holderName == holderName &&
      other.expiryMonth == expiryMonth &&
      other.expiryYear == expiryYear &&
      other.cvv == cvv &&
      other.brand == brand &&
      other.tier == tier &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(number, holderName, expiryMonth, expiryYear, cvv, brand, tier, kind);

  @override
  String toString() => 'BankCard(${brand?.label} ${formatted(masked: true)})';

  /// `08/29`, `8/2029`, `2029-08`, `0829`, `٠٨/٢٩` → (8, 2029)
  static (int?, int?) parseExpiry(String raw) {
    final text = raw.replaceAllMapped(RegExp('[٠-٩۰-۹]'), (m) => BankCard.normalize(m[0]!));
    final iso = RegExp(r'^(\d{4})-(\d{1,2})').firstMatch(text);
    if (iso != null) return (int.parse(iso[2]!), int.parse(iso[1]!));

    final parts = RegExp(r'\d+').allMatches(text).map((m) => m[0]!).toList();
    if (parts.length >= 2) {
      final year = int.parse(parts[1]);
      return (int.parse(parts[0]), year < 100 ? 2000 + year : year);
    }
    if (parts.length == 1 && parts[0].length == 4) {
      return (int.parse(parts[0].substring(0, 2)), 2000 + int.parse(parts[0].substring(2)));
    }
    return (null, null);
  }
}
