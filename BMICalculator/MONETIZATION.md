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

## 1. Price — launch at **$1.99**

Ad-removal-only of a *single* banner is a low-perceived-value unlock, so price it in the impulse band,
not the premium-feature band. This is a deliberate change from the old **$4.99**, which was set when
"Pro" bundled export + custom themes + multiple profiles. With those features cut, $4.99 has nothing
extra to justify it and would convert poorly — most people would just tolerate the banner.

| Price | Use it when |
|---|---|
| **$1.99 (recommended)** | Default for ad-removal-only. Impulse-priced — the annoyed-by-ads buyer taps without deliberating; maximizes buyers and gives the rating **relief valve** for a low-value unlock. |
| $2.99 | If you'd rather lean on **revenue-per-sale** than volume. Still impulse-band; a reasonable A/B against $1.99 once you have data. |
| $0.99 | Floor. Only if $1.99 shows real price resistance in reviews. |
| $3.99+ | Too high now that nothing but the banner is gated — it would suppress the (already small) buyer pool. |

Net per buyer at $1.99 = $1.99 × 0.85 ≈ **$1.69** (Apple Small Business 15%). Never hardcode the price
— the app uses `product.displayPrice` (already wired), so changing it later is a **one-field edit in
App Store Connect with no new build**.

**Threshold to change:** the IAP is secondary to banner revenue, so don't over-tune it. If unlock
conversion is healthy (> ~2% of *engaged* users) with no price complaints → A/B **$2.99**. If reviews
cite price or conversion is near zero → drop to **$0.99**.

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

## 3. The unlock — what the $1.99 buys

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
- [ ] **App Store Connect:** create the non-consumable `com.bmi.removeads` at **$1.99**, submit it **with the build** + a review screenshot.
- [x] **`.storekit` config** (`Products.storekit`) wired into the scheme for simulator testing — **done**. Still to do manually: test buy → delete → reinstall → **Restore** → unlock before submitting.
- [ ] Surface **Restore Purchases** on the paywall too (not just Settings).

## 5. Revenue model (one-time unlock; ranges, not forecasts)

Conversion of **active free users → one-time buyer**: **Low ~1% · Median ~2.5% · High ~5%** (a
low-frequency utility likely lands in the lower half). Per-buyer net ≈ **$1.69** (at the $1.99 price,
after Apple's 15% Small Business cut). Note the IAP is **secondary** to banner revenue here.

| Active free users | Low (1%) | Median (2.5%) | High (5%) |
|---|---|---|---|
| 1,000 | ~$17 | ~$42 | ~$85 |
| 10,000 | ~$170 | ~$423 | ~$845 |
| 50,000 | ~$845 | ~$2,113 | ~$4,225 |
| 100,000 | ~$1,690 | ~$4,225 | ~$8,450 |

This is **one-time** per cohort, **plus** ongoing (modest) ad revenue from non-payers — the shipping
build serves a single banner only, so banner eCPM sets the ad ceiling. Replace these planning ranges
with your App Store Connect analytics + Benchmarks tab after 60–90 days.

**Caveat:** one-time-unlock conversion data is thin and subscription-biased industry-wide; treat every
number here as a planning assumption to validate against your own funnel.

## 6. Price benchmarks & how to test price

**Where $1.99 sits (external benchmarks, directional — not Apple first-party data):**
- Typical one-time ad-removal band for a utility/casual app: **$0.99–$2.99**, with **$1.99 the most
  common** price point; **$3.99–$4.99** is generally reserved for premium/*bundled* unlocks — which is
  why $4.99 made sense for the old multi-feature "Pro" bundle but not for ad-removal-only.
- One-time ad-removal conversion commonly runs **~2–4% on iOS** (higher willingness-to-pay than
  Android). Third-party blog figures — validate against your own funnel.
- Real-world comps: **Fitter** charges exactly **$1.99** for ad removal (bundled with export/passcode);
  a competing BMI app used **$0.99**. So $1.99 sits at/slightly above the niche's low end — reasonable,
  with headroom to test $2.99.

**How to actually test price (Apple has no native price A/B test):**
- **Product Page Optimization (PPO) tests creative only** — icon, screenshots, previews — **not** price,
  title, or description. Don't expect PPO to answer the price question.
- Test price **sequentially**: run **$1.99 for N weeks → $2.99 for N weeks** over comparable windows and
  compare **revenue-per-download** and conversion. Optionally use **Custom Product Pages** for
  campaign-specific messaging. Changing the IAP price is a one-field edit in App Store Connect (no build).
- **Decision threshold:** if ad-removal conversion is materially **below ~2%**, the prompt
  **timing/placement** is the likelier culprit, not the price — fix the UX first (show the upsell after
  the first result "aha moment", keep it dismissible, always ship **Restore Purchases**), *then* test price.
