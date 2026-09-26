# Build Plan

Ordered by dependency and by earliest useful slice. Spend tracking comes before
the pantry, because it delivers value without first typing in 80 items.

The receipt pipeline is built in the order `review -> capture -> read`, not the
order it runs in. The review screen is the feature; the scanner prefills it.

## Milestone 1 - Foundation

- [x] 1. **Firebase and sign in** - wire up Firebase, sign in with a manually created account, app shell and navigation, Firestore and Storage security rules requiring auth.

## Milestone 2 - Spend tracking

- [x] 2. **Item catalogue** - create, edit and list items with name, unit, category, average piece weight, daily usage and low threshold.
- [x] 3. **Record a purchase** - the review and commit screen: date, shop, total, who paid, line items, creating unknown items inline, writing the spend and restocking stock in one action.
- [x] 4. **Spending reports** - monthly totals by person, category and shop, each person's spend against an equal share, and month to month comparison.

## Milestone 3 - Pantry

- [x] 5. **Stock tracking** - derived current stock from the baseline formula, automatic daily decrease for staples, consumption logging for irregular items, recount and ad hoc adjustment.
- [x] 6. **Running low on the home screen** - items below threshold, calculated from stock, clearing themselves when restocked.
- [x] 7. **Run out notifications** - predict the empty date and schedule a local notification ahead of it.

## Milestone 4 - Shopping list

- [x] 8. **Shared shopping list** - manual entries syncing live between users, cleared automatically when a confirmed purchase matches them.

## Milestone 5 - Receipts

- [x] 9. **Receipt capture** - photograph the scontrino, store it, attach it to a purchase, queue the upload when offline.
- [x] 10. **On device receipt reading** - ML Kit text recognition plus a parser for total, date and line items, prefilling the review screen on Android and iOS.
- [x] 11. **Learned receipt mapping** - the alias table, so a receipt line mapped once to an item and quantity resolves automatically every time after.

## Milestone 6 - Finish

- [x] 12. **CSV export** - export a month of purchases and share it.
- [x] 13. **Large screen and web layout pass** - responsive reports and tables, and the manual entry path for receipts on web where ML Kit is unavailable.

## Milestone 7 - Mobile redesign

Implements the Figma design (project plan, section 7) on the features above.
Mostly presentation; items 18, 19 and 20 add small pieces of data.

- [ ] 14. **Design tokens and theme** - `AppColors` and the theme from the Figma variables: light surfaces, navy text, brand green, positive, negative and warning colours, text styles on CenturyGothic 400 and 700, radii and spacing. Light top bars replace the green app bar.
- [ ] 15. **App shell** - bottom navigation with Home, Pantry, List and Spending, and an Account screen opened from the Home avatar with the household and sign out.
- [ ] 16. **Home** - month glance, scan hero with take photo, gallery and manual entry, running low rows with add to list, shopping list preview, and the first-run empty state.
- [ ] 17. **Review screen** - receipt strip, payer chips, unmatched lines grouped on top in red, the match line sheet with item search and the learning note, and the new item sheet.
- [ ] 18. **Saved summary** - what a save did: spend, items restocked and created, list entries cleared, lines learned, spend-only lines, photo upload state. The commit outcome reports these counts.
- [ ] 19. **Pantry** - grouped list with filter chips and a status per item; item detail with the run-out date, add to shopping list, and stock history read from `consumptionEvents`.
- [ ] 20. **Purchase history** - a month's purchases grouped by day, and a read-only purchase detail with its lines and the receipt photo.
- [ ] 21. **Spending** - month total and change, who paid against the equal share, by category, by shop, and recent purchases.
- [ ] 22. **Shopping list tab** - the full list with add, a shared indicator, and running-low suggestions added with one tap.
