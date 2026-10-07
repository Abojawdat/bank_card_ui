import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/rendering.dart';

import 'bank_card.dart';
import 'card_display.dart';
import 'card_labels.dart';
import 'card_skin.dart';

const double _w = 85.60;
const double _h = 53.98;

/// width / height of a real bank card (ISO ID-1)
const double kCardAspectRatio = _w / _h;

enum CardSide { front, back }

final RRect _shape = RRect.fromLTRBR(0, 0, _w, _h, const Radius.circular(3.18));
const Rect _rect = Rect.fromLTWH(0, 0, _w, _h);

const List<Color> _rainbow = [
  Color(0xFFFF5E8A),
  Color(0xFFFFC85E),
  Color(0xFF7CFFB2),
  Color(0xFF5EC8FF),
  Color(0xFFB57CFF),
  Color(0xFFFF5E8A),
];
const List<double> _rainbowStops = [0, 0.2, 0.4, 0.6, 0.8, 1];

class CardFacePainter extends CustomPainter {
  CardFacePainter({
    required this.card,
    required this.skin,
    required this.look,
    required this.labels,
    required this.side,
    this.display = const CardDisplay(),
    this.placeholders = false,
    this.tiltX = 0,
    this.tiltY = 0,
    this.intro = 1,
    this.logo = 1,
    this.stampIndex = -1,
    this.stamp = 1,
    this.time = 0,
    this.fontFamily,
    this.baked,
  });

  final BankCard card;
  final CardSkin skin;
  final CardLook look;
  final BankCardLabels labels;
  final CardSide side;
  final CardDisplay display;
  final bool placeholders;
  final double tiltX;
  final double tiltY;
  final double intro;
  final double logo;
  final int stampIndex;
  final double stamp;
  final double time;
  final String? fontFamily;

  // the face painted once, so a frame is just this image plus the light on top
  final ui.Image? baked;

  bool get _glass => look == CardLook.glass;

  Color get _ink => _glass ? const Color(0xFFFFFFFF) : skin.ink;

  Offset get _light {
    final l = Offset(-0.55 - tiltY * 0.9, -0.85 + tiltX * 0.9);
    return l / l.distance;
  }

  double _phase(double start, double length) => ((intro - start) / length).clamp(0.0, 1.0);

  String get _m => display.mask;

  @override
  void paint(Canvas canvas, Size size) {
    final image = baked;
    canvas.save();
    canvas.scale(size.width / _w);
    canvas.clipRRect(_shape);
    if (image == null || _glass) _body(canvas);
    if (image == null) {
      _content(canvas);
    } else {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        _rect,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    _lighting(canvas);
    canvas.restore();
  }

  void _content(Canvas canvas) => side == CardSide.front ? _front(canvas) : _back(canvas);

  ui.Image bake(Size size, double ratio) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(ratio * size.width / _w)
      ..clipRRect(_shape);
    if (!_glass) _body(canvas);
    _content(canvas);
    final picture = recorder.endRecording();
    final image = picture.toImageSync((size.width * ratio).ceil(), (size.height * ratio).ceil());
    picture.dispose();
    return image;
  }

  void _body(Canvas canvas) {
    final colors = _glass ? [for (final c in skin.colors) Color.lerp(c, const Color(0xFF04050A), 0.5)!] : skin.colors;
    canvas.drawRect(
      _rect,
      Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(_w, _h), colors, const [0, 0.55, 1]),
    );
    if (_glass) _orbs(canvas);
    final texture = _pattern(_glass ? null : skin.finish, card.brand, skin.isLight);
    canvas.drawImageRect(
      texture,
      Rect.fromLTWH(0, 0, texture.width.toDouble(), texture.height.toDouble()),
      _rect,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  void _orbs(Canvas canvas) {
    final colors = switch (card.brand) {
      CardBrand.visa => [skin.glow, const Color(0xFF2B3CFF), const Color(0xFF00B8FF)],
      CardBrand.mastercard => [const Color(0xFFEB001B), const Color(0xFFF79E1B), skin.glow],
      null => [skin.glow, const Color(0xFF5B6BFF), const Color(0xFF2DD4BF)],
    };
    const spots = [(0.12, 0.08, 34.0, 1.0), (0.95, 0.98, 38.0, 0.6), (0.66, 0.2, 22.0, 1.7)];
    for (var i = 0; i < spots.length; i++) {
      final (fx, fy, r, depth) = spots[i];
      final drift = Offset(math.sin(time * 0.35 + i * 2.1), math.cos(time * 0.27 + i * 1.3)) * 4;
      final center = Offset(fx * _w, fy * _h) + drift + Offset(-tiltY, tiltX) * 10 * depth;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = ui.Gradient.radial(center, r, [colors[i].withValues(alpha: 0.9), colors[i].withValues(alpha: 0)]),
      );
    }
  }

