import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'bank_card.dart';
import 'bank_card_view.dart';
import 'card_display.dart';
import 'card_labels.dart';
import 'card_painter.dart';
import 'card_skin.dart';

/// The card in real 3D. Drag it, flick it, double tap to flip.
///
/// Takes up exactly `width x width / kCardAspectRatio`.
class BankCard3D extends StatefulWidget {
  const BankCard3D({
    required this.card,
    this.width = 340,
    this.look = CardLook.photoreal,
    this.skin,
    this.labels,
    this.display = const CardDisplay(),
    this.showBack = false,
    this.interactive = true,
    this.intro = true,
    this.float = true,
    this.tilt,
    this.shadow = true,
    this.placeholders = false,
    this.onTap,
    super.key,
  });

  final BankCard card;
  final double width;
  final CardLook look;
  final CardSkin? skin;
  final BankCardLabels? labels;
  final CardDisplay display;

  /// flips to the back when true, back again when false
  final bool showBack;
  final bool interactive;

  /// plays the minting animation when the card first shows up
  final bool intro;
  final bool float;

  /// device tilt, x and y in -1..1. hook a gyro or accelerometer stream here
  final Stream<Offset>? tilt;
  final bool shadow;
  final bool placeholders;
  final VoidCallback? onTap;

  @override
  State<BankCard3D> createState() => _BankCard3DState();
}

class _BankCard3DState extends State<BankCard3D> with SingleTickerProviderStateMixin {
  static const _introSeconds = 2.8;
  static const _stiffness = 70.0;
  static const _damping = 9.0;
  static const _layers = 5;

  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  double _time = 0;

  double _rx = 0, _ry = 0, _vx = 0, _vy = 0, _goalX = 0, _goalY = 0;
  bool _dragging = false;

  Offset _hover = Offset.zero, _sensor = Offset.zero, _tilt = Offset.zero;
  StreamSubscription<Offset>? _sensorSub;

  late double _intro = widget.intro ? 0 : 1;
  double _float = 0;
  late CardSkin _skinFrom = _skinOf(widget);
  double _skinT = 1;
  double _logo = 1;
  int _stampIndex = -1;
  double _stamp = 1;
  final _baked = <CardSide, (Object, ui.Image)>{};

  CardSkin _skinOf(BankCard3D w) => w.skin ?? CardSkin.of(w.card.brand, w.card.tier);

  bool get _facingBack => ((_goalX / math.pi).round() + (_goalY / math.pi).round()).isOdd;

  @override
  void initState() {
    super.initState();
    if (widget.showBack) _goalY = _ry = math.pi;
    _listen();
    _wake();
  }

  @override
  void didUpdateWidget(BankCard3D old) {
    super.didUpdateWidget(old);
    if (old.tilt != widget.tilt) {
      _sensorSub?.cancel();
      _sensor = Offset.zero;
      _listen();
    }
    if (widget.showBack != _facingBack && old.showBack != widget.showBack) {
      _goalY += math.pi;
    }
    final before = _skinOf(old);
    if (before != _skinOf(widget)) {
      _skinFrom = CardSkin.lerp(_skinFrom, before, Curves.easeInOut.transform(_skinT));
      _skinT = 0;
    }
    if (widget.card.brand != null && old.card.brand != widget.card.brand) {
      _logo = 0;
      _vy += 2.2;
    }
    final a = old.card.number, b = widget.card.number;
    if (b.length == a.length + 1 && b.startsWith(a)) {
      _stampIndex = b.length - 1;
      _stamp = 0;
      _vx += 0.25;
    }
    _wake();
  }

  @override
  void dispose() {
    for (final (_, image) in _baked.values) {
      image.dispose();
    }
    _ticker.dispose();
    _sensorSub?.cancel();
    super.dispose();
  }

  void _listen() {
    _sensorSub = widget.tilt?.listen((v) {
      _sensor = Offset(v.dx.clamp(-1.0, 1.0), v.dy.clamp(-1.0, 1.0));
      _wake();
    });
  }

