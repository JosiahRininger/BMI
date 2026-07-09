# BMI Calculator — Localization Roadmap

App: **BMI Calculator – Fast & Simple** (id 1467544257) · currently US-English only.
Date: 2026-06-18 · Cross-links: [`ASO.md`](./ASO.md) · [`MONETIZATION.md`](./MONETIZATION.md) · [`BUILD_STATUS.md`](./BUILD_STATUS.md)

> Principle: **chase revenue-per-hour, not raw installs.** A US/UK/DE user is worth 5–50× an
> India/Brazil/Indonesia user on banner eCPM + IAP. Localize the rich markets; skip the
> download-volume traps. Most locales are **metadata-only** (Minimum Viable Localization ≈ 1 week
> each); the *one* genuine product change is UK "stone" units.

## Priority order

| Stage | Locale | Why | Work |
|---|---|---|---|
| **1** | **English (UK)** | #2 Health & Fitness market, top-3 iOS banner eCPM; **zero translation** (still English); EN-GB is a *secondary* indexed locale across most storefronts → broad keyword reach | **Product: add "stone" weight mode** (Core done ✓) + EN-GB keyword field + UK screenshots |
| **2** | **German (DE → AT, CH)** | Among the highest-monetizing EU markets (ads + spend); already metric | Metadata + keywords (MVL) |
| **3** | **Spanish (ES-ES + ES-MX)** | Largest multi-country unlock (Spain + LatAm); **ES-MX is also indexed in the US storefront** → a US-reach keyword hack | Metadata + keywords (MVL) |
| 4 (opt) | French / Japanese | France solid; Japan pays well but needs *true* localization + native review (CJK), higher effort | MVL (FR) / full (JP) |
| ❌ skip | Portuguese-BR, Hindi, Indonesian | High installs, **low eCPM + IAP** — poor revenue-per-hour | — |

## Stage 1 — English (UK): the one product change

**Stone (st) = 14 lb ≈ 6.35029 kg** is how the UK/Ireland think about body weight. The app currently
offers only metric (kg) and imperial (lb). Adding a stone mode differentiates it in a top market.

- ✅ **Core done + tested**: `BMICalculator.kilograms(fromStone:pounds:)` and
  `stoneAndPounds(fromKilograms:)` (5/5 `swift test`). BMI math unchanged — stone is input-conversion only.
- ⏳ **UI wiring (your Xcode task)**: add a 3rd weight option ("st") to the weight picker/`UnitSystem`
  path, formatting as `12 st 5 lb`, using the Core helpers. Height stays ft-in or cm. See `BUILD_STATUS.md`.
- **EN-GB keyword field** (no overlap with title/subtitle, singular, comma-no-space):
  `bmi,body mass index,weight,stone,healthy,nhs,obesity,chart,kid,metric,imperial,calorie,fat,age`
- Screenshots: show the **stone** result so UK users see themselves in it.

## Per-locale keyword fields (verified local terms)

- **EN-GB** — see above (`stone`, `nhs` are the UK-distinct wins).
- **German (DE)** — `bmi rechner,bmi berechnen,body mass index,körpergewicht,gewicht,abnehmen,größe,kalorie,kind,fett,alter` (watch ~35% text expansion on screenshots/subtitle).
- **Spanish (ES-ES, LatAm)** — `calculadora imc,calcular imc,indice de masa corporal,peso,obesidad,salud,altura,caloria,niño,edad`
- **Spanish (ES-MX, US storefront)** — fill with *extra English* terms (pure US-reach hack, indexed alongside English-US): `tracker,index,loss,trend,widget,spotlight,siri,metric,imperial`
- (FR) `calcul imc,indice de masse corporelle,obesite,sante`
- (JP) `bmi 計算,体格指数,肥満,ダイエット` — needs native review before shipping.

## Mechanics & expected lift
- Each localization = its own indexed **Title (30) + Subtitle (30) + Keywords (100)** ≈ +160 indexable chars. Keywords combine **only within** a locale — never duplicate across locales; add *new* terms each.
- **EN-GB** is a secondary indexed locale in most storefronts (reach beyond Britain). **ES-MX** is indexed in the **US** storefront (the reach hack).
- Realistic planning lift per well-chosen market: **+15–40% installs** (store-listing localization ≈ +38% organic; localized screenshots ≈ +33–36% conversion). The old Distimo "+128%/+26%" figure is directional only.

## Caveats
- Per-keyword search volumes are paywalled; the priority order is anchored on **monetization** (eCPM/IAP by country) + obesity-prevalence demand proxies + competitor localization footprints — validate the keyword strings in a logged-in Keyword Planner/Ahrefs before finalizing.
- eCPM dollar values are directional; the **rank order** (US/UK/DE/CA/AU/Nordics high; IN/BR/ID low) is robust.
- **Stone is the only product change** — everything else is metadata/keywords. Re-verify BMI math is unchanged when wiring the stone UI (Core already is: 1 st = 6.35029318 kg).
