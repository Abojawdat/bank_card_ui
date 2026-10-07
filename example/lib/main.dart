import 'dart:math' as math;

import 'package:bank_card_3d/bank_card_3d.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() => runApp(const Demo());

// what a backend might send, every record spelled diffrently on purpose
const api = [
  {
    'card_number': '4532015112830366',
    'holder_name': 'Mohammad Othman',
    'expiry': '08/29',
    'scheme': 'VISA',
    'product': 'Infinite',
    'card_type': 'credit',
  },
  {
    'masked_pan': '542523******9903',
    'cardholder_name': 'SARA KAREEM',
    'exp_month': 11,
    'exp_year': 2028,
    'scheme': 'mastercard',
    'level': 'world_elite',
  },
  {
    'card': {'brand': 'visa', 'last4': '4242', 'exp_month': 3, 'exp_year': 2030, 'funding': 'debit'},
    'name_on_card': 'Ali Hassan',
    'tier': 'gold',
  },
  {
    'pan': '2223003122003222',
    'name': 'Noor Al-Huda',
    'expiry_date': '2027-06',
    'network': 'MasterCard',
    'tier': 'platinum',
  },
  {'number': '4024007163053426', 'holder': 'Zaid Mahmoud', 'expiry': '01/31', 'tier': 'signature'},
  {'last4': '0005', 'brand': 'mastercard', 'tier': 'world'},
];

Stream<Offset>? deviceTilt() {
  final phone =
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  if (!phone) return null;
  Offset? rest;
  return accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).map((e) {
    final now = Offset(e.x, e.y);
    rest = Offset.lerp(rest ?? now, now, 0.02);
    final d = (now - rest!) / 3;
    return Offset(-d.dx, d.dy);
  }).asBroadcastStream();
}

const _text = {
  'en': {
    'card': 'Card',
    'wallet': 'Wallet',
    'add': 'Add card',
    'hint': 'Drag it, flick it, double tap to flip',
    'last4': 'Last 4 only',
    'name': 'Name',
    'expiry': 'Expiry',
    'cvv': 'CVV',
    'back': 'Back',
    'replay': 'Replay',
    'walletHint': 'Six cards from a mixed API response, the last one only has last4. Tap one.',
    'save': 'Save card',
    'saved': 'Saved',
    'glass': 'Glass',
    'photoreal': 'Photoreal',
  },
  'ar': {
    'card': 'البطاقة',
    'wallet': 'المحفظة',
    'add': 'إضافة بطاقة',
    'hint': 'اسحبها، ارمِها، أو انقر مرتين لقلبها',
    'last4': 'آخر ٤ أرقام',
    'name': 'الاسم',
    'expiry': 'الانتهاء',
    'cvv': 'رمز الأمان',
    'back': 'الوجه الخلفي',
    'replay': 'إعادة',
    'walletHint': 'ست بطاقات من استجابة API مختلطة، الأخيرة فيها آخر ٤ أرقام فقط. انقر على واحدة.',
    'save': 'حفظ البطاقة',
    'saved': 'تم الحفظ',
    'glass': 'زجاجي',
    'photoreal': 'واقعي',
  },
};

class Demo extends StatefulWidget {
  const Demo({super.key});

  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  var locale = const Locale('en');
  var look = CardLook.photoreal;
  var tab = 0;
  final tilt = deviceTilt();

  @override
  Widget build(BuildContext context) {
    final t = _text[locale.languageCode]!;
    return MaterialApp(
      title: 'bank_card_3d',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF3D5AFE),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      builder: (context, child) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.3,
            colors: [Color(0xFF1B2050), Color(0xFF07080F)],
          ),
        ),
        child: child,
      ),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('bank_card_3d', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            SegmentedButton<CardLook>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: CardLook.photoreal, label: Text(t['photoreal']!)),
                ButtonSegment(value: CardLook.glass, label: Text(t['glass']!)),
              ],
              selected: {look},
              onSelectionChanged: (s) => setState(() => look = s.first),
            ),
            TextButton(
              onPressed: () => setState(() => locale = Locale(locale.languageCode == 'en' ? 'ar' : 'en')),
              child: Text(locale.languageCode == 'en' ? 'عربي' : 'EN'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: switch (tab) {
            0 => Showcase(look: look, tilt: tilt, t: t),
            1 => WalletPage(look: look, tilt: tilt, t: t),
            _ => AddPage(look: look, tilt: tilt, t: t),
          },
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.black26,
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.credit_card), label: t['card']!),
            NavigationDestination(icon: const Icon(Icons.wallet), label: t['wallet']!),
            NavigationDestination(icon: const Icon(Icons.add_card), label: t['add']!),
          ],
        ),
      ),
    );
  }
}

double cardWidth(BuildContext context) => math.min(MediaQuery.sizeOf(context).width - 48, 420);

class Showcase extends StatefulWidget {
  const Showcase({required this.look, required this.tilt, required this.t, super.key});