  void _wake() {
    if (_ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final real = _last == Duration.zero ? 1 / 60 : (elapsed - _last).inMicroseconds / 1e6;
    final dt = math.min(real, 1 / 30);
    _last = elapsed;
    _time += dt;

    if (_intro < 1) {
      final before = _intro;
      _intro = math.min(1, _intro + real / _introSeconds);
      _knock(before, _intro);
    }
    if (!_dragging) {
      _vx += (-_stiffness * (_rx - _goalX) - _damping * _vx) * dt;
      _vy += (-_stiffness * (_ry - _goalY) - _damping * _vy) * dt;
      _rx += _vx * dt;
      _ry += _vy * dt;
    }
    final goal = _hover + _sensor;
    _tilt = Offset.lerp(_tilt, goal, 1 - math.exp(-dt * 7))!;
    final floatGoal = widget.float && !_dragging && _intro >= 1 ? 1.0 : 0.0;
    _float += (floatGoal - _float) * (1 - math.exp(-dt * 2.5));
    _skinT = math.min(1, _skinT + dt / 0.8);
    _logo = math.min(1, _logo + dt / 1.1);
    _stamp = math.min(1, _stamp + dt / 0.32);

    final settled =
        !widget.float &&
        !_dragging &&
        _intro >= 1 &&
        _skinT >= 1 &&
        _logo >= 1 &&
        _stamp >= 1 &&
        _float < 1e-3 &&
        (_rx - _goalX).abs() < 1e-3 &&
        (_ry - _goalY).abs() < 1e-3 &&
        _vx.abs() < 1e-3 &&
        _vy.abs() < 1e-3 &&
        (_tilt - goal).distance < 1e-3;
    if (settled) _ticker.stop();
    setState(() {});
  }

  // the card nods a bit everytime a digit gets stamped in
  void _knock(double before, double now) {
    final n = widget.card.number.length;
    for (var i = 0; i < n; i++) {
      final t = 0.46 + 0.30 * i / n;
      if (before < t && now >= t) _vx += 0.22;
    }
    if (before < 0.86 && now >= 0.86 && widget.card.brand != null) _vy += 1.6;
  }

  void _release(DragEndDetails d) {
    _dragging = false;
    final v = d.velocity.pixelsPerSecond * (math.pi / widget.width);
    _vy = v.dx;
    _vx = -v.dy;
    _goalY = ((_ry + _vy * 0.12) / math.pi).roundToDouble() * math.pi;
    _goalX = ((_rx + _vx * 0.12) / math.pi).roundToDouble() * math.pi;
    _wake();
  }

  void _flip() {
    _goalY += math.pi;
    _wake();
  }

  ui.Image _bake(CardFacePainter painter, Size size, double ratio) {
    final key = (
      painter.card,
      painter.skin,
      painter.look,
      painter.labels,
      painter.display,
      painter.placeholders,
      painter.fontFamily,
      size,
      ratio,
    );
    final hit = _baked[painter.side];
    if (hit != null && hit.$1 == key) return hit.$2;
    hit?.$2.dispose();
    final image = painter.bake(size, ratio * 1.15);
    _baked[painter.side] = (key, image);
    return image;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w / kCardAspectRatio;
    final labels = widget.labels ?? BankCardLabels.of(context);
    final skin = CardSkin.lerp(_skinFrom, _skinOf(widget), Curves.easeInOut.transform(_skinT));

    final entry = (_intro / 0.34).clamp(0.0, 1.0);
    final a = Curves.easeOutCubic.transform(entry);
    final scale = 0.2 + 0.8 * Curves.easeOutBack.transform(entry);
    final rx = _rx + (1 - a) * 1.1 + _tilt.dy * 0.32 + _float * math.sin(_time * 1.1) * 0.05;
    final ry = _ry - (1 - a) * 3 * math.pi - _tilt.dx * 0.42 + _float * math.sin(_time * 0.77) * 0.08;
    final lift = -(1 - a) * h * 0.4 + _float * math.sin(_time * 1.3) * h * 0.025;
    final thickness = math.max(1.5, w * 0.0089 * (skin.finish == CardFinish.metal ? 1.5 : 1.0));
    final radius = BorderRadius.circular(w * 0.037);

    Matrix4 at(double z) => Matrix4.identity()
      ..setEntry(3, 2, 0.4 / w)
      ..translateByDouble(0, lift, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..rotateX(rx)
      ..rotateY(ry)
      ..translateByDouble(0, 0, z, 1);

    final side = math.cos(rx) * math.cos(ry) > 0 ? CardSide.front : CardSide.back;
    final family = DefaultTextStyle.of(context).style.fontFamily;
    final still = CardFacePainter(
      card: widget.card,
      skin: skin,
      look: widget.look,
      labels: labels,
      side: side,
      display: widget.display,
      placeholders: widget.placeholders,
      fontFamily: family,
    );
    // while something on the face is moving paint it live, otherwise reuse the baked image
    final live = _intro < 1 || _logo < 1 || _stamp < 1 || _skinT < 1;
    final face = CustomPaint(
      painter: CardFacePainter(
        card: widget.card,
        skin: skin,
        look: widget.look,
        labels: labels,
        side: side,
        display: widget.display,
        placeholders: widget.placeholders,
        tiltX: math.sin(rx),
        tiltY: side == CardSide.front ? math.sin(ry) : -math.sin(ry),
        intro: _intro,
        logo: _logo,
        stampIndex: _stampIndex,
        stamp: _stamp,
        time: _time,
        fontFamily: family,
        baked: live ? null : _bake(still, Size(w, h), MediaQuery.maybeDevicePixelRatioOf(context) ?? 1),
      ),
    );

    final top = Transform(
      alignment: Alignment.center,
      transform: side == CardSide.front ? at(-thickness / 2) : (at(thickness / 2)..rotateY(math.pi)),
      child: face,
    );
    Widget layer(int i) {
      final outer = i == 1 || i == _layers - 1;
      final color = outer && skin.finish == CardFinish.plastic ? skin.colors[1] : skin.edgeColor;
      return Transform(
        alignment: Alignment.center,
        transform: at(-thickness / 2 + thickness * i / _layers),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: radius),
        ),
      );
    }

    final layers = [for (var i = 1; i < _layers; i++) layer(i)];

    Widget card = SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          if (widget.shadow)
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translateByDouble(-_tilt.dx * w * 0.05, h * 0.5 + (1 - a) * h * 0.3, 0, 1)
                ..scaleByDouble((0.3 + 0.7 * math.cos(ry).abs()) * scale, 0.16, 1, 1),
              child: Center(
                child: SizedBox.square(
                  dimension: w,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Color.fromRGBO(0, 0, 0, 0.5 * a),
                          Color.fromRGBO(0, 0, 0, 0.22 * a),
                          const Color(0x00000000),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ...side == CardSide.front ? layers.reversed : layers,
          top,
        ],
      ),
    );

    if (widget.interactive) {
      card = MouseRegion(
        onHover: (e) {
          _hover = Offset((e.localPosition.dx / w - 0.5) * 2, (e.localPosition.dy / h - 0.5) * 2);
          _wake();
        },
        onExit: (_) {
          _hover = Offset.zero;
          _wake();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            _dragging = true;
            _wake();
          },
          onPanUpdate: (d) {
            _ry += d.delta.dx * math.pi / w;
            _rx -= d.delta.dy * math.pi / w;
          },
          onPanEnd: _release,
          onPanCancel: () => _dragging = false,
          onDoubleTap: _flip,
          onTap: widget.onTap,
          child: card,
        ),
      );
    } else if (widget.onTap != null) {
      card = GestureDetector(onTap: widget.onTap, child: card);
    }
    return Semantics(label: semanticLabel(widget.card), button: widget.onTap != null, child: card);
  }
}
