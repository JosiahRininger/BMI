# BMI Calculator — Organic Growth Playbook ($0 budget)

App: **BMI Calculator** — Apple ID `1467544257`
Constraints: solo dev · local-first · zero-maintenance · no backend · free app monetized by one **AdMob banner** + a one-time **"Remove Ads" IAP** (`com.bmi.removeads`)
Date: 2026-06-18
Cross-links: [`ASO.md`](./ASO.md) (metadata, screenshots, ratings, PPO) · [`BUILD_STATUS.md`](./BUILD_STATUS.md) (what actually ships / integration TODOs)

> This is a growth plan for a **utility**, not a social app. Utilities don't go viral; they get
> *found* (ASO) and occasionally *passed along* (a good share). Everything below is ranked to
> respect that, and to respect a hard rule: **anything that needs a server, an account, or
> cross-device attribution is out of scope.** We grow with on-device mechanics and the App Store's
> own measurement, or we don't grow.

---

## 1. TL;DR

**The one highest-leverage move:** ship a **beautifully designed, opt-in, progress-framed
shareable card.** Render it on-device with SwiftUI's `ImageRenderer`, hand it to the system share
sheet (`ShareLink`), and bake into the image a footer with the App Store deep link
(`https://apps.apple.com/app/id1467544257`) and a "Made with BMI Calculator" wordmark + icon. This
is the **Spotify Wrapped / Strava activity-card** pattern: the user shares *their progress* because
it makes them look good, and the artifact quietly advertises the app to everyone who sees it. It
needs **zero backend** — the image is generated and shared entirely locally.

