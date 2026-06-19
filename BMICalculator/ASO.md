# BMI Calculator — App Store Optimization Plan

App: **BMI Calculator** — Apple ID `1467544257`
Category: Health & Fitness (Primary). Suggested secondary: Medical.
Date: 2026-06-18

---

## 0. Situation & Diagnosis

| Signal | Current state | Implication |
| --- | --- | --- |
| Title | `BMI Calculator - Fast & Simple` (29 chars) | Spends ~14 chars on "Fast & Simple" — non-searched filler. |
| Subtitle | `Check out your Body Mass Index` (30 chars) | Stop-words ("Check out your") + duplicate of title noun ("Body Mass Index"). Near-zero incremental keyword coverage. |
| Ratings | 8 ratings | Below the social-proof floor (~50). Conversion and rank both suppressed. |
| Impressions | Low-intent surge | Apple Search / browse is serving the app to broad, non-converting queries. We need to **re-target keywords toward high-intent long-tail** and lift the conversion rate so the algorithm keeps the good traffic and sheds the junk. |

**Strategy in one line:** stop wasting metadata on the obvious word "BMI", capture adjacent high-intent demand (weight, tracker, ideal weight, body fat, kids), and convert it with a social-proof + benefit-led page.

> Metadata-field rule recap (so the choices below are auditable):
> - **Title** and **Subtitle** are indexed for search and are the strongest ranking fields. ≤30 chars each.
> - **Keyword field** (100 chars) is indexed but invisible to users. Never repeat words already in Title/Subtitle — the algorithm de-dupes across fields, so repeats waste characters. No spaces after commas (commas-only saves characters). Singular forms only (Apple stems plural/singular).
> - The app name + subtitle + keyword field combine into the searchable keyword set; the algorithm also auto-combines tokens (e.g. "weight" + "loss" + "tracker" ⇒ matches "weight loss tracker").

---

## 1. Title & Subtitle (the two indexed, user-visible fields)

### Title (≤30 chars)
```
BMI Calculator: Weight Index
```
- Length: **28 / 30** characters.
- Keeps the exact-match anchor "BMI Calculator" (highest-volume head term, do not lose it).
- Replaces "Fast & Simple" (no search volume) with **Weight** and **Index** — both high-volume health tokens that now seed combinations: "weight calculator", "weight index", "BMI index", "calculate weight".

### Subtitle (≤30 chars)
```
Body Fat Tracker & Calorie Log
```
- Length: **30 / 30** characters.
- Zero stop-words. Every token is a searched keyword: **Body / Fat / Tracker / Calorie / Log**.
- No overlap with the Title tokens (BMI, Calculator, Weight, Index) — so the two fields cover disjoint vocabulary and maximize the indexed surface.
- Combinations unlocked: "body fat tracker", "fat calculator", "calorie tracker", "body fat calculator", "weight tracker" (weight from Title + tracker from Subtitle).

> **Feature-backing (now honest):** the rewrite ships a **US Navy body-fat %** calculator and a
> **BMR/TDEE (calorie needs)** calculator (`Core/HealthCalculators.swift`, verified), so "Body Fat"
> and "Calorie" in the subtitle/keywords map to real features — this clears the Apple
> metadata-rejection risk of marketing features that don't exist. Note "**Log**" implies persistent
> logging; the calculators compute rather than log, so if you want to be strict, prefer a subtitle
> like `Body Fat & Calorie Calculator` over "…Log", or ship the history-logging tie-in for these metrics.

**Combined indexed head/mid terms after rewrite:** bmi, calculator, weight, index, body, fat, tracker, calorie, log — plus all auto-combinations across the two fields.

---

## 2. Keyword Field (100 chars, US English)

Rules applied: comma-separated, **no spaces**, **singular**, **no word already in Title/Subtitle** (bmi, calculator, weight, index, body, fat, tracker, calorie, log are all excluded), long-tail / modifier tokens that the algorithm will recombine.

```
loss,health,fitness,ideal,chart,kid,child,metric,imperial,height,obesity,widget,navy,muscle,scale,age
```

Character count (incl. commas): **97 / 100**. ✅

Token-by-token rationale:

| Token | Why it's here | Notable combinations it unlocks |
| --- | --- | --- |
| `loss` | "weight loss" is the single biggest adjacent intent | weight loss, fat loss, weight loss tracker |
| `health` | category relevance + broad | health tracker, health log |
| `fitness` | category relevance | fitness tracker, fitness calculator |
| `ideal` | high-intent calc query | ideal weight, ideal body weight |
| `chart` | feature + query | bmi chart, weight chart, body fat chart |
| `kid` | distinct child audience | bmi kid, weight kid |
| `child` | child-percentile searchers (singular, not "children") | bmi child, child weight |
| `metric` | unit-system searchers | metric bmi, metric calculator |
| `imperial` | unit-system searchers | imperial bmi |
| `height` | core input term, own demand | height weight chart, height calculator |
| `obesity` | clinical-adjacent intent | obesity calculator, obesity chart |
| `widget` | differentiator we actually ship | bmi widget, weight widget |
| `navy` | "navy body fat method" — strong niche, low competition | navy body fat, navy fat calculator |
| `muscle` | body-composition intent | muscle fat, muscle calculator |
| `scale` | "weight scale" companion search | weight scale, body scale |
| `age` | "bmi for age" (kids percentile) | bmi age, weight age |

