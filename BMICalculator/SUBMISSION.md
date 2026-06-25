# BMI Calculator — App Store Submission Package

Everything needed to take the SwiftUI/iOS 26 rewrite from "builds locally" to
"Submitted for Review." Copy/paste the metadata, answer the questionnaires with
the recommended answers, follow the checklist at the end.

App: **BMI Calculator** · Apple ID **1467544257** · Bundle **com.jdr.BMI**
Updates the existing live listing (currently v1.2).

---

## ⚠️ 0. One decision to make first: ship v1 ad-free?

The current build **excludes the Google AdMob SDK** (it's blocked by the VPN and
needs your AdMob account + real ad-unit IDs). So this submission is **ad-free**,
monetized only by the one-time **BMI Pro** in-app purchase (export + themes +
profiles).

I've already made the build honest for that: the banner placeholder and the
"Remove all ads" claim now appear **only** when the ad SDK is linked (all behind
`#if canImport(GoogleMobileAds)`), so nothing promises ads that aren't there.
When you later wire AdMob, those return automatically.

- **Recommended: submit ad-free now.** Cleanest App Review (no ad SDK = no IDFA,
  simplest privacy answers), and the Pro IAP still monetizes. Add AdMob + the
  "Remove Ads" benefit in a fast-follow update.
- **Alternative: hold for AdMob.** Requires getting off the VPN to fetch the SPM
  package, your AdMob account, and real ad-unit IDs, then re-doing the privacy
  answers (IDFA = Yes, "Data Used to Track You", etc.). Slower.

**The rest of this doc assumes the ad-free path.** Where the ad path differs, it's
called out.

---

## 1. App version & build

- Set **MARKETING_VERSION** to something above the live `1.2` — recommend **`2.0`**
  to signal the full rewrite (or keep `1.3`; your call). It's `project.yml` →
  app target → `MARKETING_VERSION`.
- Bump **CURRENT_PROJECT_VERSION** (build number) on every upload; it's currently
  `1`. Each TestFlight/App Store upload needs a unique, increasing build number.
- After editing `project.yml`: `xcodegen generate`, then Archive.

---

## 2. App Store listing metadata (US English) — copy/paste

> Source: `ASO.md` (keyword research). Finalized here. All ≤ field limits.

**App Name (Title)** — ≤30 chars:
```
BMI Calculator: Weight Index
```

**Subtitle** — ≤30 chars:
```
Body Fat Tracker & Calorie Log
```
> Both "Body Fat" and "Calorie" map to real features (US Navy body-fat + BMR/TDEE),
> so this won't trip the "marketing features that don't exist" rejection. If you
> want to be extra-strict about the word "Log" (the metrics screens compute rather
> than persist), use `Body Fat & Calorie Calculator` instead.

**Keywords** — ≤100 chars, no spaces, singular:
```
loss,health,fitness,ideal,chart,kid,child,metric,imperial,height,obesity,widget,navy,muscle,scale,age
```

**Promotional Text** — ≤170 chars (editable any time without review):
```
Now rebuilt for iOS 26: a faster, private BMI tracker with trends, widgets, body-fat & calorie tools, Apple Health sync, and optional BMI Pro. No account, ever.
```

**Description** (compliance-checked — no diagnostic claims, screening-tool
disclaimer present):
```
BMI Calculator helps you understand your body mass index and track it over time. Fast, private, and free.

Enter your height and weight and get your BMI instantly, with a clear, color-coded category and a plain-language explanation of what the number means. Switch between metric and imperial units, and choose the BMI standard that fits you, including WHO/CDC cutoffs and WHO Asian action points.

WHAT YOU CAN DO
• Calculate BMI in seconds with a clean, accessible interface
• See body fat and ideal-weight estimates alongside your BMI
• Track every result in your history and watch the trend chart over weeks and months
• Add Home Screen and Lock Screen widgets to see your latest number at a glance
• Use Spotlight and Siri Shortcuts to calculate without even opening the app
• Sync weight and height with Apple Health so your data stays consistent across apps
• Designed for adults, with support for child and teen BMI-for-age context

BMI PRO (optional, one-time purchase)
• Export your history to CSV or PDF
• Custom accent themes
• Track multiple people (family or clients)
A single purchase — no subscription, ever.

PRIVATE BY DESIGN
Your measurements stay on your device. No account, no sign-up, and no selling of your data.

A NOTE ON HOW TO USE THIS APP
BMI is a screening tool, not a diagnosis. It is a general indicator that does not measure body composition directly and does not account for muscle mass, bone density, or other individual factors. This app is for general informational and educational purposes only and is not a substitute for professional medical advice. Please talk with a qualified healthcare provider about your health and before making changes to diet or exercise.

Download BMI Calculator and start tracking your numbers today.
```
> _(Ad path only: add "• Remove ads" under BMI PRO.)_