  void _front(Canvas canvas) {
    final ink = _ink;
    final kind = card.kind;
    if (kind != null && display.kindName) {
      _text(
        canvas,
        labels.kinds[kind]!,
        const Offset(80.4, 4.9),
        size: 2.0,
        weight: FontWeight.w700,
        color: ink.withValues(alpha: 0.85),
        spacing: 0.35,
        alignRight: true,
      );
    }
    final tier = card.tier.printedName(card.brand);
    if (tier.isNotEmpty && display.tierName) {
      final mc = card.tier == CardTier.world || card.tier == CardTier.worldElite;
      _text(
        canvas,
        tier,
        Offset(80.4, mc ? 36.0 : 36.6),
        size: mc ? 2.4 : 1.9,
        weight: FontWeight.w700,
        italic: mc,
        spacing: mc ? 0 : 0.4,
        alignRight: true,
      );
    }
    if (display.chip) _chip(canvas, _phase(0.26, 0.16));
    if (display.contactless) _contactless(canvas);
    _number(canvas);
    _expiry(canvas);
    _holder(canvas);
    _brandMark(canvas);
    if (intro < 1) _sweep(canvas);
  }

  void _chip(Canvas canvas, double p) {
    if (p <= 0) return;
    const rect = Rect.fromLTRB(9.0, 16.6, 20.6, 25.4);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(1.5));
    canvas.save();
    if (p < 1) {
      final e = Curves.easeOutBack.transform(p);
      final s = 1 + (1 - e) * 1.3;
      canvas.translate(rect.center.dx, rect.center.dy - (1 - e) * 9);
      canvas.scale(s);
      canvas.translate(-rect.center.dx, -rect.center.dy);
    }
    canvas.drawRRect(
      rrect.shift(const Offset(0.14, 0.2)),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.25),
    );
    final shine = (0.5 + tiltY * 0.7 - tiltX * 0.3).clamp(0.2, 0.8);
    final metal = _glass
        ? const [Color(0xFF8E949C), Color(0xFFD5D9DE), Color(0xFFF7F8FA), Color(0xFFC3C8CE), Color(0xFF858B93)]
        : const [Color(0xFFB08A3A), Color(0xFFE5CB85), Color(0xFFFFF4C9), Color(0xFFD6B35F), Color(0xFF9C7A30)];
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, metal, [0, shine - 0.18, shine, shine + 0.18, 1]),
    );
    final pads = Path()
      ..moveTo(rect.left, 19.5)
      ..lineTo(13.4, 19.5)
      ..moveTo(rect.left, 22.5)
      ..lineTo(13.4, 22.5)
      ..moveTo(16.2, 19.5)
      ..lineTo(rect.right, 19.5)
      ..moveTo(16.2, 22.5)
      ..lineTo(rect.right, 22.5)
      ..addRRect(RRect.fromLTRBR(13.4, 18.6, 16.2, 23.4, const Radius.circular(0.6)))
      ..moveTo(14.8, rect.top)
      ..lineTo(14.8, 18.6)
      ..moveTo(14.8, 23.4)
      ..lineTo(14.8, rect.bottom);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      pads.shift(const Offset(0.1, 0.1)),
      line
        ..strokeWidth = 0.12
        ..color = const Color(0x99FFF6D8),
    );
    canvas.drawPath(
      pads,
      line
        ..strokeWidth = 0.2
        ..color = _glass ? const Color(0xFF5E636B) : const Color(0xFF76561C),
    );
    canvas.drawRRect(
      rrect,
      line
        ..strokeWidth = 0.15
        ..color = const Color(0x88594013),
    );
    canvas.restore();
  }

  void _contactless(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.round
      ..color = _ink.withValues(alpha: 0.9);
    for (var j = 0; j < 4; j++) {
      if (intro < 0.36 + j * 0.035) break;
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(23.4, 21.0), radius: 1.0 + j * 1.05),
        -0.9,
        1.8,
        false,
        paint,
      );
    }
  }

  void _number(Canvas canvas) {
    if (display.number == NumberDisplay.hide) return;
    var digits = card.number.replaceAll('•', _m);
    digits = switch (display.number) {
      NumberDisplay.lastFour when digits.length > 4 => _m * (digits.length - 4) + digits.substring(digits.length - 4),
      NumberDisplay.mask => _m * digits.length,
      _ => digits,
    };
    if (digits.isEmpty && !placeholders) digits = _m * 16;
    final total = placeholders ? math.max(digits.length, digits.length > 16 ? 19 : 16) : digits.length;
    final padded = digits.padRight(total, '•');
    final grouped = StringBuffer();
    for (var i = 0; i < padded.length; i++) {
      if (i > 0 && i % 4 == 0) grouped.write(' ');
      grouped.write(padded[i]);
    }
    final text = grouped.toString();
    _glyphRow(
      canvas,
      text,
      const Offset(8.4, 28.8),
      _glass ? 3.4 : 3.9,
      maxWidth: 71,
      faintFrom: digits.length + digits.length ~/ 4,
      progress: (i) {
        var p = ((intro - (0.40 + 0.30 * i / text.length)) / 0.06).clamp(0.0, 1.0);
        if (i - (i + 1) ~/ 5 == stampIndex) p = math.min(p, stamp);
        return p;
      },
    );
  }

  void _expiry(Canvas canvas) {
    if (display.expiry == FieldDisplay.hide || intro < 0.68) return;
    final have = card.expiry.isNotEmpty;
    final faint = !have && placeholders && display.expiry == FieldDisplay.show;
    final text = faint ? '••/••' : (have && display.expiry == FieldDisplay.show ? card.expiry : '$_m$_m/$_m$_m');
    _text(
      canvas,
      labels.validThru,
      const Offset(35.6, 36.7),
      size: 1.05,
      weight: FontWeight.w600,
      color: _ink.withValues(alpha: 0.8),
      height: 1.05,
      alignRight: true,
    );
    _glyphRow(
      canvas,
      text,
      const Offset(36.4, 36.6),
      _glass ? 2.6 : 2.9,
      maxWidth: 18,
      faintFrom: faint ? 0 : 99,
      progress: (i) => ((intro - (0.68 + i * 0.012)) / 0.05).clamp(0.0, 1.0),
    );
  }

  void _holder(Canvas canvas) {
    if (display.holder == FieldDisplay.hide) return;
    var name = card.holderName.toUpperCase();
    var faint = false;
    if (display.holder == FieldDisplay.mask) {
      name = _m * name.length.clamp(10, 18);
    } else if (name.isEmpty && placeholders) {
      name = labels.holderPlaceholder;
      faint = true;
    } else if (name.isEmpty) {
      name = _m * 12;
    }
    if (name.replaceAll(_m, '').isEmpty) {
      _glyphRow(
        canvas,
        name,
        const Offset(8.4, 43.9),
        2.4,
        maxWidth: 47,
        progress: (i) => ((intro - (0.72 + 0.12 * i / name.length)) / 0.04).clamp(0.0, 1.0),
      );
      return;
    }
    final runes = name.runes.toList();
    final count = (runes.length * _phase(0.72, 0.12)).ceil();
    if (count == 0) return;
    _text(
      canvas,
      String.fromCharCodes(runes.take(count)),
      const Offset(8.4, 43.4),
      size: _glass ? 2.6 : 2.9,
      weight: _glass ? FontWeight.w500 : FontWeight.w600,
      spacing: _glass ? 0.55 : 0.3,
      color: faint ? _ink.withValues(alpha: 0.3) : null,
      emboss: !faint,
      fit: 47,
    );
  }

  void _brandMark(Canvas canvas) {
    final brand = card.brand;
    if (brand == null) return;
    final p = math.min(_phase(0.84, 0.14), logo);
    if (p <= 0) return;
    final s = Curves.elasticOut.transform(p);
    const anchor = Offset(73.0, 45.2);
    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    canvas.scale(s);
    canvas.translate(-anchor.dx, -anchor.dy);
    if (brand == CardBrand.visa) {
      _visa(canvas, const Rect.fromLTRB(61.0, 41.0, 80.6, 49.6));
    } else {
      _mastercard(canvas, anchor, 4.7);
    }
    canvas.restore();
  }

  void _visa(Canvas canvas, Rect box) =>
      paintVisa(canvas, box, !_glass && skin.isLight ? const Color(0xFF1A1F71) : const Color(0xFFFFFFFF), fontFamily);

  void _mastercard(Canvas canvas, Offset c, double r) => paintMastercard(canvas, c, r);

  void _sweep(Canvas canvas) {
    final q = _phase(0.86, 0.14);
    if (q <= 0 || q >= 1) return;
    canvas.save();
    canvas.translate(-30 + (_w + 60) * Curves.easeInOut.transform(q), _h / 2);
    canvas.rotate(0.35);
    const band = Rect.fromLTWH(-9, -_h, 18, _h * 2);
    canvas.drawRect(
      band,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(
          band.centerLeft,
          band.centerRight,
          const [Color(0x00FFFFFF), Color(0x80FFFFFF), Color(0x00FFFFFF)],
          const [0, 0.5, 1],
        ),
    );
    canvas.restore();
  }

  void _back(Canvas canvas) {
    final ink = _ink;
    canvas.drawRect(_stripe, Paint()..color = _glass ? const Color(0xCC050507) : const Color(0xFF0E0E10));

    _text(
      canvas,
      labels.signature,
      const Offset(6.0, 17.3),
      size: 1.05,
      weight: FontWeight.w600,
      color: ink.withValues(alpha: 0.75),
      fit: 54,
    );
    const panel = Rect.fromLTRB(6.0, 19.0, 60.5, 27.0);
    canvas.drawRect(panel, Paint()..color = const Color(0xFFF2EEE4));
    canvas.save();
    canvas.clipRect(panel);
    final hatch = Paint()
      ..color = const Color(0x2E3B5BA0)
      ..strokeWidth = 0.22;
    for (var x = panel.left - 10; x < panel.right; x += 0.9) {
      canvas.drawLine(Offset(x, panel.bottom), Offset(x + 8, panel.top), hatch);
    }
    canvas.restore();
    if (card.holderName.isNotEmpty && display.holder == FieldDisplay.show) {
      _text(
        canvas,
        _signature(card.holderName),
        const Offset(8.0, 20.0),
        size: 3.4,
        weight: FontWeight.w300,
        italic: true,
        color: const Color(0xE01C2A6B),
        fit: 34,
      );
    }
    final cvv = switch (display.cvv) {
      FieldDisplay.hide => '',
      FieldDisplay.mask => _m * 3,
      FieldDisplay.show => card.cvv.padRight(3, _m),
    };
    final showLast4 = display.number == NumberDisplay.full || display.number == NumberDisplay.lastFour;
    final last4 = showLast4 && RegExp(r'^\d{4}$').hasMatch(card.last4) ? card.last4 : '';
    final code = [last4, cvv].where((t) => t.isNotEmpty).join('  ');
    if (code.isNotEmpty) {
      canvas.drawRect(const Rect.fromLTRB(46.5, 19.9, 60.0, 26.1), Paint()..color = const Color(0xFFFFFFFF));
      _text(
        canvas,
        code,
        const Offset(59.2, 21.3),
        size: 2.5,
        weight: FontWeight.w700,
        italic: true,
        color: const Color(0xFF15181D),
        alignRight: true,
      );
    }

    _hologram(canvas, _holo);
    _text(
      canvas,
      labels.backNotice,
      const Offset(6.0, 30.4),
      size: 1.18,
      weight: FontWeight.w500,
      color: ink.withValues(alpha: 0.62),
      height: 1.35,
      wrap: 74,
    );
    switch (card.brand) {
      case CardBrand.visa:
        _visa(canvas, const Rect.fromLTRB(69.5, 44.2, 80.5, 49.0));
      case CardBrand.mastercard:
        _mastercard(canvas, const Offset(76.0, 46.6), 2.6);
      case null:
    }
  }

  void _hologram(Canvas canvas, Rect rect) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(0.8));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          const [Color(0xFFB9BEC6), Color(0xFFEFF1F4), Color(0xFFA9AFB8)],
          const [0, 0.5, 1],
        ),
    );
    final line = Paint()
      ..strokeWidth = 0.08
      ..color = const Color(0x33FFFFFF);
    for (var x = rect.left; x < rect.right + 9; x += 0.45) {
      canvas.drawLine(Offset(x, rect.top), Offset(x - 9, rect.bottom), line);
    }
    final emblem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.32
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xAAFFFFFF);
    final c = rect.center;
    if (card.brand == CardBrand.mastercard) {
      canvas.drawCircle(c - const Offset(2.0, 0), 3.2, emblem);
      canvas.drawCircle(c + const Offset(2.0, 0), 3.2, emblem);
      canvas.drawLine(c - const Offset(5.2, 0), c + const Offset(5.2, 0), emblem);
    } else if (card.brand == null) {
      canvas.drawCircle(c, 3.4, emblem);
      canvas.drawOval(Rect.fromCenter(center: c, width: 3.0, height: 6.8), emblem);
      canvas.drawLine(c - const Offset(3.4, 0), c + const Offset(3.4, 0), emblem);
    } else {
      for (var j = 0; j < 3; j++) {
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 5.5, c.dy + 2.8 - j * 1.2)
            ..quadraticBezierTo(c.dx - 0.5, c.dy - 3.2 - j * 0.6, c.dx + 5.5, c.dy - 0.4 - j * 1.3),
          emblem,
        );
      }
    }
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.12
        ..color = const Color(0x66FFFFFF),
    );
  }

  static const _holo = Rect.fromLTRB(63.0, 18.6, 80.5, 27.6);
  static const _stripe = Rect.fromLTRB(0, 4.6, _w, 15.4);

  void _lighting(Canvas canvas) {
    if (side == CardSide.back) {
      final shift = (tiltX + tiltY) * 14;
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(_holo, const Radius.circular(0.8)));
      canvas.drawRect(
        _holo,
        Paint()
          ..shader = ui.Gradient.linear(
            _holo.topLeft + Offset(shift, 0),
            _holo.topLeft + Offset(shift + 9, 9),
            [for (final c in _rainbow) c.withValues(alpha: 0.55)],
            _rainbowStops,
            TileMode.mirror,
          ),
      );
      canvas.restore();
      final sx = (0.5 + tiltY * 0.9).clamp(0.2, 0.8);
      canvas.drawRect(
        _stripe,
        Paint()
          ..shader = ui.Gradient.linear(
            _stripe.centerLeft,
            _stripe.centerRight,
            const [Color(0x00FFFFFF), Color(0x26FFFFFF), Color(0x00FFFFFF)],
            [sx - 0.2, sx, sx + 0.2],
          ),
      );
    }
    final shift = (tiltX + tiltY) * 40;
    canvas.drawRect(
      _rect,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(
          Offset(shift, 0),
          Offset(shift + 40, 30),
          [for (final c in _rainbow) c.withValues(alpha: _glass ? 0.07 : 0.035)],
          _rainbowStops,
          TileMode.mirror,
        ),
    );
    final glare = Offset(_w * (0.3 + tiltY * 0.9), _h * (0.18 - tiltX * 0.9));
    canvas.drawRect(
      _rect,
      Paint()
        ..shader = ui.Gradient.radial(glare, _w * 0.7, [
          Color.fromRGBO(255, 255, 255, skin.isLight ? 0.08 : 0.19),
          const Color(0x00FFFFFF),
        ]),
    );
    if (!_glass && skin.finish != CardFinish.plastic) {
      canvas.save();
      canvas.translate(_w * (0.5 + tiltY * 1.5), _h / 2);
      canvas.rotate(skin.finish == CardFinish.metal ? 0.5 : 0);
      const band = Rect.fromLTWH(-14, -_h, 28, _h * 2);
      canvas.drawRect(
        band,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(
            band.centerLeft,
            band.centerRight,
            [
              const Color(0x00FFFFFF),
              Color.fromRGBO(255, 255, 255, skin.isLight ? 0.1 : 0.18),
              const Color(0x00FFFFFF),
            ],
            const [0, 0.5, 1],
          ),
      );
      canvas.restore();
    }
    if (_glass) {
      canvas.drawRect(
        _rect,
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, _h * 0.6), const [
            Color(0x1FFFFFFF),
            Color(0x00FFFFFF),
          ]),
      );
      canvas.drawRRect(
        _shape.deflate(0.15),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.3
          ..shader = ui.Gradient.linear(
            Offset.zero,
            const Offset(_w, _h),
            const [Color(0x99FFFFFF), Color(0x14FFFFFF), Color(0x55FFFFFF)],
            const [0, 0.5, 1],
          ),
      );
    }
  }

  void _glyphRow(
    Canvas canvas,
    String text,
    Offset at,
    double height, {
    required double maxWidth,
    required double Function(int i) progress,
    int faintFrom = 99,
  }) {
    final weight = _glass ? 1.15 : 1.7;
    double advance(int i) => text[i] == ' ' ? 6.0 : 13.6;
    var units = -3.6;
    for (var i = 0; i < text.length; i++) {
      units += advance(i);
    }
    var unit = height / 14;
    if (units * unit > maxWidth) unit = maxWidth / units;

    final done = Path();
    final faint = Path();
    final pending = <(Path, double, Offset, double)>[];
    var x = at.dx;
    for (var i = 0; i < text.length; i++) {
      final glyph = _glyphs[text[i]];
      if (glyph != null) {
        if (i >= faintFrom) {
          if (intro >= 1) faint.addPath(glyph, Offset.zero, matrix4: _place(unit, x, at.dy));
        } else {
          final p = progress(i);
          if (p >= 1) {
            done.addPath(glyph, Offset.zero, matrix4: _place(unit, x, at.dy));
          } else if (p > 0) {
            final s = unit * (1 + 1.1 * (1 - Curves.easeOutCubic.transform(p)));
            final c = Offset(x + 5 * unit, at.dy + 7 * unit);
            pending.add((glyph.transform(_place(s, c.dx - 5 * s, c.dy - 7 * s)), p, c, s));
          }
        }
      }
      x += advance(i) * unit;
    }

    final bounds = Rect.fromLTWH(at.dx, at.dy, units * unit, height);
    canvas.drawPath(faint, _stroke(weight * unit)..color = _ink.withValues(alpha: 0.24));
    _emboss(canvas, done, bounds, weight * unit);
    for (final (path, p, c, s) in pending) {
      _emboss(canvas, path, bounds, weight * s, flash: 1 - p);
      if (p > 0.5) {
        final q = (p - 0.5) / 0.5;
        canvas.drawCircle(
          c,
          height * (0.4 + q * 0.9),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.25
            ..color = Color.lerp(skin.foil, const Color(0xFFFFFFFF), 0.5)!.withValues(alpha: (1 - q) * 0.7),
        );
      }
    }
  }

  Paint _stroke(double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _emboss(Canvas canvas, Path path, Rect bounds, double width, {double flash = 0}) {
    const white = Color(0xFFFFFFFF);
    if (_glass) {
      canvas.drawPath(path, _stroke(width)..color = Color.lerp(_ink, white, flash)!);
      return;
    }
    final l = _light;
    canvas.drawPath(path.shift(l * -0.17), _stroke(width)..color = const Color(0x8C000000));
    canvas.drawPath(path.shift(l * 0.08), _stroke(width)..color = const Color(0x73FFFFFF));
    canvas.drawPath(path, _stroke(width)..shader = _foil(bounds, flash));
  }

  Shader _foil(Rect bounds, double flash) {
    const white = Color(0xFFFFFFFF);
    final s = (0.5 + tiltY * 0.9 - tiltX * 0.3).clamp(0.2, 0.8);
    final foil = Color.lerp(skin.foil, white, flash)!;
    final dark = Color.lerp(foil, const Color(0xFF000000), 0.35)!;
    final bright = Color.lerp(foil, white, 0.75)!;
    return ui.Gradient.linear(
      bounds.centerLeft,
      bounds.centerRight,
      [dark, foil, bright, foil, dark],
      [0, s - 0.18, s, s + 0.18, 1],
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    required double size,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double spacing = 0,
    bool italic = false,
    double? height,
    double? fit,
    double? wrap,
    bool alignRight = false,
    bool emboss = false,
  }) {
    final direction = RegExp('[؀-ۿ]').hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;
    TextPainter layout(Color? c, Paint? fg) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          color: c,
          foreground: fg,
          letterSpacing: spacing,
          fontStyle: italic ? FontStyle.italic : null,
          height: height,
        ),
      ),
      textDirection: direction,
      textAlign: alignRight ? TextAlign.right : TextAlign.start,
    )..layout(maxWidth: wrap ?? double.infinity);

    void draw(TextPainter tp, Offset nudge) {
      final scale = fit != null && tp.width > fit ? fit / tp.width : 1.0;
      canvas.save();
      canvas.translate(at.dx + nudge.dx - (alignRight ? tp.width * scale : 0), at.dy + nudge.dy);
      canvas.scale(scale);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
      tp.dispose();
    }

    if (emboss && !_glass) {
      final l = _light;
      draw(layout(const Color(0x8C000000), null), l * -0.15);
      draw(layout(const Color(0x66FFFFFF), null), l * 0.07);
      draw(layout(null, Paint()..shader = _foil(Rect.fromLTWH(0, 0, 45, size), 0)), Offset.zero);
    } else {
      draw(layout(color ?? _ink, null), Offset.zero);
    }
  }

  static String _signature(String name) => name
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  @override
  bool shouldRepaint(CardFacePainter old) =>
      old.card != card ||
      old.skin != skin ||
      old.look != look ||
      old.labels != labels ||
      old.side != side ||
      old.display != display ||
      old.placeholders != placeholders ||
      old.tiltX != tiltX ||
      old.tiltY != tiltY ||
      old.intro != intro ||
      old.logo != logo ||
      old.stampIndex != stampIndex ||
      old.stamp != stamp ||
      old.time != time ||
      old.fontFamily != fontFamily ||
      old.baked != baked;
}