No duplicates within the field; no duplicates against Title/Subtitle.

---

## 3. Screenshot Plan — 6 frames, Value → Usage → Trust

Conversion research: on the search results card and the top of the product page, **frames 1–3 carry ~80% of the install decision**. Lead with value, then show it's effortless to use, then prove trust. Use captions (benefit-first, not feature-first), bold legible type, and the brand accent color. Portrait 6.9"/6.7" set is the master; down-size for 6.5"/5.5".

| # | Order tier | Visual | Benefit caption (≤7 words) |
| --- | --- | --- | --- |
| 1 | **Value** | Hero result card: large BMI number + color category band + "where you are" pointer on the scale | **Know your number in 2 seconds** |
| 2 | **Value** | Trend chart screen (History/TrendChart) showing a line trending down over weeks | **See your progress, not just today** |
| 3 | **Value** | Body-fat / ideal-weight result with metric–imperial toggle visible | **Body fat, ideal weight, your units** |
| 4 | **Usage** | Home Screen + Lock Screen widgets and a Spotlight "Calculate BMI" result | **Check it without opening the app** |
| 5 | **Usage** | Apple Health sync screen — weight/height flowing in, results flowing out | **Syncs with Apple Health automatically** |
| 6 | **Trust** | Ratings/review motif + "Private. On-device. No account." + screening-tool disclaimer line | **Private, free, and trusted** |

Notes:
- Frame 1's caption must be readable at thumbnail size — it's what shows in search results.
- Keep captions person-first and claim-free (no "diagnose", "detect disease", "medical-grade").
- Consider an **App Preview video** later (optional) reusing frames 1→2→4 motion.

---

## 4. Ratings Plan — `RequestReviewAction` (SKStoreReviewController successor)

Goal: move from **8 ratings → 100+ at ≥4.5★** within ~90 days.

The app already ships `Services/ReviewPrompter.swift`, which wraps StoreKit's `RequestReviewAction` and self-limits. Keep its gates (they are already compliant and good-citizen):

| Gate | Value | Reason |
| --- | --- | --- |
| Trigger event | **After a successful calculation** | Peak-positive moment, never mid-input or on error. |
| Min days installed | 7 | Don't burn the budget on day one. |
| Min successful calcs | 3 | Only ask engaged users. |
| Min days between prompts | 30 | Spacing inside Apple's window. |
| Max prompts / 365 days | **3** | Apple's hard ceiling; respect it explicitly. |

Operational rules:
- **Never** show a custom "Rate us" modal that blocks or precedes the system sheet, and never gate it on a star pre-selection ("Enjoying the app? 👍/👎 then route") — Apple rejects rating-gating. Use the system prompt directly.
- Keep a passive **"Rate BMI Calculator" row in Settings** linking to `…?action=write-review` for users who want to volunteer a review outside the prompt budget.
- Throughput math: 3 prompts/user/yr × even a low accept rate, applied to current calc volume, clears 100 ratings well within 90 days; the surge in impressions means raw funnel volume is not the constraint — the social-proof lift is.
- Watch for and reply to (where possible) any 1–2★ reviews; protecting the **4.5★** average matters more than raw count for conversion.

---

## 5. Product Page Optimization (PPO) — A/B Test Plan

Because traffic is modest, run **one treatment vs. the current default for the full 90-day maximum** to reach significance. Do **not** split into multiple simultaneous treatments — it would starve each arm.