**What's New (release notes)**:
```
A complete rewrite for iOS 26 — faster, cleaner, and more private.
• New: history with a trend chart, Home/Lock Screen widgets, and Spotlight & Siri shortcuts
• New: body-fat %, ideal weight, calorie needs (BMR/TDEE), waist-to-height, and frame-size tools
• New: Apple Health sync, and an optional BMI Pro upgrade (export, themes, multiple profiles)
• Redesigned, accessible interface with full light & dark mode support
• Lots of fixes and reliability improvements
```

**URLs**:
- **Support URL** (required): a simple page or `https://josiahrininger.com/bmi/support`
  (can be a mailto-style contact page). Must resolve.
- **Marketing URL** (optional): `https://josiahrininger.com/bmi`
- **Privacy Policy URL** (REQUIRED — HealthKit apps must have one):
  `https://josiahrininger.com/bmi/privacy` → host `PRIVACY_POLICY.md` there.

**Category**: Primary **Health & Fitness**. Secondary (optional) **Medical**.

**Localizations** (optional, later): `ASO.md §6` has distinct en-GB / en-AU
keyword fields ready when you want to add those storefronts.

---

## 3. In-App Purchase setup (App Store Connect → Features → In-App Purchases)

The app reads a **non-consumable** product whose id is hardcoded in
`Services/StoreService.swift`:
```
removeAdsProductID = "com.bmi.removeads"
```
- Create one **Non-Consumable** with **Product ID exactly `com.bmi.removeads`**
  (it MUST match the code, or purchases fail). The id is internal/invisible to
  users — its legacy "removeads" name is fine.
  - _Optional cleanup:_ if you'd rather the id read "pro", change the constant to
    e.g. `com.jdr.BMI.pro`, rebuild, and create that id instead. Not required.
- **Reference Name:** `BMI Pro`
- **Display Name (localization):** `BMI Pro`
- **Description:** `Unlock history export (CSV & PDF), custom accent themes, and tracking for multiple people. One-time purchase, no subscription.`
- **Price:** $4.99 (Tier 5) — matches the monetization plan.
- **Review screenshot:** a screenshot of the in-app paywall (the "BMI Pro" sheet).
- **Submit the IAP WITH the app version** (first-time IAPs are reviewed alongside
  the binary; attach it to the version under "In-App Purchases").

---

## 4. App Privacy ("nutrition label") — App Store Connect → App Privacy

This build collects nothing. Answer:

- **"Do you or your third-party partners collect data from this app?"** → **No**
  → the label becomes **"Data Not Collected."**
  - Rationale: height/weight/BMI/history live only on device; HealthKit data
    stays on device and is never sent to you; the IAP is processed by Apple, not
    you; there are **no analytics, no ads, no tracking, no servers**.
- **Data Used to Track You:** none.
- **Data Linked to You:** none.
- **Data Not Linked to You:** none.

> **Ad path only:** if AdMob is added, this changes substantially — you'd declare
> "Identifiers (Device ID)" and likely "Usage Data" under **Data Used to Track
> You** + "Data Linked/Not Linked," set IDFA = Yes, and update the privacy policy.
> Don't ship ads without redoing this section.

The `PrivacyInfo.xcprivacy` manifests already in the build (no tracking, no
collected types, UserDefaults reasons CA92.1 + 1C8F.1) back up these answers.

---

## 5. Age Rating questionnaire (the "health app" question you asked about)

Apple's **new 2025 questionnaire** (mandatory) added a **"Medical or Wellness
Topics"** question, plus In-App Controls, Capabilities, and Violent Themes. New
tiers are 4+, 9+, 13+, 16+, 18+.