Float64List _place(double scale, double dx, double dy) =>
    Float64List.fromList([scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1]);

// card digits drawn by hand on a 10x14 grid, kinda like the old embosed font
final Map<String, Path> _glyphs = {
  for (final e in const {
    '0': 'M 3 0 L 7 0 Q 10 0 10 3 L 10 11 Q 10 14 7 14 L 3 14 Q 0 14 0 11 L 0 3 Q 0 0 3 0 Z',
    '1': 'M 2 3 L 5.5 0 L 5.5 14 M 2 14 L 9 14',
    '2': 'M 0.4 3.4 Q 0.6 0 4 0 L 6.4 0 Q 10 0 10 3.6 Q 10 6 7 7.6 L 0 12 L 0 14 L 10 14',
    '3': 'M 0.5 0 L 9.5 0 L 4.6 5.8 L 6.6 5.8 Q 10 5.8 10 9.6 L 10 10.4 Q 10 14 6.4 14 L 3.4 14 Q 0 14 0 10.8',
    '4': 'M 7.4 14 L 7.4 0 L 0 9.6 L 0 10.6 L 10 10.6',
    '5': 'M 9.6 0 L 0.8 0 L 0.4 6 L 6.4 6 Q 10 6 10 9.8 L 10 10.4 Q 10 14 6.4 14 L 3.4 14 Q 0 14 0 10.8',
    '6':
        'M 8.6 0 L 4 0 Q 0 0 0 4 L 0 10.4 Q 0 14 3.6 14 L 6.4 14 Q 10 14 10 10.4 L 10 9.6 Q 10 6 6.4 6 L 3.6 6 Q 0 6 0 9.6',
    '7': 'M 0 0 L 10 0 L 10 2 L 3.6 14',
    '8':
        'M 3.2 0 L 6.8 0 Q 9.6 0 9.6 3 Q 9.6 6 6.8 6 L 3.2 6 Q 0.4 6 0.4 3 Q 0.4 0 3.2 0 Z '
        'M 3.2 6 L 6.8 6 Q 10 6 10 10 Q 10 14 6.8 14 L 3.2 14 Q 0 14 0 10 Q 0 6 3.2 6 Z',
    '9':
        'M 1.4 14 L 6 14 Q 10 14 10 10 L 10 3.6 Q 10 0 6.4 0 L 3.6 0 Q 0 0 0 3.6 L 0 4.4 Q 0 8 3.6 8 L 6.4 8 Q 10 8 10 4.4',
    '/': 'M 8.5 0 L 1.5 14',
    '•': 'O 5 7 1',
    '*': 'M 5 3.2 L 5 10.8 M 1.7 5.1 L 8.3 8.9 M 1.7 8.9 L 8.3 5.1',
  }.entries)
    e.key: _parse(e.value),
};

