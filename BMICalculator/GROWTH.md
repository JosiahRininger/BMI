# BMI Calculator — Organic Growth Playbook ($0 budget)

App: **BMI Calculator** — Apple ID `1467544257`
Constraints: solo dev · local-first · zero-maintenance · no backend · free app monetized by one **non-personalized AdMob banner** + a one-time **"Remove Ads" IAP** (`com.bmi.removeads`)
Date: 2026-06-18 (revised 2026-07-09 — app slimmed to a focused BMI-only build)
Cross-links: [`ASO.md`](./ASO.md) (metadata, screenshots, ratings, PPO) · [`BUILD_STATUS.md`](./BUILD_STATUS.md) (what actually ships / integration TODOs)

> This is a growth plan for a **utility**, not a social app. Utilities don't go viral; they get
> *found* (ASO) and occasionally *recommended* (a good rating, word of mouth). Everything below is
> ranked to respect that, and to respect a hard rule: **anything that needs a server, an account, or
> cross-device attribution is out of scope.** We grow with on-device mechanics and the App Store's
> own measurement, or we don't grow.

---

## 1. TL;DR

**The one highest-leverage move:** win **App Store search + ratings.** For a utility, ~all discovery
is search, and ratings lift both rank and conversion. Ship the metadata and screenshots in
`ASO.md`, and wire the **system ratings prompt** so it fires after a *successful* calc
(peak-positive moment) via `ReviewPrompter.recordSuccessfulCalc()` — it's currently never called
(`BUILD_STATUS.md` §B), so the whole ratings strategy is dark until you do. Give the screenshots
something concrete to sell: the result card's new **"healthy weight range for your height"** readout
and the **history trend chart** (with the healthy band highlighted) are the two most
screenshot-able value props.

