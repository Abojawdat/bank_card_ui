import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import 'bank_card.dart';
import 'bank_card_3d.dart';
import 'card_display.dart';
import 'card_labels.dart';
import 'card_painter.dart';
import 'card_skin.dart';

/// A stack of cards like a phone wallet. Tap one to pull it out, tap it again to put it back.
class BankCardWallet extends StatefulWidget {
  const BankCardWallet({
    required this.cards,
    this.width = 340,
    this.look = CardLook.photoreal,
    this.labels,
    this.display = const CardDisplay(),
    this.tilt,
    this.intro = true,
    this.onSelected,
    super.key,
  });

  final List<BankCard> cards;
  final double width;
  final CardLook look;
  final BankCardLabels? labels;
  final CardDisplay display;
  final Stream<Offset>? tilt;

  /// deals the cards in one by one on first build
  final bool intro;

  /// index of the pulled out card, null when its put back
  final ValueChanged<int?>? onSelected;

  @override
  State<BankCardWallet> createState() => _BankCardWalletState();
}

class _BankCardWalletState extends State<BankCardWallet> with TickerProviderStateMixin {
  late final AnimationController _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))
    ..addListener(() => setState(() {}));

  late final AnimationController _deal = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 900 + 160 * widget.cards.length),
    value: widget.intro ? 0 : 1,
  )..addListener(() => setState(() {}));

  int? _selected;
  late Stream<Offset>? _tilt = widget.tilt?.asBroadcastStream();

  @override
  void initState() {
    super.initState();
    _deal.forward();
  }

  @override
  void didUpdateWidget(BankCardWallet old) {
    super.didUpdateWidget(old);
    if (old.tilt != widget.tilt) _tilt = widget.tilt?.asBroadcastStream();
    if (_selected != null && _selected! >= widget.cards.length) {
      _selected = null;
      _open.value = 0;
    }
  }

  @override
  void dispose() {
    _open.dispose();
    _deal.dispose();
    super.dispose();
  }

  Future<void> _tap(int i) async {
    if (_selected == i) {
      await _open.reverse();
      if (!mounted) return;
      setState(() => _selected = null);
    } else {
      if (_selected != null) await _open.reverse();
      if (!mounted) return;
      setState(() => _selected = i);
      _open.forward();
    }
    widget.onSelected?.call(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    final w = widget.width;
    final h = w / kCardAspectRatio;
    if (cards.isEmpty) return SizedBox(width: w, height: h);
    if (cards.length == 1) {
      return BankCard3D(
        card: cards.first,
        width: w,
        look: widget.look,
        labels: widget.labels,
        display: widget.display,
        tilt: widget.tilt,
        intro: widget.intro,
      );
    }

    final n = cards.length;
    final peek = h * 0.21;
    final pileTop = h * 1.02;
    final pileStep = h * 0.06;
    final height = math.max(h + (n - 1) * peek, pileTop + (n - 2) * pileStep + h * 0.75);
    final selected = _selected;

    Widget place(int i) {
      final rank = selected == null || i < selected ? i : i - 1;
      final isSel = i == selected;
      final stagger = isSel ? 0.0 : rank * 0.05;
      final t = Curves.easeInOutCubic.transform(
        ((_open.value - stagger) / (1 - stagger * 2).clamp(0.5, 1.0)).clamp(0.0, 1.0),
      );

      final restY = i * peek;
      final openY = isSel ? 0.0 : pileTop + rank * pileStep;
      var y = lerpDouble(restY, selected == null ? restY : openY, t)!;
      var rx = lerpDouble(-0.16, isSel ? 0.0 : -1.0, selected == null ? 0 : t)!;
      var scale =
          lerpDouble(1, isSel ? 1.0 : 0.88, selected == null ? 0 : t)! + (isSel ? math.sin(math.pi * t) * 0.06 : 0);
      var rz = 0.0;

      // deal in from below, one after the other
      final d = ((_deal.value * (n + 4) - i) / 5).clamp(0.0, 1.0);
      if (d < 1) {
        final e = Curves.easeOutBack.transform(d);
        y += (1 - e) * h * 2.6;
        rx += (1 - e) * 1.3;
        rz = (1 - e) * (i.isEven ? 0.35 : -0.35);
        scale *= 0.6 + 0.4 * e;
      }

      final live = isSel && _open.isCompleted;
      return Positioned(
        left: 0,
        top: 0,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.4 / w)
            ..translateByDouble(0, y, 0, 1)
            ..scaleByDouble(scale, scale, 1, 1)
            ..rotateX(rx)
            ..rotateZ(rz),
          child: GestureDetector(
            onTap: live ? null : () => _tap(i),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(w * 0.037),
                boxShadow: [
                  BoxShadow(color: const Color(0x66000000), blurRadius: w * 0.05, offset: Offset(0, -h * 0.015)),
                ],
              ),
              child: BankCard3D(
                key: ObjectKey(cards[i]),
                card: cards[i],
                width: w,
                look: widget.look,
                labels: widget.labels,
                display: widget.display,
                tilt: _tilt,
                intro: false,
                float: live,
                interactive: live,
                shadow: false,
                onTap: live ? () => _tap(i) : null,
              ),
            ),
          ),
        ),
      );
    }

    final order = [
      for (var i = 0; i < n; i++)
        if (i != selected) i,
      ?selected,
    ];
    return SizedBox(
      width: w,
      height: height,
      child: Stack(clipBehavior: Clip.none, children: [for (final i in order) place(i)]),
    );
  }
}
