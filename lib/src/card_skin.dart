import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

import 'bank_card.dart';

/// How the card is drawn.
enum CardLook {
  /// embossed digits, chip, magstripe, hologram, real materials
  photoreal,

  /// frosted glass over moving light
  glass,
}

/// The surface of a photoreal card.
enum CardFinish {
  /// Matte plastic with a printed security pattern.
  plastic,

  /// Hairline-brushed foil that throws a highlight band as it turns.
  brushed,

  /// Spun black metal, brushed in circles.
  metal,
}

/// Colors and material of a card. Every brand and tier has one, see [CardSkin.of].
@immutable
class CardSkin {
  const CardSkin({
    required this.colors,
    required this.ink,
    required this.foil,
    required this.glow,
    this.finish = CardFinish.plastic,
    this.edge,
  });

  /// Gradient across the body, top-left to bottom-right.
  final List<Color> colors;

  /// Printed text and marks.
  final Color ink;

  /// The tipping on embossed digits.
  final Color foil;

  /// Light drifting under the glass look.
  final Color glow;
  final CardFinish finish;

  /// the side edge you see when it turns
  final Color? edge;

  Color get edgeColor =>
      edge ??
      switch (finish) {
        CardFinish.metal => const Color(0xFF8D9096),
        CardFinish.brushed => Color.lerp(colors[1], const Color(0xFFE8E8E8), 0.45)!,
        CardFinish.plastic => Color.lerp(colors[1], const Color(0xFFF2F2F2), 0.7)!,
      };

  bool get isLight => colors[1].computeLuminance() > 0.4;

  /// one color of yours, ink goes black or white whichever reads
  factory CardSkin.branded(Color color, {CardFinish finish = CardFinish.plastic}) {
    final hsl = HSLColor.fromColor(color);
    Color shade(double dl) => hsl.withLightness((hsl.lightness + dl).clamp(0.0, 1.0)).toColor();
    final light = color.computeLuminance() > 0.4;
    return CardSkin(
      colors: [shade(-0.08), color, shade(-0.2)],
      ink: light ? const Color(0xFF15181D) : const Color(0xFFFFFFFF),
      foil: light ? const Color(0xFF2A2E35) : const Color(0xFFE9EBEF),
      glow: hsl.withHue((hsl.hue + 40) % 360).withLightness(0.6).toColor(),
      finish: finish,
    );
  }

  /// The skin each brand and tier ships with.
  static CardSkin of(CardBrand? brand, CardTier tier) => switch (tier) {
    CardTier.gold => _gold,
    CardTier.platinum => _platinum,
    CardTier.signature => _signature,
    CardTier.infinite => _infinite,
    CardTier.world => _world,
    CardTier.worldElite => _worldElite,
    CardTier.standard => switch (brand) {
      CardBrand.visa => _visaClassic,
      CardBrand.mastercard => _mastercardStandard,
      null => blank,
    },
  };

  /// The card before its brand is known.
  static const blank = CardSkin(
    colors: [Color(0xFF2C2F36), Color(0xFF41454F), Color(0xFF1C1E23)],
    ink: Color(0xFFF3F4F6),
    foil: Color(0xFFDADDE2),
    glow: Color(0xFF7D8AA8),
  );

  static const _visaClassic = CardSkin(
    colors: [Color(0xFF1A1F71), Color(0xFF2445B3), Color(0xFF0C1150)],
    ink: Color(0xFFFFFFFF),
    foil: Color(0xFFE6E9F2),
    glow: Color(0xFF3FA7FF),
  );

  static const _mastercardStandard = CardSkin(
    colors: [Color(0xFF14243B), Color(0xFF1F4868), Color(0xFF0A1624)],
    ink: Color(0xFFFFFFFF),
    foil: Color(0xFFE4E8EE),
    glow: Color(0xFFFF7A1A),
  );

  static const _gold = CardSkin(
    colors: [Color(0xFFB4892C), Color(0xFFEBD089), Color(0xFF94701F)],
    ink: Color(0xFF2B1F08),
    foil: Color(0xFF3A2A0C),
    glow: Color(0xFFFFC94D),
    finish: CardFinish.brushed,
  );

  static const _platinum = CardSkin(
    colors: [Color(0xFF8C939B), Color(0xFFE5E8EC), Color(0xFF79808A)],
    ink: Color(0xFF1B2026),
    foil: Color(0xFF262B32),
    glow: Color(0xFF9EC9FF),
    finish: CardFinish.brushed,
  );

  static const _signature = CardSkin(
    colors: [Color(0xFF26282F), Color(0xFF4B505C), Color(0xFF17181C)],
    ink: Color(0xFFF2F3F5),
    foil: Color(0xFFE2E4E8),
    glow: Color(0xFFB59CFF),
    finish: CardFinish.brushed,
  );

  static const _infinite = CardSkin(
    colors: [Color(0xFF060607), Color(0xFF1F2025), Color(0xFF050506)],
    ink: Color(0xFFE6E2D8),
    foil: Color(0xFFD9C08A),
    glow: Color(0xFFD9B26A),
    finish: CardFinish.metal,
  );

  static const _world = CardSkin(
    colors: [Color(0xFF3B0B1F), Color(0xFF751B3A), Color(0xFF22050F)],
    ink: Color(0xFFFFFFFF),
    foil: Color(0xFFEDE3E6),
    glow: Color(0xFFFF4F6A),
  );

  static const _worldElite = CardSkin(
    colors: [Color(0xFF07080A), Color(0xFF22252B), Color(0xFF060607)],
    ink: Color(0xFFE9EBEE),
    foil: Color(0xFFCDD2D9),
    glow: Color(0xFFFF8A3D),
    finish: CardFinish.metal,
  );

  static CardSkin lerp(CardSkin a, CardSkin b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    return CardSkin(
      colors: [for (var i = 0; i < 3; i++) Color.lerp(a.colors[i], b.colors[i], t)!],
      ink: Color.lerp(a.ink, b.ink, t)!,
      foil: Color.lerp(a.foil, b.foil, t)!,
      glow: Color.lerp(a.glow, b.glow, t)!,
      finish: t < 0.5 ? a.finish : b.finish,
      edge: Color.lerp(a.edgeColor, b.edgeColor, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CardSkin &&
      other.colors[0] == colors[0] &&
      other.colors[1] == colors[1] &&
      other.colors[2] == colors[2] &&
      other.ink == ink &&
      other.foil == foil &&
      other.glow == glow &&
      other.finish == finish &&
      other.edge == edge;

  @override
  int get hashCode => Object.hash(Object.hashAll(colors), ink, foil, glow, finish, edge);
}
