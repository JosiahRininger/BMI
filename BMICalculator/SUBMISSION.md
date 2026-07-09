# BMI Calculator — App Store Submission Package

Everything needed to take the SwiftUI/iOS 26 rewrite from "builds locally" to
"Submitted for Review." Copy/paste the metadata, answer the questionnaires with
the recommended answers, follow the checklist at the end.

App: **BMI Calculator** · Apple ID **1467544257** · Bundle **com.jdr.BMI**
Updates the existing live listing (currently v1.2).

---

## 0. Monetization: a banner ad + a one-time "Remove Ads" unlock

This build ships **ad-supported** and links the **Google Mobile Ads SDK**
(`GoogleMobileAds` SPM package, 12.14.0). The free tier shows **one banner ad**,
served **non-personalized** (`npa=1`). There is **no interstitial, rewarded, or
video ad** in the shipping build. A single one-time in-app purchase removes the
banner.

- **AdMob app ID:** `ca-app-pub-6687613409331343~7486203316`
- **Banner ad unit:** `ca-app-pub-6687613409331343/5598406572`
- **Remove-Ads IAP:** `com.bmi.removeads` (non-consumable — see §3)

Because the banner is non-personalized, the app does **not** use the IDFA to track
users and shows no ATT prompt. Health/measurement data is **firewalled** from ads
and is never used for advertising (see §4). Buying Remove Ads hides the banner
app-wide, with no subscription.

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
BMI Tracker & Trend Charts
```
> Both "Tracker" and "Trend Charts" map to real features (saved history + the
> trend chart), so this won't trip the "marketing features that don't exist"
> rejection.

**Keywords** — ≤100 chars, no spaces, singular:
```
loss,health,fitness,chart,trend,metric,imperial,height,obesity,widget,muscle,scale,range,asian
```

**Promotional Text** — ≤170 chars (editable any time without review):
```
Rebuilt for iOS 26: a fast, private BMI tracker with trends, a healthy-weight range, widgets, and Apple Health sync. Remove the ad with one purchase. No account, ever.
```

**Description** (compliance-checked — no diagnostic claims, screening-tool
disclaimer present):
```
BMI Calculator helps you understand your body mass index and track it over time. Fast, private, and free.

Enter your height and weight and get your BMI instantly, with a clear, color-coded category and a plain-language explanation of what the number means. Switch between metric and imperial units, and choose the BMI standard that fits you, including WHO/CDC cutoffs and WHO Asian action points.

WHAT YOU CAN DO
• Calculate BMI in seconds with a clean, accessible interface
• See the healthy weight range for your height, shown in your units
• Track every result in your history and watch the trend chart over weeks and months
• Add Home Screen and Lock Screen widgets to see your latest number at a glance
• Use Spotlight and Siri Shortcuts to calculate without even opening the app
• Sync weight and height with Apple Health so your data stays consistent across apps
• Designed for adults — clear, non-judgmental, and person-first throughout

REMOVE ADS (optional, one-time purchase)
The free version shows a single, non-personalized banner ad. Prefer none? One tap removes it for good — no subscription, ever.

PRIVATE BY DESIGN
Your measurements stay on your device. No account, no sign-up, and no selling of your data. Your health data is never used for ads.

A NOTE ON HOW TO USE THIS APP
BMI is a screening tool, not a diagnosis. It is a general indicator that does not measure body composition directly and does not account for muscle mass, bone density, or other individual factors. This app is for general informational and educational purposes only and is not a substitute for professional medical advice. Please talk with a qualified healthcare provider about your health and before making changes to diet or exercise.

Download BMI Calculator and start tracking your numbers today.
```
**What's New (release notes)**:
```
A complete rewrite for iOS 26 — faster, cleaner, and more private.
• New: history with a trend chart, Home/Lock Screen widgets, and Spotlight & Siri shortcuts
• New: the healthy weight range for your height, plus WHO/CDC and WHO Asian BMI cutoffs
• New: Apple Health sync, and an optional one-time Remove Ads purchase
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
  users, and it already matches what it does — "Remove Ads."
- **Reference Name:** `Remove Ads`
- **Display Name (localization):** `Remove Ads`
- **Description:** `Remove the banner ad from BMI Calculator. One-time purchase, no subscription.`
- **Price:** $1.99 — impulse-priced for an ad-removal-only unlock (see [`MONETIZATION.md`](./MONETIZATION.md); $2.99 is the revenue-leaning alternative).
- **Review screenshot:** a screenshot of the in-app Remove Ads purchase sheet.
- **Submit the IAP WITH the app version** (first-time IAPs are reviewed alongside
  the binary; attach it to the version under "In-App Purchases").

---

## 4. App Privacy ("nutrition label") — App Store Connect → App Privacy

Your app's own code collects nothing, and health data never leaves the device.
The one nuance is the **Google AdMob banner**, whose SDK collects some data to
serve the ad — so answer for the SDK, not just your code:

- **"Do you or your third-party partners collect data from this app?"** → **Yes**,
  because the Google Mobile Ads SDK collects data to serve the banner.