Path _parse(String d) {
  final t = d.split(' ');
  final path = Path();
  double n(int i) => double.parse(t[i]);
  for (var i = 0; i < t.length;) {
    switch (t[i]) {
      case 'M':
        path.moveTo(n(i + 1), n(i + 2));
        i += 3;
      case 'L':
        path.lineTo(n(i + 1), n(i + 2));
        i += 3;
      case 'Q':
        path.quadraticBezierTo(n(i + 1), n(i + 2), n(i + 3), n(i + 4));
        i += 5;
      case 'O':
        path.addOval(Rect.fromCircle(center: Offset(n(i + 1), n(i + 2)), radius: n(i + 3)));
        i += 4;
      default:
        path.close();
        i += 1;
    }
  }
  return path;
}

final Map<(CardFinish?, CardBrand?, bool), ui.Image> _patterns = {};

// baked once per finish, its the heavy part (hundreds of lines)
ui.Image _pattern(CardFinish? finish, CardBrand? brand, bool light) {
  final key = (finish, brand, light);
  final hit = _patterns.remove(key);
  if (hit != null) return _patterns[key] = hit;
  if (_patterns.length >= 12) _patterns.remove(_patterns.keys.first)!.dispose();
  return _patterns[key] = _bake(finish, brand, light);
}