  final CardLook look;
  final Stream<Offset>? tilt;
  final Map<String, String> t;

  @override
  State<Showcase> createState() => _ShowcaseState();
}

class _ShowcaseState extends State<Showcase> {
  var brand = CardBrand.visa;
  var tier = CardTier.platinum;
  var display = CardDisplay.everything;
  var back = false;
  var replay = 0;

  static const tiers = {
    CardBrand.visa: [CardTier.standard, CardTier.gold, CardTier.platinum, CardTier.signature, CardTier.infinite],
    CardBrand.mastercard: [CardTier.standard, CardTier.gold, CardTier.platinum, CardTier.world, CardTier.worldElite],
  };

  String tierName(CardTier t) => t == CardTier.standard
      ? (brand == CardBrand.visa ? 'Classic' : 'Standard')
      : t.printedName(brand)[0] + t.printedName(brand).substring(1).toLowerCase().replaceAll('elite', 'Elite');

  @override
  Widget build(BuildContext context) {
    final card = BankCard(
      number: brand == CardBrand.visa ? '4532 0151 1283 0366' : '5425 2334 3010 9903',
      holderName: 'Mohammad Othman',
      expiryMonth: 8,
      expiryYear: 2029,
      cvv: '742',
      tier: tier,
      kind: CardKind.credit,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      children: [
        Center(
          child: BankCard3D(
            key: ValueKey(replay),
            card: card,
            width: cardWidth(context),
            look: widget.look,
            display: display,
            showBack: back,
            tilt: widget.tilt,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          widget.t['hint']!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 28),
        Center(
          child: SegmentedButton<CardBrand>(
            segments: const [
              ButtonSegment(value: CardBrand.visa, label: Text('Visa')),
              ButtonSegment(value: CardBrand.mastercard, label: Text('Mastercard')),
            ],
            selected: {brand},
            onSelectionChanged: (s) => setState(() {
              brand = s.first;
              if (!tiers[brand]!.contains(tier)) tier = CardTier.standard;
            }),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in tiers[brand]!)
              ChoiceChip(label: Text(tierName(t)), selected: t == tier, onSelected: (_) => setState(() => tier = t)),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: Text(widget.t['last4']!),
              selected: display.number == NumberDisplay.lastFour,
              onSelected: (v) =>
                  setState(() => display = display.copyWith(number: v ? NumberDisplay.lastFour : NumberDisplay.full)),
            ),
            for (final (key, field) in [('name', display.holder), ('expiry', display.expiry), ('cvv', display.cvv)])
              FilterChip(
                label: Text(widget.t[key]!),
                selected: field == FieldDisplay.show,
                onSelected: (v) => setState(() {
                  final mode = v ? FieldDisplay.show : FieldDisplay.mask;
                  display = switch (key) {
                    'name' => display.copyWith(holder: mode),
                    'expiry' => display.copyWith(expiry: mode),
                    _ => display.copyWith(cvv: mode),
                  };
                }),
              ),
            FilterChip(label: Text(widget.t['back']!), selected: back, onSelected: (v) => setState(() => back = v)),
            ActionChip(
              avatar: const Icon(Icons.replay, size: 18),
              label: Text(widget.t['replay']!),
              onPressed: () => setState(() => replay++),
            ),
          ],
        ),
      ],
    );
  }
}

class WalletPage extends StatefulWidget {
  const WalletPage({required this.look, required this.tilt, required this.t, super.key});

  final CardLook look;
  final Stream<Offset>? tilt;
  final Map<String, String> t;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final cards = [for (final json in api) ?BankCard.tryFromJson(json)];
  int? picked;

  @override
  Widget build(BuildContext context) {
    final card = picked == null ? null : cards[picked!];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Text(
          widget.t['walletHint']!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            card == null
                ? ' '
                : [card.brand!.label, '•••• ${card.last4}', if (card.expiry.isNotEmpty) card.expiry].join(' · '),
            key: ValueKey(picked),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: BankCardWallet(
            cards: cards,
            width: cardWidth(context),
            look: widget.look,
            tilt: widget.tilt,
            onSelected: (i) => setState(() => picked = i),
          ),
        ),
      ],
    );
  }
}

class AddPage extends StatefulWidget {
  const AddPage({required this.look, required this.tilt, required this.t, super.key});

  final CardLook look;
  final Stream<Offset>? tilt;
  final Map<String, String> t;

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final form = GlobalKey<FormState>();
  BankCard? card;

  void save() {
    if (!form.currentState!.validate()) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${widget.t['saved']!} · ${card!.brand!.label} •••• ${card!.last4}')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: BankCardForm(
              formKey: form,
              look: widget.look,
              tilt: widget.tilt,
              cardWidth: cardWidth(context),
              onChanged: (c) => card = c,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.lock_outline),
            label: Text(widget.t['save']!),
          ),
        ),
      ],
    );
  }
}