**The one hard constraint (don't fight it):** **true referral attribution is impossible on iOS
without a backend**, and even with one it's degraded post-ATT. You cannot reliably know that
install B came from user A. So **do not build double-sided referral rewards, "invite a friend"
credit, or anything that pays out on a confirmed referral.** Measure the aggregate lift of each
external channel with App Store Connect campaign links — never per-user referral plumbing.

**Scope note:** the app was slimmed to **BMI-only**. The previously planned **shareable progress
card, consecutive-day streaks, share-to-unlock cosmetics, and reminder notifications were removed**,
so this plan no longer relies on any in-app share or viral loop. Growth is now ASO + ratings, with
the **widget** and **Apple Health** as retention surfaces.

Net: **ASO is the engine; ratings are the multiplier.** Do ASO first (`ASO.md`), then keep the
ratings prompt running continuously.

---

## 2. Prioritized growth mechanics

Ranked by **impact ÷ (effort × risk)**. "Local-first" build column = what you actually implement
with no server. Risk = privacy + stigma + App Review.

| # | Mechanic | What to build (local-first) | Expected impact | Build effort | Privacy / stigma risk | Evidence |
|---|----------|------------------------------|-----------------|--------------|------------------------|----------|
| **1** | **ASO foundation** | Metadata + screenshots per `ASO.md`; wire `ReviewPrompter.recordSuccessfulCalc()` so the **system ratings prompt** fires after a *successful* calc (peak-positive moment, gated 7d/3-calcs/30d-apart/3-per-yr) | **Highest.** This is where ~all discovery comes from for a utility; ratings lift both rank and conversion | Low–Med (metadata is text; ratings hook is a 1-line call that's currently missing — see `BUILD_STATUS.md` §B) | Low (use Apple's `RequestReviewAction`; never gate on a 👍/👎 pre-screen) | Apple/AppTweak: **~65% of App Store downloads happen directly after a search**, so keyword rank is the dominant lever for utilities |
| **2** | **Widgets as passive-visibility surface** | Already in scope (`BMIWidget`): Home/Lock-Screen + Control Center. Wire the **widget data writer** (`BUILD_STATUS.md` §B) so the latest entry actually shows | Med — every glance is a re-engagement; widgets keep a *zero-maintenance* app on the user's screen and surface it to over-the-shoulder viewers | Low (already built; just needs the App-Group writer) | Low — but the widget must **not** show a bare BMI number on the Lock Screen by default (over-the-shoulder exposure); prefer a trend glyph / "tap to view" | **Locket hit ~2M users in 2 weeks** purely as a widget — the home-screen surface itself is a growth channel, not just a feature |
| **3** | **App Clip "instant BMI"** | A tiny App Clip that computes BMI from a tapped link / NFC / code, with a "Get the full app" affordance | Low–Med — a frictionless top-of-funnel for shared links and (later) any web presence | Med–High (separate App Clip target, size budget, invocation setup — real work for a solo dev) | Low (no health data needed for a one-shot calc) | Apple positions App Clips as a low-friction acquisition path; pairs naturally with any shared App Store link or `bmicalculator://` deep link |
| **4** | **App Store campaign links** | Generate App Store Connect **campaign/provider links** for each external surface (website, Reddit post, featuring pitch) to read **aggregate** source attribution | Low direct, **high informational** — this is *how you measure* the §8 external channels without a backend | Low (generated in App Store Connect; just append the token to the link) | None | App Store Connect campaign links are Apple's sanctioned, ATT-safe way to attribute installs *in aggregate* — the only honest way to know if a channel works |

**Sequencing within the table:** do **#1 first and let it settle** (see §7). **#2 (widgets)** is
already built — just wire the App-Group data writer. **#3/#4** are optional and measurement-gated.

---

## 3. Do NOT build (negative leverage)

Each of these *looks* like growth and actually costs you installs, ratings, or an App Review
rejection.

- **Double-sided referral rewards ("invite a friend, you both get X").**
  *Why not:* post-ATT iOS has **no reliable install attribution** without a backend, and you have
  no backend. You'd be promising a reward you can't verify was earned — which either breaks (no
  payout → angry users) or gets gamed. Measure channels in aggregate with campaign links (§4/§6)
  instead of paying out on an unprovable referral.

- **Public BMI / weight leaderboards.**
  *Why not:* needs a server (out of scope) **and** turns a private health metric into a public
  ranking — the exact opposite of the app's "Private. On-device. No account." promise, and a
  magnet for body-comparison harm. Negative on privacy, stigma, *and* architecture.

- **"Share your BMI number" prompts / before-after photos / punitive streaks / guilt
  notifications.**
  *Why not:* sharing a raw BMI or weight number, before/after bodies, or "You broke your streak 😢"
  pushes are **documented to backfire** — they trigger body-comparison and shame, drive
  uninstalls, and invite **1-star reviews** on a health app. (The app ships **no** share, streak, or
  notification surfaces at all, so there's nothing here to build even if you were tempted — keep it
  that way.)

- **Gifting the "Remove Ads" IAP.**
  *Why not:* **Apple does not support gifting in-app purchases** (gifting is for paid apps and some
  other IAP types, not a free app's non-consumable unlock). There's no compliant way to ship
  "gift Remove Ads to a friend," so don't design a flow around it.

- **Any advertising targeted using HealthKit data.**
  *Why not:* **App Store Review Guidelines 5.1.2 / 5.1.3 forbid using Health/HealthKit data for
  advertising or marketing.** The AdMob banner is served with **no health signal** — the app ships
  **non-personalized ads only** (`npa=1`), no `NSUserTrackingUsageDescription` (see
  `BUILD_STATUS.md`). The **health → ad firewall must stay verified.** This is a rejection-and-
  removal risk, not a style preference.

---

## 4. Share card — removed from scope

The shareable progress card (`ImageRenderer` → `ShareLink`) that earlier versions of this plan
treated as the flywheel was **cut when the app was slimmed to BMI-only.** The shipping build has
**no on-device share, export, or progress-card surface**, so there is no share-card spec to
implement and no share/viral loop for the rest of this plan to lean on. This heading is kept only as
a scope-change marker; growth now rests on ASO + ratings (§1, §2) and the external channels in §8.

---

## 5. Stigma & compliance guardrails

These are not optional polish; they're what keeps a health app off the 1-star pile and inside
Apple's rules.

- **BMI is a contested screening metric.** **CDC** frames BMI as a screening tool, not a diagnosis;
  **Stanford** and **Yale** researchers have publicly criticized its limits (it ignores body
  composition, muscle, distribution, and varies across populations). The app's copy already says
  "screening tool, not a diagnosis" (`ASO.md` §7) — every growth surface must echo that humility,
  never imply precision or judgment.
- **Weight shaming backfires.** Research (e.g., **Pearl at the University of Florida** and the
  broader weight-stigma literature) shows shame *worsens* outcomes and drives avoidance. So keep the
  category copy **person-first and supportive**, and — since the app has **no streaks and no
  notifications** — there is no "you broke your streak" or "you gained" framing to guard against;
  don't reintroduce one.
- **HealthKit data may never be used for ads or marketing** (Guidelines **5.1.2 / 5.1.3**). Keep
  the **health → ad firewall verified**; ads stay **non-personalized**; health is **never** listed
  in the privacy manifest as ad-related data.

---

## 6. Measurement without a backend

With the share card cut, there is **no viral share loop to model** — a BMI utility with no in-app
share mechanic has an effective k-factor of ~0, and that's fine: this was always ~80% an ASO play.
Don't try to manufacture a viral coefficient; grow through **search, ratings, and the external
channels in §8**, and **measure them honestly.**

**How to measure without a backend:**
- Put a distinct **App Store Connect campaign link** on each external surface (the website, any
  Reddit post, the featuring pitch). App Store Connect reports installs per campaign **in
  aggregate** — ATT-safe, no per-user tracking.
- Compare install/impression deltas in App Store Connect **before vs. after** each change, against
  the ASO baseline, so you can tell which move actually moved the needle.
- **Never** instrument this with per-user referral codes or device fingerprinting — that's the
  attribution rabbit hole §1 told you to skip, and it's an ATT/privacy liability.

---

## 7. 90-day sequence

A staged rollout so each change is measurable and nothing confounds the ASO baseline.

1. **Days 0–3 — Ship ASO metadata first.** New Title/Subtitle/keyword fields + description +
   screenshots per `ASO.md` (§1–3, §7), as a normal version update. Add `en-GB`/`en-AU` locales.
   Wire the **ratings hook** (`ReviewPrompter.recordSuccessfulCalc()`) — it's currently never
   called (`BUILD_STATUS.md` §B), so the whole ratings strategy is dark until you do.
2. **Days 3–17 — Let rank settle (~2 weeks).** Don't touch metadata or start any A/B test yet;
   you need a stable search-rank baseline before measuring anything else. Watch the Search-terms
   report.
3. **Days ~17–107 — Run the 90-day Product Page Optimization test.** One treatment vs. current
   (new screenshots + icon variant), 50/50, primary metric Conversion Rate, guardrail day-1
   retention — exactly as `ASO.md` §5 specifies. At this traffic, one treatment over the full 90
   days is what reaches significance.
4. **In parallel (from ~day 17) — harden the retention surfaces.** Wire the **widget data writer**
   (`BUILD_STATUS.md` §B) so the latest entry actually shows, and confirm the **Apple Health**
   prefill and the result card's **healthy-weight-range** readout land cleanly — these are what make
   the app worth keeping on-screen and worth rating. No new features; just make what ships work.
5. **Throughout — drive ratings.** The ratings prompt (step 1) runs continuously after successful
   calcs; reply to any 1–2★ reviews to protect the average. Ratings volume + average is the single
   biggest conversion multiplier and feeds rank back into step 1.
6. **Day ~107 — read the results.** Promote the PPO winner only if it wins Conversion Rate without
   hurting retention. Check the campaign-tagged installs (§6) to see which external channel earned
   its keep. Re-allocate any zero-impression keyword tokens.

---

## 8. External acquisition channels ($0) & the January surge

On-device mechanics (§2) compound, but **discovery still starts with ASO + Apple editorial featuring
timed to the January resolution surge** — the single highest-leverage external move. Health & fitness
installs spike sharply every January (Adjust: installs ~+36% MoM; +46% by Jan 1), and the featuring
queue is now indie-accessible.

| Channel | Verdict | What to do | Effort / payoff |
|---|---|---|---|
| **ASO foundation** | ⭐ Tier 1 | `ASO.md` metadata + screenshots + 4.0★+ rating. ~65% of downloads happen right after a search. | Low / **highest** |
| **Apple featuring + January surge** | ⭐ Tier 1 | File the **Featuring Nomination** (App Store Connect) **late Nov/early Dec**, pitch a *story* ("rebuilt around iOS 26 widgets / App Intents / HealthKit" — all of which this app now ships), get approved by **~Dec 20**, be live & updated by **Jan 1**. Editors reward new-framework adoption + a polished first-frame product page. | Low–Med / **high** (featuring × seasonal demand compound) |
| **Short-form video** (TikTok/Reels/Shorts) | Tier 2 | "Apps you didn't know you needed" + problem/solution demos; app in-hand in first 3s, name on-screen + link in bio; 3–5/week, reuse footage. | High ongoing / Med, high variance |
| **Reddit (value-first)** | Tier 2 | Build genuine karma in r/loseit, r/fitness, r/SideProject, r/iosapps; then post the free app to **r/apphookup** following its exact rules (direct App Store link, disclose you built it, no shortened URLs). | Med / Med, bursty |
| **r/SideProject "I built this"** | Tier 3 | One low-effort feedback post. | Very low / low |
| **Web BMI calculator for SEO** | ❌ Don't | The head term is locked by CDC/NIH/NHS/calculator.net (DR 90+); a new $0 site won't rank for years. | — |
| **Product Hunt / Hacker News** | ❌ Don't | Wrong audience (founders/B2B/dev tools); consumer health utilities flop there. | — |

**Hard deadline:** App Review slows ~Dec 23–27, so a January-ready build must be **submitted by
mid-December** and the nomination filed **3+ weeks ahead**. If you can't ship a feature-worthy update
by mid-Dec, file for a later seasonal moment (e.g. "summer" in June) rather than rush a weak release.
Featuring is a free lottery ticket that improves the odds — not a guarantee.

> See [`MONETIZATION.md`](./MONETIZATION.md) for the plan that turns these installs into revenue —
> now just the single one-time **"Remove Ads"** unlock (`com.bmi.removeads`); there is no multi-
> feature Pro bundle.

---

### One-paragraph honest summary

For a free, local-first BMI utility, **organic growth is overwhelmingly ASO + ratings**, with the
**widget** and **Apple Health** keeping people around and the result card's **healthy-weight-range**
readout giving them a reason to rate. There is **no viral loop to engineer** and **no referral system
worth building** on iOS without a backend — and, since the app was slimmed to BMI-only, **no share
card or streak** either. Ship the metadata, earn the ratings, keep the widget and Health integration
solid, measure external channels with App Store campaign links, and stay rigorously on the right side
of both the **weight-stigma** and **HealthKit-advertising** lines. See [`ASO.md`](./ASO.md) for the
metadata/screenshot/ratings detail and [`BUILD_STATUS.md`](./BUILD_STATUS.md) for the integration
TODOs (ratings hook, widget writer, ad firewall) this plan depends on.