- **Data Used to Track You:** **none.** The banner is **non-personalized**
  (`npa=1`), so there is no cross-app/website advertising tracking and no IDFA use.
- **Data Not Linked to You:** declare the categories the AdMob SDK collects to
  serve **non-personalized** ads (typically device identifiers, plus usage and
  diagnostic data). Confirm the exact list against Google's current
  "AdMob and Apple's App Privacy questions" guidance before you submit.
- **Data Linked to You:** **none.**
- Your **health/measurement data** (height, weight, BMI, history) is **not
  collected**: it lives only on device, HealthKit data stays on device and is
  never sent to you, and it is firewalled from the ad SDK. The IAP is processed by
  Apple, not you.

The `PrivacyInfo.xcprivacy` manifest in the build (UserDefaults reasons CA92.1 +
1C8F.1), plus the Google Mobile Ads SDK's own bundled privacy manifest, back up
these answers.

---

## 5. Age Rating questionnaire (the "health app" question you asked about)

Apple's **new 2025 questionnaire** (mandatory) added a **"Medical or Wellness
Topics"** question, plus In-App Controls, Capabilities, and Violent Themes. New
tiers are 4+, 9+, 13+, 16+, 18+.

Recommended answers:

- **Medical or Wellness Topics:** the app presents BMI categories and a
  healthy-weight range (general health/wellness information) — but **no
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

**Content rights:** the app's own content is original. It does display
**third-party banner ads served by Google AdMob** (under your AdMob agreement),
and the only external link is your own privacy policy. Answer the App Store
Connect "third-party content" prompt accordingly for an app that shows ad-network
banners.

**Advertising identifier (IDFA):** the banner is served **non-personalized**
(`npa=1`), so the app does **not** use the IDFA to track users and shows no ATT
prompt. Answer the App Store Connect IDFA prompt for a non-personalized-ads build
(no tracking); confirm against Google's AdMob guidance.

**Sign-in required / demo account:** **No account needed** — leave demo
credentials blank; everything works without sign-in.

**Notes for the reviewer (paste into "Notes"):**
```
BMI Calculator is a private, on-device BMI screening tool. Key points for review:

• Not a diagnosis. The app presents BMI categories and a healthy-weight range as general informational/educational screening figures, with a "screening tool, not a diagnosis — talk to a healthcare provider" disclaimer on the result screen, in History, and in Settings. No diagnostic, disease-detection, or treatment claims are made.

• Advertising. The free tier shows a single Google AdMob banner, served non-personalized (npa=1). There are no interstitial, rewarded, or video ads, and the ads do not track users (no IDFA-based tracking, no ATT prompt).

• Health data is firewalled (Guideline 5.1.3). HealthKit is used only to (a) optionally read recent height/weight to prefill the calculator and (b) optionally write a weight/BMI sample back to Health. Health data never leaves the device and is never used for advertising or analytics.

• Privacy. All measurements and history are stored on-device only. No account, no servers, no tracking. Privacy policy: https://josiahrininger.com/bmi/privacy

• In-app purchase. One non-consumable, "Remove Ads" (com.bmi.removeads), removes the banner. No subscription. The free tier is fully functional.

• General-audience adult BMI tool. Not directed at children; no data collected from anyone.

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
3. Healthy weight range + unit toggle — "Your healthy range, in your units"
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
   green (115 tests) and the app launches on your iPhone.

**B. Signing & capabilities (first device build):**
4. [ ] Open the project in Xcode; with **automatic signing** + your team, let it
   register **HealthKit** and **App Groups** on the App ID (accept any prompt).
5. [ ] Confirm it installs and runs on your iPhone (USB if Wi-Fi debugging is
   flaky — see §9).

**C. App Store Connect setup (web):**
6. [ ] Host the **privacy policy** (`PRIVACY_POLICY.md`) at
   `josiahrininger.com/bmi/privacy`; set the **Support URL** too.
7. [ ] Create the **Remove Ads** non-consumable IAP (`com.bmi.removeads`) —
   §3 — and attach it to the new version.
8. [ ] Create a **new version** on the existing app (1467544257). Paste the
   **metadata** (§2): name, subtitle, keywords, promo text, description, what's
   new, URLs, category.
9. [ ] Complete **App Privacy** (§4): **Data Collected = Yes** — the AdMob SDK
   only (device identifiers + usage/diagnostics, **Data Not Linked**, **no
   Tracking** since `npa=1`); your health/measurement data is **not** collected.
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
| AdMob SDK + ad-unit IDs | **Done** — GoogleMobileAds SPM 12.14.0 linked; real app ID + banner unit wired (§0) | — |
| App Store Connect IAP product | Not created yet | You (§3) |
| Privacy policy + support pages hosted | Not live yet | You (§2, §6) |
| App icon (incl. alternate icons) | Needs final art | You / design |
| Screenshots captured | Plan ready; raw capture blocked by §9 host issue | Me (once host healthy) / you |
| Intent-result persistence (Siri calc → History) | Deferred (widget-target restructure) | Later |

Everything in the **repo** (entitlements, manifests, build config, code) is ready;
the open items above are account/asset/host tasks on your side. Engineering-wise
the branch is submittable.
