# BMI Calculator — Monetization Plan (one-time "Remove Ads / Pro" unlock)

App: **BMI Calculator** (id 1467544257) · model: free + AdMob banner + ONE post-calc interstitial +
a one-time **non-consumable** unlock (`com.bmi.removeads`). **No subscription.**
Date: 2026-06-18 · Cross-links: [`GROWTH.md`](./GROWTH.md) · [`BUILD_STATUS.md`](./BUILD_STATUS.md) · [`ASO.md`](./ASO.md)

> Reality check: a BMI calculator is a **low-frequency utility**, so both ad revenue and unlock
> conversion are structurally capped. The biggest revenue lever is **downloads × retention**
> (`GROWTH.md` / `ASO.md`), not squeezing the funnel. Monetize gently; over-monetizing a free
> utility trades a few dollars for 1-star reviews that cap everything.

## 1. Price — launch at **$4.99**

| Price | Use it when |
|---|---|
| **$4.99 (recommended)** | Default. Charm-priced (left-digit effect), still impulse-band; intent-driven buyers barely change conversion vs $2.99, so $4.99 usually wins on **total revenue**. |
| $3.99 | If you value buyer **volume / reviews / word-of-mouth** over revenue-per-sale. |
| $2.99 | Floor / temporary launch promo to seed reviews, then raise. |
| $1.99 / $0.99 | Too low — signals "hobby"; you only sell the unlock once, so you can't recover the gap. |
| $6.99+ | Only if you ship a genuinely rich Pro bundle (widgets + Watch + export + profiles). |

Net per buyer at $4.99 = $4.99 × 0.85 ≈ **$4.24** (Apple Small Business 15%). Never hardcode the
price — the app uses `product.displayPrice` (already wired).

**Threshold to change:** if analytics show unlock conversion < ~1% of *engaged* users **and** reviews
cite price → test $3.99/$2.99. If conversion > ~3% with few price complaints → test $6.99 *with* a richer bundle.

## 2. Upsell placement — ranked (deploy top-to-bottom)

1. **"Remove Ads" affordance on / right after the interstitial** — highest intent (user feels the exact friction); low rating-risk relief valve.
2. **Soft, dismissible "Go Pro" card on the result screen** after a calc (the "aha" moment). *(ResultCard already has an upsell hook + `onShowPaywall`.)*
3. **One-time soft prompt after ~3–5 calculations.**
4. **Frequency-triggered prompt after the Nth interstitial** ("Tired of ads? Remove them forever") — frequency-capped.
5. **Permanent "Upgrade to Pro" + "Restore Purchases" in Settings** *(already present)* — low conversion, but Restore here is **required** by Apple.
6. **Skippable post-onboarding card** (optional).
7. **❌ Never a hard launch wall.** Core BMI must stay free (ASO + ratings depend on it).

**Frequency / rating guardrails:** ≤ 1 interstitial per session initially; only after a *completed calculation*, never on launch or mid-input; show the purchase prompt at most once/session and remember dismissals. AdMob itself warns pure utilities are weak interstitial fits — so tie the single interstitial strictly to "calculation complete." Watch retention/ratings as you tune.

## 3. Pro bundle — what the $4.99 unlocks

Bundling ad-removal with real capability converts better than ad-removal alone and justifies $4.99.

- **Remove all ads** (banner + interstitial). *(`StoreState.isPro` → `AdsManager.setPro(true)` — wired.)*
- **History + trend chart export (CSV / PDF)** — local-first, high perceived value.
- **Multiple profiles** (family / clients).
- **Custom themes / alternate app icons.**
- *(Defer Apple Watch + extra widgets to a possible richer $6.99 tier or v2.)*

### ✅ Decided: the 6 extra calculators are FREE
Research conflicted — monetization research listed "extra calculators" as the highest-WTP Pro feature,
while growth/ASO research treats them as download + retention + keyword drivers. **Decision: keep the 6
calculators FREE** (they're the discovery/word-of-mouth engine and the `ASO.md` "body fat / calorie"
keywords lean on them; downloads are the stated #1 goal). **Pro = remove ads + history/CSV-PDF export +
multiple profiles + themes.** This is how the code is already wired (no gate on the calculator screens).
Revisit only if revenue underperforms — then A/B moving body-fat/TDEE behind Pro is the lever, but lead
with growth.

## 4. StoreKit 2 checklist (status vs `Services/StoreService.swift`)

- [x] Non-consumable, `displayPrice` used (no hardcoded price) — **done**.
- [x] `Transaction.updates` listener started at **launch** (in `init`) — **done** (the #1 common bug, avoided).
- [x] `Transaction.currentEntitlements` read at launch; `isPro` **rebuilt** each time (not appended), so a refund clears it — **done**.
- [x] Only `.verified` transactions unlock; `transaction.finish()` after delivery — **done**.
- [x] `AppStore.sync()` **only** behind the "Restore Purchases" button (it prompts for Apple ID) — **done**.
- [x] **Local `isPro` cache** as a soft fallback for the iOS 26.x `currentEntitlements`-empty regression (StoreKit stays source of truth; refund still clears it) — **added this session**.
- [ ] **App Store Connect:** create the non-consumable `com.bmi.removeads` at **$4.99**, submit it **with the build** + a review screenshot.
- [ ] **`.storekit` config** in the scheme for simulator testing; test buy → delete → reinstall → **Restore** → unlock before submitting.
- [ ] Surface **Restore Purchases** on the paywall too (not just Settings).

## 5. Revenue model (one-time unlock; ranges, not forecasts)

Conversion of **active free users → one-time buyer**: **Low ~1% · Median ~2.5% · High ~5%** (a
low-frequency utility likely lands in the lower half). Per-buyer net ≈ **$4.24**.

| Active free users | Low (1%) | Median (2.5%) | High (5%) |
|---|---|---|---|
| 1,000 | ~$42 | ~$106 | ~$212 |
| 10,000 | ~$424 | ~$1,060 | ~$2,120 |
| 50,000 | ~$2,120 | ~$5,300 | ~$10,600 |
| 100,000 | ~$4,240 | ~$10,600 | ~$21,200 |

This is **one-time** per cohort, **plus** ongoing ad revenue from non-payers (interstitial eCPM ~$5 ≫
banner). Replace these planning ranges with your App Store Connect analytics + Benchmarks tab after 60–90 days.

**Caveat:** one-time-unlock conversion data is thin and subscription-biased industry-wide; treat every
number here as a planning assumption to validate against your own funnel.
