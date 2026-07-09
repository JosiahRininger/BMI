# BMI Calculator — Monetization Plan (one-time "Remove Ads" unlock)

App: **BMI Calculator** (id 1467544257) · model: free + ONE **non-personalized** AdMob banner +
a one-time **non-consumable** "Remove Ads" unlock (`com.bmi.removeads`). **No subscription · no
interstitial in the shipping build · no rewarded/video ads.**
Date: 2026-06-18 · Cross-links: [`GROWTH.md`](./GROWTH.md) · [`BUILD_STATUS.md`](./BUILD_STATUS.md) · [`ASO.md`](./ASO.md)

AdMob (shipping): app ID `ca-app-pub-6687613409331343~7486203316` · banner unit
`ca-app-pub-6687613409331343/5598406572`. Ads are **non-personalized** (`npa=1`) and firewalled from
all on-device health data (weight/height/BMI is never used for ad targeting).

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
| $6.99+ | Too high for an ad-removal-only unlock — nothing else is gated, so there's no extra value to justify the jump. |

Net per buyer at $4.99 = $4.99 × 0.85 ≈ **$4.24** (Apple Small Business 15%). Never hardcode the
price — the app uses `product.displayPrice` (already wired).

**Threshold to change:** if analytics show unlock conversion < ~1% of *engaged* users **and** reviews
cite price → test $3.99/$2.99. If conversion > ~3% with few price complaints → there may be room to
nudge the price up, but an ad-removal-only unlock has limited pricing headroom.

## 2. Upsell placement — ranked (deploy top-to-bottom)

1. **Soft, dismissible "Remove Ads" card on the result screen** after a calc (the "aha" moment). *(ResultCard already has an upsell hook + `onShowPaywall`.)*
2. **"Remove Ads" affordance near the banner itself** — highest intent (the user feels the exact friction); a low rating-risk relief valve.
3. **One-time soft prompt after ~3–5 calculations.**
4. **Permanent "Remove Ads" + "Restore Purchases" in Settings** *(already present)* — low conversion, but Restore here is **required** by Apple.
5. **Skippable post-onboarding card** (optional).
6. **❌ Never a hard launch wall.** Core BMI must stay free (ASO + ratings depend on it).

**Frequency / rating guardrails:** show the purchase prompt at most once/session, remember dismissals,
and never interrupt mid-input. The shipping build serves a **single banner only** — the post-calc
interstitial code exists but is **dormant/off**. AdMob itself warns pure utilities are weak interstitial
fits, which is one reason it stays off; if it's ever enabled, tie it strictly to "calculation complete"
and cap it at ≤ 1 per session. Watch retention/ratings as you tune.

## 3. The unlock — what the $4.99 buys

The single non-consumable does one thing: **it removes ads.**

- [x] **Remove ads** — hides the banner (and the dormant interstitial, if it's ever turned on). *(`StoreState.isPro` → `AdsManager.setPro(true)` — wired.)*

Paywall + Settings copy list exactly this — ad removal only, nothing more to gate or over-promise.

> **Scope note (this doc previously described a multi-feature "BMI Pro" bundle).** The app has been
> slimmed to a focused **BMI-only** app, so the former bundle extras are **no longer in the product**:
> CSV/PDF export, multiple profiles, and custom accent themes have all been removed, along with the 6
> adjacent calculators (body fat, TDEE/BMR, ideal weight, waist-to-height, frame size, lean mass). The
> unlock is now **ad-removal only**; there is no "Pro" tier beyond removing ads.

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

This is **one-time** per cohort, **plus** ongoing (modest) ad revenue from non-payers — the shipping
build serves a single banner only, so banner eCPM sets the ad ceiling. Replace these planning ranges
with your App Store Connect analytics + Benchmarks tab after 60–90 days.

**Caveat:** one-time-unlock conversion data is thin and subscription-biased industry-wide; treat every
number here as a planning assumption to validate against your own funnel.