Recommended answers:

- **Medical or Wellness Topics:** the app presents BMI categories and body-fat /
  calorie **estimates** (general health/wellness information) — but **no
  diagnosis and no treatment advice**, with disclaimers throughout. Select the
  **lowest applicable level** for "references to general health/wellness or
  medical information" (the "**Infrequent/Mild**"-style option, not
  "Frequent/Intense"). Do **not** claim it provides treatment/medical advice.
  - Expected resulting rating: **12+/13+** (typical for health-info apps). That's
    fine — it does not restrict distribution.
  - If the questionnaire offers a "does this app provide medical
    *treatment/dosage* information?" → **No**.
- **Capabilities** (chat / messaging / web browsing / user-generated content):
  **No** to all — the app has none.
- **Unrestricted Web Access / In-app browser:** the only web view is the in-app
  Safari sheet that opens **your own privacy policy** (a fixed URL), not arbitrary
  browsing → answer **No** to unrestricted web access.
- **In-App Controls / Parental controls:** **None**.
- **Violence, sexual content, profanity, gambling, contests, horror, drugs:**
  **None**.
- **Made for Kids:** **No** (general audience; do not enroll in Kids Category).

Answer honestly; the disclaimers + "informational, not a diagnosis" framing is
exactly what keeps a BMI app in the safe zone for Guideline 1.4.1 (physical harm).

---

## 6. App Review Information — what to tell the reviewer

**Export compliance:** already auto-answered — `ITSAppUsesNonExemptEncryption =
NO` is in the build's Info.plist (standard HTTPS only), so no manual prompt.

**Content rights:** "Does your app contain, display, or access third-party
content?" → **No.** (All content is original; the only external link is your own
privacy policy.)

**Advertising identifier (IDFA):** **No** (ad-free build; the AdMob SDK isn't
linked).

**Sign-in required / demo account:** **No account needed** — leave demo
credentials blank; everything works without sign-in.

**Notes for the reviewer (paste into "Notes"):**
```
BMI Calculator is a private, on-device health-screening tool. Key points for review:

• Not a diagnosis. The app presents BMI categories and body-fat/calorie estimates as general informational/educational screening figures, with a "screening tool, not a diagnosis — talk to a healthcare provider" disclaimer on the result screen, in History, in Settings, and on every metrics screen. No diagnostic, disease-detection, or treatment claims are made.

• Health data is firewalled (Guideline 5.1.3). HealthKit is used only to (a) optionally read recent height/weight to prefill the calculator and (b) optionally write a weight/BMI sample back to Health. Health data never leaves the device and is never used for advertising or analytics. This build contains no advertising or analytics SDKs at all.

• Privacy. All data (measurements, history, profiles) is stored on-device only. No account, no servers, no tracking. Privacy policy: https://josiahrininger.com/bmi/privacy

• In-app purchase. One non-consumable, "BMI Pro" (com.bmi.removeads), unlocks history export (CSV/PDF), custom themes, and multiple profiles. No subscription. The free tier is fully functional; the 6 calculators are all free.

• Child/teen support is BMI-for-age informational context only; the app is a general-audience tool, not directed at children.

No special steps are needed to exercise any feature; everything is reachable from the main tabs.
```

---

## 7. Screenshots

**Required sizes (2026):**
- **iPhone 6.9"** — **1320 × 2868 px** (iPhone 17 Pro Max). Apple auto-scales this
  to smaller iPhones, so this is the only iPhone size you must provide. (1290×2796
  is an accepted fallback.)
- **iPad 13"** — **2064 × 2752 px** — **required because the app supports iPad**
  (`TARGETED_DEVICE_FAMILY = 1,2`). _(If you'd rather not ship iPad screenshots,
  you could set the app to iPhone-only — but the app already runs on iPad, so
  providing them is the better path.)_
- PNG or JPEG, RGB, no alpha, exact dimensions. 1–10 per device class.

