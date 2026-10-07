import 'dart:convert';

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

  /// reads `visa`, `VISA_DEBIT`, `Visa Platinum`, `MasterCard`, `mc`... null for anything else
  static CardBrand? tryParse(String? name) {
    final key = name?.toLowerCase().replaceAll(RegExp('[^a-z]'), '') ?? '';
    if (key.contains('visa')) return visa;
    if (key.contains('master') || key == 'mc') return mastercard;
    return null;
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
    int? expiryMonth,
    int? expiryYear,
    String cvv = '',
    CardBrand? brand,
    this.tier = CardTier.standard,
    this.kind,
  }) : number = normalize(number),
       holderName = holderName.trim().replaceAll(RegExp(r'\s+'), ' '),
       expiryMonth = _year(expiryMonth, expiryYear) == null ? null : expiryMonth,
       expiryYear = _year(expiryMonth, expiryYear),
       cvv = normalize(cvv),
       _brand = brand;

  /// Digits, with `•` standing for each masked position. No spaces.
  final String number;
  final String holderName;
  final int? expiryMonth;

  /// Four digits. A two-digit year passed in is read as 20xx, a broken date becomes null.
  final int? expiryYear;

  static int? _year(int? month, int? year) {
    if (month == null || year == null || month < 1 || month > 12) return null;
    final full = year < 100 ? 2000 + year : year;
    return full < 1990 || full > 2100 ? null : full;
  }

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

  /// A card from only the last four digits, for apis that never send more.
  factory BankCard.lastFour(
    Object last4, {
    CardBrand? brand,
    String holderName = '',
    int? expiryMonth,
    int? expiryYear,
    CardTier tier = CardTier.standard,
    CardKind? kind,
  }) => BankCard(
    number: _tail(_last4(last4)),
    brand: brand,
    holderName: holderName,
    expiryMonth: expiryMonth,
    expiryYear: expiryYear,
    tier: tier,
    kind: kind,
  );

  /// Reads whatever your backend sends and never fails.
  ///
  /// A map in any shape or nesting, a raw json string, a bare `"4242"`, even null.
  /// Anything missing or broken comes out as stars, an unknown brand as a plain card.
  factory BankCard.fromJson(Object? json) {
    if (json is String && json.trimLeft().startsWith('{')) {
      try {
        json = jsonDecode(json);
      } on FormatException {
        // not json after all, read it as a number
      }
    }
    return switch (json) {
      Map map => _read(map),
      String text => BankCard(number: _tail(text)),
      num n => BankCard(number: _tail(_last4(n))),
      _ => BankCard(number: ''),
    };
  }

  /// [BankCard.fromJson], but null when theres no number or last4 at all. handy for filtering lists
  static BankCard? tryFromJson(Object? json) {
    final card = BankCard.fromJson(json);
    return card.number.isEmpty ? null : card;
  }

  static BankCard _read(Map json) {
    final fields = _flatten(json);

    Object? raw(List<String> keys) {
      for (final key in keys) {
        final value = fields[key];
        if (value == null || value is Iterable) continue;
        final text = '$value'.trim().toLowerCase();
        if (text.isNotEmpty && !_blank.contains(text)) return value;
      }
      return null;
    }

    String? pick(List<String> keys) {
      final value = raw(keys);
      return value is num ? '${value is int ? value : value.toInt()}' : value?.toString().trim();
    }

    var number = _tail(pick(_numberKeys) ?? '');
    if (!number.contains(RegExp(r'\d'))) {
      final tail = raw(_last4Keys);
      final last4 = tail == null ? '' : _last4(tail);
      var bin = normalize(pick(_binKeys) ?? '').replaceAll('•', '');
      if (bin.length > 8) bin = bin.substring(0, 8);
      if (last4.isNotEmpty || bin.isNotEmpty) {
        number = bin + '•' * (16 - bin.length - last4.length).clamp(0, 16) + last4;
      }
    }

    var (month, year) = parseExpiry(pick(_expiryKeys) ?? '');
    if (_year(month, year) == null) {
      month = _int(pick(_monthKeys));
      year = _int(pick(_yearKeys));
    }

    final brandText = pick(_brandKeys);
    final tierText = pick(_tierKeys);
    return BankCard(
      number: number,
      holderName: pick(_holderKeys) ?? '',
      expiryMonth: month,
      expiryYear: year,
      cvv: pick(_cvvKeys) ?? '',
      brand: CardBrand.tryParse(brandText) ?? CardBrand.tryParse(tierText),
      tier: CardTier.tryParse(tierText) ?? CardTier.tryParse(brandText) ?? CardTier.standard,
      kind: CardKind.tryParse(pick(_kindKeys)) ?? CardKind.tryParse(brandText),
    );
  }

  // keys compared lowercase with _ - and spaces gone, so card_number, CardNumber and CARD-NUMBER all match
  static const _numberKeys = [
    'number', 'cardnumber', 'pan', 'maskedpan', 'maskednumber', 'maskedcardnumber', 'cardno', 'cardnum', //
    'cardpan', 'primaryaccountnumber', 'displaynumber',
  ];
  static const _last4Keys = [
    'last4', 'lastfour', 'last4digits', 'lastfourdigits', 'lastdigits', 'cardlast4', 'cardlastfour', //
    'panlast4', 'endingin', 'ending', 'suffix',
  ];
  static const _binKeys = ['bin', 'iin', 'first6', 'firstsix', 'first6digits', 'first8', 'cardbin'];
  static const _expiryKeys = [
    'expiry', 'expirydate', 'exp', 'expdate', 'expires', 'expiresat', 'expiration', 'expirationdate', //
    'validthru', 'validthrough', 'validuntil', 'cardexpiry',
  ];
  static const _monthKeys = ['expmonth', 'expirymonth', 'expirationmonth', 'cardexpmonth', 'month'];
  static const _yearKeys = ['expyear', 'expiryyear', 'expirationyear', 'cardexpyear', 'year'];
  static const _holderKeys = [
    'holdername', 'cardholdername', 'cardholder', 'nameoncard', 'holder', 'cardname', 'ownername', 'owner', //
    'customername', 'fullname', 'name',
  ];
  static const _brandKeys = [
    'brand', 'scheme', 'network', 'cardbrand', 'cardscheme', 'cardnetwork', 'paymentbrand', 'paymentnetwork', //
    'cardtype', 'type', 'issuer',
  ];
  static const _tierKeys = [
    'tier',
    'level',
    'product',
    'cardlevel',
    'cardproduct',
    'productname',
    'category',
    'cardcategory',
  ];
  static const _kindKeys = ['funding', 'fundingtype', 'kind', 'cardkind', 'cardtype', 'type', 'accounttype'];
  static const _cvvKeys = ['cvv', 'cvc', 'cvv2', 'cvc2', 'securitycode'];
  static const _blank = {'null', 'none', 'nil', 'undefined', 'unknown', 'n/a', 'na', '-', '--'};

  static Map<String, Object?> _flatten(Map json) {
    final out = <String, Object?>{};
    final queue = [(json, 0)];
    for (var i = 0; i < queue.length; i++) {
      final (map, depth) = queue[i];
      for (final MapEntry(:key, :value) in map.entries) {
        final name = '$key'.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
        if (value is Map) {
          // a bank or address name is not the cardholder
          if (depth < 3 && !RegExp('bank|issuer|merchant|address|shipping').hasMatch(name)) {
            queue.add((value, depth + 1));
          }
        } else {
          out.putIfAbsent(name, () => value);
        }
      }
    }
    return out;
  }

  // anything shorter than a real card is the end of one
  static String _tail(String raw) {
    final n = normalize(raw);
    return n.isEmpty || n.length >= 12 ? n : n.padLeft(16, '•');
  }

  static String _last4(Object value) {
    var d = normalize(value is num ? '${value.toInt()}' : '$value').replaceAll('•', '');
    if (value is num) d = d.padLeft(4, '0');
    return d.length > 4 ? d.substring(d.length - 4) : d;
  }

  static int? _int(String? text) {
    if (text == null) return null;
    return num.tryParse(text)?.toInt() ?? int.tryParse(normalize(text));
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
      final yearFirst = parts[0].length == 4;
      final year = int.parse(yearFirst ? parts[0] : parts[1]);
      return (int.parse(yearFirst ? parts[1] : parts[0]), year < 100 ? 2000 + year : year);
    }
    if (parts.length == 1 && parts[0].length == 4) {
      return (int.parse(parts[0].substring(0, 2)), 2000 + int.parse(parts[0].substring(2)));
    }
    return (null, null);
  }
}