| Parameter | Setting |
| --- | --- |
| Test type | App Store Connect **Product Page Optimization** (organic page A/B test) |
| Treatments | **1 treatment** vs. original (2 arms total) |
| Traffic split | 50% / 50% |
| Duration | **90 days** (the max; required at this volume for power) |
| Localizations under test | US English (the test reads the device locale's page) |
| Primary metric | Conversion Rate (impression → download) |
| Guardrail metric | Retention day-1 (don't win installs that bounce) |

**What the single treatment changes (one coherent hypothesis):** new **screenshot set (Section 3)** + new **app icon variant** (cleaner mark, higher contrast for thumbnail legibility). Hypothesis: a benefit-led, value-first first-three-frames sequence lifts conversion vs. the current generic shots.

- Keep metadata (Title/Subtitle/keywords) **out** of the PPO test — those ship as a normal version update (Section 1–2) so we don't confound the screenshot test with a search-rank change.
- Ship the metadata update **first**, let rank settle ~1–2 weeks, **then** start the 90-day PPO so the baseline is stable.
- Decision rule at day 90: promote the treatment only if it wins on Conversion Rate **without** degrading day-1 retention beyond noise.

---

## 6. Added Localizations — English (UK) & English (Australia)

> **Full roadmap → [`LOCALIZATION.md`](./LOCALIZATION.md).** Prioritize by *revenue-per-hour*: **EN-GB
> first** (add the **stone** weight unit — a real product win in a top-3 eCPM market; Core conversions
> are built + tested), then **German**, then **Spanish** — and fill the **Spanish (Mexico)** keyword
> field in the *US* storefront with extra English terms as a US-reach hack. Deprioritize
> Portuguese-BR / Hindi / Indonesian (high installs, low eCPM + IAP).

Adding `en-GB` and `en-AU` localizations creates **two more indexed keyword fields** for English-speaking storefronts. The catch: do **not** copy the US keywords — duplicate keywords across these locales add nothing. Use **different, locale-distinct long-tail terms** so each storefront indexes incremental vocabulary.

> Localized Title/Subtitle can stay close to US for brand consistency; the **keyword fields must differ**. Singular, comma-no-space, ≤100 chars, and still no overlap with that locale's Title/Subtitle tokens.

### English (UK) — keyword field
```
loss,nhs,stone,centimetre,height,waist,obesity,diabetes,chart,child,metric,fitness,scale,widget,age
```
Length: **96 / 100**. Distinct picks: **nhs** (UK health authority searches), **stone** (UK weight unit), **centimetre** (UK spelling/metric), **waist** (waist-to-height), **diabetes** (risk-context query). These have real UK volume and are absent from the US field.

### English (Australia) — keyword field
```
loss,kilo,kilojoule,waist,height,fitness,obesity,chart,child,metric,pregnancy,scale,widget,age,navy
```
Length: **97 / 100**. Distinct picks: **kilo** / **kilojoule** (AU energy unit vs. US "calorie"), **pregnancy** (pregnancy-weight queries), plus AU-relevant fitness/obesity terms. Differs from both US and UK fields (no `nhs`/`stone`/`centimetre`/`diabetes`; adds `kilo`/`kilojoule`/`pregnancy`).

Cross-locale check: US uses `calorie`/`imperial`/`ideal`/`muscle`/`health`; UK uniquely adds `nhs`/`stone`/`centimetre`/`waist`/`diabetes`; AU uniquely adds `kilo`/`kilojoule`/`pregnancy`. Shared utility tokens (`loss`,`height`,`chart`,`obesity`,`child`,`metric`,`fitness`,`scale`,`widget`,`age`) are acceptable to repeat across **storefronts** since each storefront is indexed independently — the no-duplicate rule applies *within* a single locale's field set, not across countries. The locale-specific tokens are what make each addition worthwhile.

---

## 7. App Store Description (fresh, compliant)

Compliance constraints honored: **no diagnostic/medical claims** (no "diagnose", "detect", "treat", "medical-grade"), **person-first** language, explicit **screening-tool disclaimer**, and it highlights the features the app actually ships (widgets, Spotlight/App Shortcuts, Apple Health, history/trends).

```
BMI Calculator helps you understand your body mass index and track it over time — fast, private, and free.

Enter your height and weight and get your BMI instantly, with a clear, color-coded category and a plain-language explanation of what the number means. Switch between metric and imperial units, and choose the BMI standard that fits you, including WHO/CDC cutoffs and WHO Asian action points.

WHAT YOU CAN DO
• Calculate BMI in seconds with a clean, accessible interface
• See body fat and ideal-weight estimates alongside your BMI
• Track every result in your history and watch the trend chart over weeks and months
• Add Home Screen and Lock Screen widgets to see your latest number at a glance
• Use Spotlight and Siri Shortcuts to calculate without even opening the app
• Sync weight and height with Apple Health so your data stays consistent across apps
• Designed for adults, with support for child and teen BMI-for-age context

PRIVATE BY DESIGN
Your measurements stay on your device. No account, no sign-up, and no selling of your data.

A NOTE ON HOW TO USE THIS APP
BMI is a screening tool, not a diagnosis. It is a general indicator that does not measure body composition directly and does not account for muscle mass, bone density, or other individual factors. This app is for general informational and educational purposes only and is not a substitute for professional medical advice. Please talk with a qualified healthcare provider about your health and before making changes to diet or exercise.

Download BMI Calculator and start tracking your numbers today.
```

Description compliance checklist:
- [x] No diagnostic or disease claims; "screening tool, not a diagnosis" stated explicitly.
- [x] Person-first ("helps you understand…", "talk with a qualified healthcare provider").
- [x] Screening-tool + "not a substitute for professional medical advice" disclaimer present.
- [x] Highlights widgets, Spotlight/Siri Shortcuts, Apple Health sync, history/trend chart — all features present in the codebase.
- [x] Privacy/on-device messaging matches the app's local-persistence design.

---

## 8. Rollout Sequence (recommended order)

1. **Ship metadata update** (Title, Subtitle, US keyword field, new description) as a normal version.
2. **Add `en-GB` and `en-AU`** localizations with their distinct keyword fields in the same version.
3. **Confirm `ReviewPrompter` gates** match Section 4 and ship the Settings "Rate" row.
4. Let search rank settle **~1–2 weeks**.
5. **Start the 90-day PPO** test (new screenshots + icon variant), 50/50.
6. **Review at day 90**: promote the PPO winner on Conversion Rate without retention regression; reassess keyword fields against Search-term report data and re-allocate any zero-impression tokens.
```
