import 'package:flutter/widgets.dart';

import 'bank_card.dart';
import 'card_display.dart';
import 'card_labels.dart';
import 'card_painter.dart';
import 'card_skin.dart';

/// A flat card, no animation. Cheap enough for lists.
class BankCardView extends StatelessWidget {
  const BankCardView({
    required this.card,
    this.width = 320,
    this.side = CardSide.front,
    this.look = CardLook.photoreal,
    this.skin,
    this.labels,
    this.display = const CardDisplay(),
    this.shadow = true,
    super.key,
  });

  final BankCard card;
  final double width;
  final CardSide side;
  final CardLook look;
  final CardSkin? skin;
  final BankCardLabels? labels;
  final CardDisplay display;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final height = width / kCardAspectRatio;
    Widget child = CustomPaint(
      size: Size(width, height),
      painter: CardFacePainter(
        card: card,
        skin: skin ?? CardSkin.of(card.brand, card.tier),
        look: look,
        labels: labels ?? BankCardLabels.of(context),
        side: side,
        display: display,
        fontFamily: DefaultTextStyle.of(context).style.fontFamily,
      ),
    );
    if (shadow) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.037),
          boxShadow: [
            BoxShadow(color: const Color(0x40000000), blurRadius: width * 0.06, offset: Offset(0, width * 0.025)),
          ],
        ),
        child: child,
      );
    }
    return Semantics(label: semanticLabel(card), image: true, child: child);
  }
}

/// Just the Visa or Mastercard logo, for lists and text fields.
class CardBrandMark extends StatelessWidget {
  const CardBrandMark({required this.brand, this.height = 24, this.color, super.key});

  final CardBrand brand;
  final double height;

  /// visa wordmark colour, defaults to visa blue
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final family = DefaultTextStyle.of(context).style.fontFamily;
    return Semantics(
      label: brand.label,
      child: CustomPaint(
        size: Size(height * 1.62, height),
        painter: _MarkPainter(brand, color ?? const Color(0xFF1A1F71), family),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.brand, this.color, this.family);

  final CardBrand brand;
  final Color color;
  final String? family;

  @override
  void paint(Canvas canvas, Size size) => brand == CardBrand.visa
      ? paintVisa(canvas, Offset.zero & size, color, family)
      : paintMastercard(canvas, size.center(Offset.zero), size.height / 2);

  @override
  bool shouldRepaint(_MarkPainter old) => old.brand != brand || old.color != color || old.family != family;
}

String semanticLabel(BankCard card) => '${card.brand?.label ?? 'Card'} •••• ${card.last4}';
