import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bank_card.dart';
import 'bank_card_3d.dart';
import 'bank_card_view.dart';
import 'card_display.dart';
import 'card_labels.dart';
import 'card_skin.dart';

/// Card entry form with the 3D card on top. The card fills in while the user types
/// and flips over when they get to the CVV.
class BankCardForm extends StatefulWidget {
  const BankCardForm({
    this.onChanged,
    this.formKey,
    this.initial,
    this.look = CardLook.photoreal,
    this.tier = CardTier.standard,
    this.labels,
    this.cardWidth = 340,
    this.tilt,
    this.gap = 14,
    this.display = CardDisplay.everything,
    super.key,
  });

  /// called on every keystroke with what the user typed so far
  final ValueChanged<BankCard>? onChanged;

  /// call `formKey.currentState!.validate()` before you submit
  final GlobalKey<FormState>? formKey;
  final BankCard? initial;
  final CardLook look;
  final CardTier tier;
  final BankCardLabels? labels;
  final double cardWidth;
  final Stream<Offset>? tilt;
  final double gap;
  final CardDisplay display;

  @override
  State<BankCardForm> createState() => _BankCardFormState();
}

class _BankCardFormState extends State<BankCardForm> {
  late final _number = TextEditingController(text: widget.initial?.formatted() ?? '');
  late final _holder = TextEditingController(text: widget.initial?.holderName ?? '');
  late final _expiry = TextEditingController(text: widget.initial?.expiry ?? '');
  late final _cvv = TextEditingController(text: widget.initial?.cvv ?? '');
  final _cvvFocus = FocusNode();
  late BankCard _card = _read();

  @override
  void initState() {
    super.initState();
    _cvvFocus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(BankCardForm old) {
    super.didUpdateWidget(old);
    if (old.tier != widget.tier) _card = _read();
  }

  @override
  void dispose() {
    _number.dispose();
    _holder.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _cvvFocus.dispose();
    super.dispose();
  }

  BankCard _read() {
    final (month, year) = BankCard.parseExpiry(_expiry.text);
    return BankCard(
      number: _number.text,
      holderName: _holder.text,
      expiryMonth: month,
      expiryYear: year,
      cvv: _cvv.text,
      tier: widget.tier,
    );
  }

  void _changed(String _) {
    setState(() => _card = _read());
    widget.onChanged?.call(_card);
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels ?? BankCardLabels.of(context);
    String? message(CardIssue? issue) => issue == null ? null : labels.issue(issue);
    final brand = _card.brand;
    final gap = SizedBox(height: widget.gap, width: widget.gap);

    return Form(
      key: widget.formKey,
      child: LayoutBuilder(
        builder: (context, box) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: BankCard3D(
                card: _card,
                width: box.maxWidth.isFinite && box.maxWidth < widget.cardWidth ? box.maxWidth : widget.cardWidth,
                look: widget.look,
                labels: labels,
                display: widget.display,
                placeholders: true,
                showBack: _cvvFocus.hasFocus,
                tilt: widget.tilt,
              ),
            ),
            SizedBox(height: widget.gap * 2),
            TextFormField(
              controller: _number,
              decoration: InputDecoration(
                labelText: labels.number,
                hintText: '0000 0000 0000 0000',
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    switchInCurve: Curves.elasticOut,
                    transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                    child: brand == null
                        ? const SizedBox(width: 36)
                        : CardBrandMark(
                            key: ValueKey(brand),
                            brand: brand,
                            height: 22,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : null,
                          ),
                  ),
                ),
              ),
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.creditCardNumber],
              inputFormatters: [_NumberFormatter()],
              validator: (_) => message(_card.numberIssue),
              onChanged: _changed,
            ),
            gap,
            TextFormField(
              controller: _holder,
              decoration: InputDecoration(labelText: labels.holder),
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.creditCardName],
              validator: (_) => message(_card.holderIssue),
              onChanged: _changed,
            ),
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiry,
                    decoration: InputDecoration(labelText: labels.expiry, hintText: 'MM/YY'),
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.creditCardExpirationDate],
                    inputFormatters: [_ExpiryFormatter()],
                    validator: (_) => message(_card.expiryIssue),
                    onChanged: _changed,
                  ),
                ),
                gap,
                Expanded(
                  child: TextFormField(
                    controller: _cvv,
                    focusNode: _cvvFocus,
                    decoration: InputDecoration(labelText: labels.cvv, hintText: '123'),
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.creditCardSecurityCode],
                    inputFormatters: [_DigitsFormatter(3)],
                    validator: (_) => message(_card.cvvIssue),
                    onChanged: _changed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _digits(String text) => BankCard.normalize(text).replaceAll('•', '');

class _NumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final end = newValue.selection.end.clamp(0, newValue.text.length);
    final before = _digits(newValue.text.substring(0, end)).length;
    var digits = _digits(newValue.text);
    final max = CardBrand.detect(digits) == CardBrand.mastercard ? 16 : 19;
    if (digits.length > max) digits = digits.substring(0, max);

    final out = StringBuffer();
    var caret = 0;
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) out.write(' ');
      out.write(digits[i]);
      if (i < before) caret = out.length;
    }
    return TextEditingValue(
      text: out.toString(),
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var d = _digits(newValue.text);
    if (d.length == 1 && d != '0' && d != '1') d = '0$d';
    if (d.length > 4) d = d.substring(0, 4);
    final deleting = newValue.text.length < oldValue.text.length;
    final text = d.length > 2 || (d.length == 2 && !deleting) ? '${d.substring(0, 2)}/${d.substring(2)}' : d;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _DigitsFormatter extends TextInputFormatter {
  _DigitsFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var d = _digits(newValue.text);
    if (d.length > max) d = d.substring(0, max);
    return TextEditingValue(
      text: d,
      selection: TextSelection.collapsed(offset: d.length),
    );
  }
}
