# bank_card_3d example

The showcase from the [live demo](https://abojawdat.github.io/bank_card_ui/):

- **Card** — every Visa and Mastercard tier, photoreal or glass, and every display option (last 4, name, expiry, CVV).
- **Wallet** — six cards parsed from a mixed API response with `BankCard.tryFromJson`, the last one with only `last4`.
- **Add card** — `BankCardForm` with validation.
- English / Arabic switch, and the gyroscope through `sensors_plus` on phones.

```sh
flutter run
```
