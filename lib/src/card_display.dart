import 'package:flutter/foundation.dart';

enum NumberDisplay { full, lastFour, mask, hide }

enum FieldDisplay { show, mask, hide }

/// Picks what the card shows and what it hides.
///
/// Anything the backend didnt send is drawn as [mask] instead of leaving a hole,
/// so a record with only `last4` still looks like a whole card.
@immutable
class CardDisplay {
  const CardDisplay({
    this.number = NumberDisplay.lastFour,
    this.holder = FieldDisplay.show,
    this.expiry = FieldDisplay.show,
    this.cvv = FieldDisplay.mask,
    this.chip = true,
    this.contactless = true,
    this.tierName = true,
    this.kindName = true,
    this.mask = '*',
  }) : assert(mask == '*' || mask == '•', "mask is '*' or '•'");

  final NumberDisplay number;
  final FieldDisplay holder;
  final FieldDisplay expiry;
  final FieldDisplay cvv;
  final bool chip;
  final bool contactless;

  /// PLATINUM, World Elite...
  final bool tierName;

  /// DEBIT, CREDIT, PREPAID
  final bool kindName;
  final String mask;

  /// every field in the clear, cvv too. the form uses this
  static const everything = CardDisplay(number: NumberDisplay.full, cvv: FieldDisplay.show);

  /// last four and the brand, nothing personal
  static const private = CardDisplay(holder: FieldDisplay.mask, expiry: FieldDisplay.mask);

  CardDisplay copyWith({
    NumberDisplay? number,
    FieldDisplay? holder,
    FieldDisplay? expiry,
    FieldDisplay? cvv,
    bool? chip,
    bool? contactless,
    bool? tierName,
    bool? kindName,
    String? mask,
  }) => CardDisplay(
    number: number ?? this.number,
    holder: holder ?? this.holder,
    expiry: expiry ?? this.expiry,
    cvv: cvv ?? this.cvv,
    chip: chip ?? this.chip,
    contactless: contactless ?? this.contactless,
    tierName: tierName ?? this.tierName,
    kindName: kindName ?? this.kindName,
    mask: mask ?? this.mask,
  );

  @override
  bool operator ==(Object other) =>
      other is CardDisplay &&
      other.number == number &&
      other.holder == holder &&
      other.expiry == expiry &&
      other.cvv == cvv &&
      other.chip == chip &&
      other.contactless == contactless &&
      other.tierName == tierName &&
      other.kindName == kindName &&
      other.mask == mask;

  @override
  int get hashCode => Object.hash(number, holder, expiry, cvv, chip, contactless, tierName, kindName, mask);
}
