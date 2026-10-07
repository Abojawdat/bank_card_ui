## 0.1.1

- Shorter package description.

## 0.1.0

First release.

- `BankCard3D`: real 3D card with drag, flick, double-tap flip, mouse lean and a `tilt` stream for the gyroscope.
- Minting intro: chip drops in, digits stamped one by one, logo pop, light sweep.
- Visa Classic, Gold, Platinum, Signature, Infinite and Mastercard Standard, Gold, Platinum, World, World Elite, each in its own material.
- Two looks: photoreal and glass.
- `BankCard.fromJson` reads whatever your backend sends and never fails: any key spelling or nesting, raw strings, broken dates. No brand gives a neutral card.
- `BankCard.lastFour` for APIs that only send the last four digits.
- `CardDisplay`: show, mask or hide each field. Missing data is drawn as stars.
- `BankCardWallet`: stacked wallet with deal-in and pull-out.
- `BankCardForm`: live entry form with brand detection, CVV flip and validation.
- `BankCardView` and `CardBrandMark` for lists.
- English and Arabic.