ui.Image _bake(CardFinish? finish, CardBrand? brand, bool light) {
  const px = 768;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(px / _w);
  final ink = light ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  final rnd = math.Random(7);
  final line = Paint()..style = PaintingStyle.stroke;

  switch (finish) {
    case null:
      final dot = Paint();
      for (var i = 0; i < 2600; i++) {
        dot.color = Color.fromRGBO(255, 255, 255, 0.04 + rnd.nextDouble() * 0.08);
        canvas.drawCircle(Offset(rnd.nextDouble() * _w, rnd.nextDouble() * _h), 0.06 + rnd.nextDouble() * 0.05, dot);
      }
    case CardFinish.plastic:
      line
        ..strokeWidth = 0.1
        ..color = ink.withValues(alpha: 0.07);
      for (var i = 0; i < 30; i++) {
        final wave = Path()..moveTo(0, _h * 0.12 + i * 1.3);
        for (var x = 0.0; x <= _w; x += 0.8) {
          wave.lineTo(x, _h * 0.12 + i * 1.3 + 2.2 * math.sin(x * 0.16 + i * 0.35) + 1.1 * math.sin(x * 0.045 + i));
        }
        canvas.drawPath(wave, line);
      }
    case CardFinish.brushed:
      for (var i = 0; i < 420; i++) {
        final y = rnd.nextDouble() * _h;
        line
          ..strokeWidth = 0.04 + rnd.nextDouble() * 0.08
          ..color = (rnd.nextBool() ? const Color(0xFFFFFFFF) : const Color(0xFF000000)).withValues(
            alpha: 0.02 + rnd.nextDouble() * 0.06,
          );
        canvas.drawLine(Offset(0, y), Offset(_w, y), line);
      }
    case CardFinish.metal:
      const center = Offset(-_w * 0.35, _h * 1.25);
      for (var r = 20.0; r < 140; r += 0.32) {
        line
          ..strokeWidth = 0.12
          ..color = (rnd.nextBool() ? const Color(0xFFFFFFFF) : const Color(0xFF000000)).withValues(
            alpha: 0.015 + rnd.nextDouble() * 0.05,
          );
        canvas.drawCircle(center, r, line);
      }
  }

  if (finish != null) {
    line
      ..strokeWidth = 0.35
      ..color = ink.withValues(alpha: 0.07);
    if (brand == CardBrand.mastercard) {
      canvas.drawCircle(const Offset(60, 27), 22, line);
      canvas.drawCircle(const Offset(82, 27), 22, line);
    } else if (brand == CardBrand.visa) {
      for (var j = 0; j < 5; j++) {
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(_w * 1.05, _h * 1.2), radius: 30.0 + j * 6),
          math.pi,
          math.pi / 2,
          false,
          line,
        );
      }
    }
  }

  final picture = recorder.endRecording();
  final image = picture.toImageSync(px, (px / kCardAspectRatio).round());
  picture.dispose();
  return image;
}

void paintVisa(Canvas canvas, Rect box, Color color, String? fontFamily) {
  final tp = TextPainter(
    text: TextSpan(
      text: 'VISA',
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: -0.2,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final s = math.min(box.width / (tp.width + tp.height * 0.2), box.height / (tp.height * 0.78));
  canvas.save();
  canvas.translate(box.right - tp.width * s, box.center.dy - tp.height * s / 2);
  canvas.scale(s);
  canvas.translate(tp.height * 0.1, 0);
  canvas.skew(-0.2, 0);
  tp.paint(canvas, Offset.zero);
  canvas.restore();
  tp.dispose();
}

void paintMastercard(Canvas canvas, Offset c, double r) {
  final left = Rect.fromCircle(center: c - Offset(r * 0.62, 0), radius: r);
  final right = Rect.fromCircle(center: c + Offset(r * 0.62, 0), radius: r);
  canvas.drawOval(left, Paint()..color = const Color(0xFFEB001B));
  canvas.drawOval(right, Paint()..color = const Color(0xFFF79E1B));
  canvas.drawPath(
    Path.combine(PathOperation.intersect, Path()..addOval(left), Path()..addOval(right)),
    Paint()..color = const Color(0xFFFF5F00),
  );
}