**The one hard constraint (don't fight it):** **true referral attribution is impossible on iOS
without a backend**, and even with one it's degraded post-ATT. You cannot reliably know that
install B came from user A's share. So **do not build double-sided referral rewards, "invite a
friend" credit, or anything that pays out on a confirmed referral.** Build the *visibility*
(the watermarked card) and measure the aggregate lift with App Store Connect campaign links —
never per-user referral plumbing.

Net: **ASO is the engine; the share card is the flywheel that supplements it.** Do ASO first
(`ASO.md`), then add the card.

---

## 2. Prioritized growth mechanics

Ranked by **impact ÷ (effort × risk)**. "Local-first" build column = what you actually implement
with no server. Risk = privacy + stigma + App Review.

| # | Mechanic | What to build (local-first) | Expected impact | Build effort | Privacy / stigma risk | Evidence |
|---|----------|------------------------------|-----------------|--------------|------------------------|----------|
| **1** | **ASO foundation** | Metadata + screenshots per `ASO.md`; wire `ReviewPrompter.recordSuccessfulCalc()` so the **system ratings prompt** fires after a *successful* calc (peak-positive moment, gated 7d/3-calcs/30d-apart/3-per-yr) | **Highest.** This is where ~all discovery comes from for a utility; ratings lift both rank and conversion | Low–Med (metadata is text; ratings hook is a 1-line call that's currently missing — see `BUILD_STATUS.md` §B) | Low (use Apple's `RequestReviewAction`; never gate on a 👍/👎 pre-screen) | Apple/AppTweak: **~65% of App Store downloads happen directly after a search**, so keyword rank is the dominant lever for utilities |
| **2** | **Shareable progress card** | `Features/Share/` — `ImageRenderer` → 1080×1920 PNG → `ShareLink`; footer with App Store deep link + wordmark; **progress/streak/trend framing, opt-in only** | High *ceiling*, unproven floor — this is the only mechanic with a real shot at compounding visibility. Treat its K as something to **measure** (§6) | Med (it's a self-contained SwiftUI view + renderer; no networking) | **Med — this is the one to get right.** Default to trend/effort, never an absolute BMI/weight number; strictly opt-in (§4, §5) | **Spotify Wrapped drove 500M+ shares in 2025**; **Strava's activity card is a literal "billboard"** athletes post to feeds — both are watermarked, progress-framed, server-rendered-but-shareable artifacts |
| **3** | **Widgets as passive-visibility surface** | Already in scope (`BMIWidget`): Home/Lock-Screen + Control Center. Wire the **widget data writer** (`BUILD_STATUS.md` §B) so the latest entry actually shows | Med — every glance is a re-engagement; widgets keep a *zero-maintenance* app on the user's screen and surface it to over-the-shoulder viewers | Low (already built; just needs the App-Group writer) | Low — but the widget must **not** show a bare BMI number on the Lock Screen by default (over-the-shoulder exposure); prefer a trend glyph / "tap to view" | **Locket hit ~2M users in 2 weeks** purely as a widget — the home-screen surface itself is a growth channel, not just a feature |
| **4** | **Shame-free local streak + milestones** | On-device streak ("logged 5 days") + gentle milestones; **no punishment, no guilt push notifications, no broken-streak shaming.** A missed day is silent | Med — retention, not acquisition; retained users are the ones who later share and rate | Low–Med (local counter + milestone copy; the *copy* is the risk surface) | Med — streaks can become punitive fast; the design rule is *celebrate presence, never punish absence* | **Finch (self-care) reached ~$30–40M ARR with an explicitly shame-free model** — kindness retains; punitive streaks churn and earn 1-stars |
| **5** | **Share-to-unlock cosmetic** | On the *share action* (not a verified install), unlock a cosmetic locally — e.g. an extra card theme / accent. Granted by observing the share completion, stored in `UserDefaults` | Low–Med — a nudge that increases share rate without any attribution backend | Low (a boolean unlock keyed off the share-sheet completion handler) | Low–Med — keep the reward **cosmetic** (never gate a real feature behind sharing, never gate "Remove Ads") | Reframes the unprovable "referral" into a provable *local* event (the user tapped share); compounds mechanic #2 |
| **6** | **App Clip "instant BMI"** | A tiny App Clip that computes BMI from a tapped link / NFC / code, with a "Get the full app" affordance | Low–Med — a frictionless top-of-funnel for shared links and (later) any web presence | Med–High (separate App Clip target, size budget, invocation setup — real work for a solo dev) | Low (no health data needed for a one-shot calc) | Apple positions App Clips as a low-friction acquisition path; pairs naturally with the share card's link |
| **7** | **App Store campaign links** | Generate App Store Connect **campaign/provider links** for each surface (card footer, widget "share app", site) to read **aggregate** source attribution | Low direct, **high informational** — this is *how you measure* mechanics #2/#5 without a backend | Low (generated in App Store Connect; just append the token to the link) | None | App Store Connect campaign links are Apple's sanctioned, ATT-safe way to attribute installs *in aggregate* — the only honest way to know if the card works |

**Sequencing within the table:** do **#1 first and let it settle** (see §7). #2–#4 are the
compounding layer. #5 is a cheap multiplier on #2. #6/#7 are optional and measurement-gated.

---

## 3. Do NOT build (negative leverage)

Each of these *looks* like growth and actually costs you installs, ratings, or an App Review
rejection.

- **Double-sided referral rewards ("invite a friend, you both get X").**
  *Why not:* post-ATT iOS has **no reliable install attribution** without a backend, and you have
  no backend. You'd be promising a reward you can't verify was earned — which either breaks (no
  payout → angry users) or gets gamed. The honest substitute is the **share-to-unlock cosmetic
  (#5)**, which rewards the *local* share action, not an unprovable referral.

- **Public BMI / weight leaderboards.**
  *Why not:* needs a server (out of scope) **and** turns a private health metric into a public
  ranking — the exact opposite of the app's "Private. On-device. No account." promise, and a
  magnet for body-comparison harm. Negative on privacy, stigma, *and* architecture.

- **"Share your BMI number" prompts / before-after photos / punitive streaks / guilt
  notifications.**
  *Why not:* sharing a raw BMI or weight number, before/after bodies, or "You broke your streak 😢"
  pushes are **documented to backfire** — they trigger body-comparison and shame, drive
  uninstalls, and invite **1-star reviews** on a health app. Share *trend and effort*, celebrate
  *presence*, and stay silent on absence (this is the §4/§5 design discipline, stated as a
  prohibition here).

- **Gifting the "Remove Ads" IAP.**
  *Why not:* **Apple does not support gifting in-app purchases** (gifting is for paid apps and some
  other IAP types, not a free app's non-consumable unlock). There's no compliant way to ship
  "gift Remove Ads to a friend," so don't design a flow around it.

- **Any advertising targeted using HealthKit data.**
  *Why not:* **App Store Review Guidelines 5.1.2 / 5.1.3 forbid using Health/HealthKit data for
  advertising or marketing.** The AdMob banner must be served with **no health signal** (the app
  already plans **NPA / non-personalized ads only**, no `NSUserTrackingUsageDescription` — see
  `BUILD_STATUS.md`). The **health → ad firewall must stay verified.** This is a rejection-and-
  removal risk, not a style preference.

---

## 4. Share-card spec

Implemented in **`Features/Share/`** (`ImageRenderer` to rasterize a SwiftUI view → `ShareLink`
to present it). No networking; the PNG is generated and shared entirely on-device.

**Canvas & layout**
- **1080 × 1920 px** (9:16 — the portrait story/feed format every platform accepts).
- **Safe zone ≈ 250 px** clear at top and bottom (story UI chrome and platform overlays live
  there). Keep all meaningful content in the central band.
- **Brand footer** (bottom safe-ish strip, above the 250px reserve): app icon + **"Made with BMI
  Calculator"** wordmark + the App Store link
  `https://apps.apple.com/app/id1467544257` (optionally tagged with an App Store Connect campaign
  token, §6/§7).

**Content framing (the part that keeps it safe and shareable)**
- Show **PROGRESS, streak, or trend** — e.g. "Down a trend over 6 weeks," "12-day logging streak,"
  a sparkline of the trend chart. This is *Strava-card* energy: it's about the effort, not the
  weigh-in.
- **Never** render an absolute **BMI value or body weight by default.** A user can *opt in* to
  include the number, but the default card is number-free.
- **Strictly opt-in.** The card is generated only when the user taps "Share progress." Nothing is
  shared automatically, ever.

**Why this shape:** it mirrors Wrapped/Strava — a watermarked, progress-framed, on-device-rendered
artifact that flatters the sharer and advertises the app to the audience, with **no server and no
personal health number leaking**.

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
  broader weight-stigma literature) shows shame *worsens* outcomes and drives avoidance. So:
  **no punitive streaks, no guilt notifications, no "you gained" framing.** Celebrate showing up.
- **HealthKit data may never be used for ads or marketing** (Guidelines **5.1.2 / 5.1.3**). Keep
  the **health → ad firewall verified**; ads stay **non-personalized**; health is **never** listed
  in the privacy manifest as ad-related data.
- **Share trend/effort, opt-in, no default-on body numbers.** Restating §4's rule as a compliance
  guardrail: the default shared artifact contains **no absolute BMI/weight**, and **nothing leaves
  the device without an explicit tap.**

---

## 6. k-factor reality check + measurement

**Set expectations honestly.** A "k-factor" (new users each existing user brings) above 1 means
self-sustaining viral growth. **A utility like this will not hit that.** A realistic viral
coefficient for a well-designed utility share is a **small fraction — roughly K ≈ 0.05–0.2** — and
that's a *supplement* to ASO, **not a replacement** for it.

Do the math with that framing:
- K = (share rate) × (shares per sharer) × (install rate per view). Every one of those terms is a
  fraction, so the product is small. A card that's shared by, say, 5% of active users, seen by a
  handful of people each, with a low single-digit % install-per-view, lands in the 0.05–0.2 band.
- **The "watermark → install %" lift is unproven** for this app. The Wrapped/Strava evidence shows
  the *pattern* works at scale; it does **not** give you a number you can assume. **Treat the
  card's K as a quantity to measure, not a number to promise.**

**How to measure without a backend:**
- Put a distinct **App Store Connect campaign link** in the card footer (and a different one in any
  "share the app" widget action, and another on the website if there is one). App Store Connect
  reports installs per campaign **in aggregate** — ATT-safe, no per-user tracking.
- Compare install/impression deltas in App Store Connect **before vs. after** turning the card on,
  against the ASO baseline. If the campaign-tagged installs and the post-launch lift are real,
  the card earns its keep; if not, you've spent a weekend and learned the floor.
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
4. **In parallel (from ~day 17) — turn on the share card + streak.** Ship `Features/Share/` (§4)
   and the shame-free streak (§2 #4). Tag the card footer with an App Store Connect campaign link
   (§6) so its lift is separable from the PPO test.
5. **Throughout — drive ratings.** The ratings prompt (step 1) runs continuously after successful
   calcs; reply to any 1–2★ reviews to protect the average. Ratings volume + average is the single
   biggest conversion multiplier and feeds rank back into step 1.
6. **Day ~107 — read the results.** Promote the PPO winner only if it wins Conversion Rate without
   hurting retention. Check the campaign-tagged installs to decide whether the share card cleared
   its (measured, not assumed) bar. Re-allocate any zero-impression keyword tokens.

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

> See [`MONETIZATION.md`](./MONETIZATION.md) for the pricing/upsell/Pro-bundle plan that turns these
> installs into revenue.

---

### One-paragraph honest summary

For a free, local-first BMI utility, **organic growth is ~80% ASO and ~20% a well-made, opt-in,
progress-framed share card**, with widgets and a kind streak keeping people around long enough to
rate and share. There is **no viral loop to engineer** and **no referral system worth building** on
iOS without a backend — so don't. Ship the metadata, earn the ratings, render a card people are
proud to post, measure its lift with App Store campaign links, and stay rigorously on the right
side of both the **weight-stigma** and **HealthKit-advertising** lines. See [`ASO.md`](./ASO.md)
for the metadata/screenshot/ratings detail and [`BUILD_STATUS.md`](./BUILD_STATUS.md) for the
integration TODOs (ratings hook, widget writer, ad firewall) this plan depends on.