**The 6 frames (from `ASO.md §3`, value → usage → trust):**
1. Hero result card (big BMI + color band) — caption "Know your number in 2 seconds"
2. History trend chart trending down — "See your progress, not just today"
3. Body-fat / ideal-weight + unit toggle — "Body fat, ideal weight, your units"
4. Widgets + Spotlight result — "Check it without opening the app"
5. Apple Health sync screen — "Syncs with Apple Health automatically"
6. Privacy/trust frame — "Private, free, and trusted"

> Keep captions claim-free (no "diagnose"/"medical-grade").

**How to capture (once your simulator/host is healthy again — see the note in
§9):** run on the iPhone 17 Pro Max simulator, navigate to each screen, ⌘S to
save a 1320×2868 screenshot, then add device-frame + caption in your tool of
choice. I can generate the raw simulator screenshots for you in one pass once the
CoreSimulator runner is unwedged — just say the word.

---

## 8. Step-by-step: from now to "Submitted for Review"

**A. Code/build prep (mostly done):**
1. [x] App Group + HealthKit entitlements, privacy manifests, URL scheme, export-
   compliance flag — all codified in the repo.
2. [ ] Set the version (`MARKETING_VERSION` → 2.0 or 1.3) and bump the build
   number in `project.yml`; run `xcodegen generate`.
3. [ ] **Fix the host first:** the test/run launcher is wedged
   (CoreSimulator/PTY). **Reboot the Mac**, then confirm `xcodebuild … test` runs
   green (219 tests) and the app launches on your iPhone.

**B. Signing & capabilities (first device build):**
4. [ ] Open the project in Xcode; with **automatic signing** + your team, let it
   register **HealthKit** and **App Groups** on the App ID (accept any prompt).
5. [ ] Confirm it installs and runs on your iPhone (USB if Wi-Fi debugging is
   flaky — see §9).

**C. App Store Connect setup (web):**
6. [ ] Host the **privacy policy** (`PRIVACY_POLICY.md`) at
   `josiahrininger.com/bmi/privacy`; set the **Support URL** too.
7. [ ] Create the **BMI Pro** non-consumable IAP (`com.bmi.removeads`, $4.99) —
   §3 — and attach it to the new version.
8. [ ] Create a **new version** on the existing app (1467544257). Paste the
   **metadata** (§2): name, subtitle, keywords, promo text, description, what's
   new, URLs, category.
9. [ ] Complete **App Privacy** = Data Not Collected (§4).
10. [ ] Complete the **Age Rating** questionnaire (§5).
11. [ ] Fill **App Review Information**: content rights = No, IDFA = No, no demo
    account, paste the **reviewer notes** (§6).

**D. Build upload:**
12. [ ] In Xcode: **Product → Archive** (Release, "Any iOS Device"), then
    **Distribute App → App Store Connect → Upload**. (Or export the .ipa and use
    Transporter.)
13. [ ] Wait for processing (a few min–1 hr), then select that build on the
    version page. Export compliance is pre-answered by the plist flag.

**E. Screenshots & submit:**
14. [ ] Upload the **6.9" iPhone + 13" iPad screenshots** (§7).
15. [ ] **Add for Review → Submit for Review.** Choose manual or automatic
    release. (Optional: do a quick **TestFlight** internal pass first.)

**Typical Apple review time:** ~24–48h. Health apps occasionally draw a question
about diagnostic claims — the reviewer notes (§6) pre-empt it.

---

## 9. Known blockers / things to track (status)

| Item | Status | Owner |
| --- | --- | --- |
| Host CoreSimulator/PTY wedge (can't run/launch) | **Blocks build-to-device** | Reboot the Mac (you) |
| AdMob SDK + ad-unit IDs | Excluded → ad-free v1 (recommended) | You (account + non-VPN network), later |
| App Store Connect IAP product | Not created yet | You (§3) |
| Privacy policy + support pages hosted | Not live yet | You (§2, §6) |
| App icon (incl. alternate icons) | Needs final art | You / design |
| Screenshots captured | Plan ready; raw capture blocked by §9 host issue | Me (once host healthy) / you |
| Intent-result persistence (Siri calc → History) | Deferred (widget-target restructure) | Later |

Everything in the **repo** (entitlements, manifests, build config, code) is ready;
the open items above are account/asset/host tasks on your side. Engineering-wise
the branch is submittable.
