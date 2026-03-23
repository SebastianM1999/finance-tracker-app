# Gamification Feature Plan — FinTrack

> App is currently in **German**. All user-facing strings must be written in German. English support added later.
> Gamification toggle added **last** after everything works.

---

## Tier System

| Tier    | Level Range | Visual                                      |
|---------|-------------|---------------------------------------------|
| Bronze  | L1 – L24    | Warm copper, solid ring                     |
| Silver  | L25 – L49   | Cool chrome, solid ring                     |
| Gold    | L50 – L74   | Rich gold, slow glow pulse ring             |
| Diamond | L75 – L100  | Dark bg, prismatic color-shifting ring      |

---

## Level Curve

**Flat constant: 200 XP per level. Level 100 = 20,000 XP total.**

No exponential growth. Every level costs the same — frequent, consistent level-ups for everyone.

| Level | XP total | Level | XP total | Level | XP total |
|-------|----------|-------|----------|-------|----------|
| 1     | 0        | 26    | 5,000    | 51    | 10,000   |
| 5     | 800      | 30    | 5,800    | 60    | 11,800   |
| 10    | 1,800    | 35    | 6,800    | 70    | 13,800   |
| 15    | 2,800    | 40    | 7,800    | 80    | 15,800   |
| 20    | 3,800    | 45    | 8,800    | 90    | 17,800   |
| 25    | 4,800    | 50    | 9,800    | 100   | 19,800   |

**Weekly check-in progression:** ~165–200 XP/week from engagement → roughly 1 level per week.
**Level 100 in ~1 year** for wealthy users. ~2 years for young users with small savings.

---

## Expected Setup Levels (day 1, based on Bundesbank 2023 median wealth data)

| User profile | Net worth | Setup level |
|---|---|---|
| Teen (14-18) | €500 | ~4 |
| Teen (14-18) | €2,000 | ~6 |
| Young adult (20-25) | €10,000 | ~10 |
| Mid career (35-44) | €50,000 | ~20 |
| Late career (45-54) | €150,000 | ~42 |
| Millionaire | €1,000,000 | ~100 (capped) |

---

## XP Sources (event-driven, deduplicated by event ID in Firestore)

### Net Worth Milestones
> Deferred 24h after first install — fire on 2nd session, not day 0.
> Only the highest newly crossed milestone fires per session (no stacking of all below).

| Milestone | XP | Event ID |
|---|---|---|
| €100 | 100 | `networth_100` |
| €500 | 150 | `networth_500` |
| €1,000 | 200 | `networth_1000` |
| €2,500 | 300 | `networth_2500` |
| €5,000 | 400 | `networth_5000` |
| €10,000 | 600 | `networth_10000` |
| €25,000 | 900 | `networth_25000` |
| €50,000 | 1,400 | `networth_50000` |
| €75,000 | 1,800 | `networth_75000` |
| €100,000 | 2,400 | `networth_100000` |
| €150,000 | 3,200 | `networth_150000` |
| €250,000 | 5,000 | `networth_250000` |
| €500,000 | 8,000 | `networth_500000` |
| €750,000 | 10,000 | `networth_750000` |
| €1,000,000 | 13,000 | `networth_1000000` |

### Engagement XP
| Event | XP | Event ID | Notes |
|---|---|---|---|
| First position in a category | 50 | `first_crypto` | Max 6 categories |
| Pull-to-refresh or edit/add (12h cooldown) | 50 | `refresh_2026-03-21-AM` | 2 slots/day: AM/PM |
| Debt fully paid off | 300 | `debt_paid_DEBTID` | Per debt |
| Festgeld matures | 100 | `festgeld_matured_ID` | Per Festgeld |
| Net worth grows vs last month | 150 | `monthly_growth_2026_03` | Monthly |
| App anniversary 1yr / 2yr / 3yr | 500 | `anniversary_1` | |
| Badge unlock | varies | — | Badge XP added on top |

### Weekly / Monthly Challenge XP
| Challenge | XP | Notes |
|---|---|---|
| Wöchentlicher Check (weekly refresh done) | 50 | Resets Monday |
| Monatliches Update (position updated this month) | 75 | Resets 1st of month |
| Positiver Monat (net worth ≥ last month) | 75 | Resets 1st of month |

**Total guaranteed weekly engagement XP:**
- Refresh: 50 (AM slot) + 50 (PM slot if active) = up to 100
- Weekly challenge: 50
- Monthly pro-rated: ~37/week
- **Total: ~165–200 XP/week → roughly 1 level per week** ✓

---

## Badges (32 total — 8 categories × 4 tiers)

**Locked badges are fully hidden** — dark placeholder + "???" text. Users cannot see what they are until unlocked. Category header shows "X/4 freigeschaltet".

**Badges are permanent once earned and can never be revoked.** They represent a milestone hit at a point in time, not the current state. (e.g. net worth drops after earning Wealth Gold → badge stays. Debt added after earning Schulden Diamond → badge stays.)

### 🏆 Vermögen

| Tier    | Name             | Bedingung                  | XP    |
|---------|------------------|----------------------------|-------|
| Bronze  | Erster Tausender | Nettovermögen ≥ €1.000     | 200   |
| Silver  | Fünfstellig      | Nettovermögen ≥ €10.000    | 500   |
| Gold    | Sechsstellig     | Nettovermögen ≥ €100.000   | 1,000 |
| Diamond | Millionär        | Nettovermögen ≥ €1.000.000 | 3,000 |

### 🔀 Diversifikation

| Tier    | Name               | Bedingung                             | XP    |
|---------|--------------------|---------------------------------------|-------|
| Bronze  | Erste Schritte     | Aktiv in 2 Kategorien                 | 150   |
| Silver  | Gut aufgestellt    | Aktiv in 3 Kategorien                 | 300   |
| Gold    | Echter Diversifier | Aktiv in 4 Kategorien                 | 600   |
| Diamond | Portfolio-Meister  | Aktiv in 5 Kategorien mit je ≥ €1.000 | 1,500 |

### 💪 Schuldenabbau

> Kategorie ist versteckt bis eine der beiden Diamond-Bedingungen erfüllt ist, oder bis der Nutzer mindestens eine Schuld erfasst hat.
> Diamond hat zwei Unlock-Pfade. Schuldenfreie Nutzer erhalten es nach 1 Monat automatisch und überspringen Bronze/Silver/Gold.

| Tier    | Name            | Bedingung                                                                                                               | XP    |
|---------|-----------------|-------------------------------------------------------------------------------------------------------------------------|-------|
| Bronze  | Ehrlicher Blick | Erste Schuld erfasst                                                                                                    | 100   |
| Silver  | Erste Etappe    | Eine Schuld vollständig abbezahlt                                                                                       | 400   |
| Gold    | Hartnäckig      | 3 Schulden vollständig abbezahlt                                                                                        | 800   |
| Diamond | Schuldenfrei    | Pfad A: Alle Schulden abbezahlt & keine neuen seit 1 Jahr — Pfad B: App seit 1 Monat genutzt & nie eine Schuld erfasst | 500   |

### ⏳ Dabei seit ...

| Tier    | Name           | Bedingung                  | XP    |
|---------|----------------|----------------------------|-------|
| Bronze  | Frischer Start | App seit 2 Tagen genutzt   | 100   |
| Silver  | Dabei bleiben  | App seit 1 Monat genutzt   | 300   |
| Gold    | Ernsthaft dabei| App seit 3 Monaten genutzt | 600   |
| Diamond | Langstrecke    | App seit 1 Jahr genutzt    | 1,500 |

### 🐷 Festgeld

| Tier    | Name           | Bedingung                     | XP    |
|---------|----------------|-------------------------------|-------|
| Bronze  | Erste Anlage   | Erstes Festgeld erstellt      | 150   |
| Silver  | Sammler        | 3 oder mehr aktive Festgelder | 300   |
| Gold    | Sicher & Stetig| ≥ €10.000 in Festgeld         | 600   |
| Diamond | Festgeld-König | ≥ €100.000 in Festgeld        | 1,500 |

### ₿ Krypto

| Tier    | Name               | Bedingung                     | XP    |
|---------|--------------------|-------------------------------|-------|
| Bronze  | Erster Token       | Erste Krypto-Position         | 150   |
| Silver  | Krypto-Neugieriger | 3 oder mehr Krypto-Positionen | 300   |
| Gold    | HODLer             | ≥ €5.000 in Krypto            | 600   |
| Diamond | Krypto-Wal         | ≥ €50.000 in Krypto           | 1,500 |

### 📈 ETF & Aktien

| Tier    | Name            | Bedingung                         | XP    |
|---------|-----------------|-----------------------------------|-------|
| Bronze  | Erste Position  | Erste ETF- oder Aktienposition    | 150   |
| Silver  | Aufbauphase     | 3 oder mehr ETF/Aktien-Positionen | 300   |
| Gold    | Marktteilnehmer | ≥ €10.000 in ETFs/Aktien          | 600   |
| Diamond | Index-Legende   | ≥ €100.000 in ETFs/Aktien         | 1,500 |

### 🔄 Konsequenz

> Zählt: Pull-to-Refresh (Wischen auf Home) + Position hinzufügen/bearbeiten.
> Nicht gezählt: App öffnen ohne Aktion, automatische Hintergrund-Updates.
> Timeout: max. 1× alle 12 Stunden (2 Slots pro Tag: AM / PM).

| Tier    | Name               | Bedingung         | XP    |
|---------|--------------------|-------------------|-------|
| Bronze  | Dabei bleiben      | 3× aktualisiert   | 100   |
| Silver  | Beständig          | 6× aktualisiert   | 250   |
| Gold    | Diszipliniert      | 10× aktualisiert  | 600   |
| Diamond | Eiserne Gewohnheit | 40× aktualisiert  | 1,500 |

---

## Challenges (Herausforderungen)

### Dauerhaft (einmalig)

| ID | Titel | Beschreibung | XP |
|---|---|---|---|
| `first_position` | Erste Schritte | Erste Position in irgendeiner Kategorie | 100 |
| `three_categories` | Es wird ernst | Positionen in 3 Kategorien | 200 |
| `all_categories` | Voll diversifiziert | In allen 6 Kategorien aktiv | 500 |
| `debt_free` | Schuldenfrei | Keine aktiven Schulden | 800 |
| `five_figures` | Fünfstellig | €10.000 Nettovermögen erreicht | 300 |
| `six_figures` | Sechsstellig | €100.000 Nettovermögen erreicht | 1,000 |
| `millionaire` | Millionär | €1.000.000 Nettovermögen erreicht | 3,000 |
| `festgeld_matured` | Erste Fälligkeit | Ein Festgeld ist fällig geworden | 200 |
| `three_month_growth` | Aufwärtstrend | Nettovermögen 3 Monate in Folge gestiegen | 400 |

### Wöchentlich (weich — keine Strafe bei Nicht-Erfüllung)

| ID | Titel | Beschreibung | XP |
|---|---|---|---|
| `weekly_refresh` | Wöchentlicher Check | App einmal diese Woche aktualisiert | 50 |

### Monatlich (weich — keine Strafe bei Nicht-Erfüllung)

| ID | Titel | Beschreibung | XP |
|---|---|---|---|
| `monthly_update` | Monatliches Update | Mindestens eine Position diesen Monat aktualisiert | 75 |
| `positive_month` | Positiver Monat | Nettovermögen höher als letzten Monat | 75 |

---

## Animation Rules

### Sequencing (max 2 events per user action)
1. **Add celebration** — existing widget, auto-dismisses (~2s)
2. **Level up overlay** — fires after, user must tap to dismiss
3. **Badge toast** — ALWAYS same component, same spot (top of screen), fires after level up is dismissed

Badge toast is NEVER embedded inside the level up screen. Same design every time, regardless of context.

### Level Up Overlay
- Full screen takeover
- Background color matches new tier (Bronze warm / Silver cool / Gold rich / Diamond dark+prismatic)
- 40 floating particle orbs, slow upward drift
- "LEVEL UP" text — slides in from above, heavy font, glow shadow
- Level number counter animation: old → new (~800ms easeOut)
- XP bar resets to 0, fills to current progress
- Confetti burst at peak moment
- If tier changed: extra "Neue Stufe: Gold" banner slides in
- Tap anywhere to dismiss — no auto-close

### Badge Toast
- `OverlayEntry` at app level (above all routes)
- Slides in from top: `SlideTransition` + `FadeTransition`, 350ms easeOut
- Glassmorphism card: `BackdropFilter(blur: 12)` + translucent bg
- Tier-colored 1px border
- Content: badge icon (48px) + "Badge freigeschaltet!" caption + badge name bold
- Auto-dismiss after 4 seconds
- Tap → open BadgeDetailSheet + remove overlay

### XP Float Animation
- "+150 XP" floats up 50px, fades out
- Duration 1200ms, appears at top of triggering screen
- Bold text, gold tint (`Color(0xFFFFD700)`)

### Badge Card — Idle Animations
- Bronze / Silver: static (no idle)
- Gold: slow glow pulse, opacity 0.7 → 1.0 → 0.7, 3s loop
- Diamond: slow prismatic hue-shift gradient, 4s loop

### Badge Reveal (when unlocked)
1. White flash overlay (200ms)
2. Scale 0.05 → 1.0, `Curves.elasticOut`, 700ms
3. Tier ring draws itself (animated stroke 0 → 1, 600ms)
4. 8–12 sparkle particles burst outward
5. Gold/Diamond: shimmer sweep
6. Idle animation starts

---

## Profile Sidebar

Entry point: profile picture moved to **LEFT** side of top bar → tap → sidebar slides in from left. Right side of top bar stays free for contextual actions per screen.

```
┌──────────────────────────────┐
│                          [X] │
│                              │
│  [foto]  Sebastian           │
│          Level 23            │  ← tier ring around photo
│                              │
│  [══════XP Bar══════] 4.400  │
│                              │
├──────────────────────────────┤
│  🏅  Meine Badges   12/32  › │
├──────────────────────────────┤
│  ⚡  Herausforderungen      › │
│      Wöchentlicher Check 50XP│
├──────────────────────────────┤
│  📊  Meine Statistiken      › │
├──────────────────────────────┤
│  ⚙️   Einstellungen         › │
└──────────────────────────────┘
```

Settings moved here from bottom nav → frees a nav slot.

---

## Firestore Structure

```
users/{uid}/
  gamification/
    profile                    ← single document
      totalXP: 4400
      level: 23
      unlockedBadgeIds: ['wealth_bronze', 'crypto_bronze', ...]
      completedChallengeIds: ['first_position', ...]
      updateCount: 14
      createdAt: Timestamp
      lastCheckedAt: Timestamp

    xpEvents/                  ← subcollection, one doc per event ID
      networth_10000:
        xp: 600
        reason: 'Nettovermögen hat €10.000 erreicht'
        awardedAt: Timestamp
```

---

## New Package

```yaml
confetti: ^0.8.0   # level up confetti burst
# flutter_animate already present
```

---

## Build Order

| # | What | Notes |
|---|------|-------|
| 1 | Models + LevelSystem | Everything depends on this |
| 2 | Badge + Challenge definitions | All strings in German |
| 3 | GamificationRepository | Firestore CRUD |
| 4 | XPService | Core XP logic, deduplication |
| 5 | BadgeService | Evaluates badge conditions |
| 6 | ChallengeService | Evaluates challenge progress |
| 7 | GamificationService | Orchestrator, returns GamificationResult |
| 8 | GamificationProviders | Riverpod wiring |
| 9 | LevelUpOverlay | Biggest animation — test early |
| 10 | BadgeToast | Second key animation |
| 11 | XPFloatAnimation | Quick to build |
| 12 | BadgeCard + idle animations | Core visual component |
| 13 | TierRing | Profile picture ring |
| 14 | BadgeGridScreen | Needs BadgeCard |
| 15 | BadgeDetailSheet | Needs BadgeCard |
| 16 | ChallengeScreen | Standalone |
| 17 | ProfileSidebar | Assembles everything |
| 18 | Integration into 6 existing screens | Last — needs all above |
| 19 | App startup check | Passive time-based events |
| 20 | Gamification toggle in Einstellungen | **Very last step** |

---

## Integration Pattern (per screen)

```dart
// After existing add celebration dismisses:
final result = await ref.read(gamificationServiceProvider).onPositionChanged(
  userId: user.uid,
  isFirstInCategory: _isFirstPosition,
  categoryKey: 'crypto',
);

if (result.leveledUp) {
  await LevelUpOverlay.show(context, result);
}
if (result.hasBadges) {
  GamificationOverlay.showBadgeToast(context, result.newBadges.first);
}
if (result.xpGained > 0) {
  XPFloatAnimation.show(context, result.xpGained);
}
```

Screens to update: `GiroScreen`, `FestgeldScreen`, `EtfScreen`, `CryptoScreen`, `AssetsScreen`, `SchuldenScreen`

---

## Gamification Toggle (Step 20 — Last)

Single switch in Einstellungen:
```
Gamification
XP, Badges und Herausforderungen verfolgen    [toggle]
```

- Underlying data still accumulates silently when disabled
- Re-enabling shows everything that was earned in the background
- All gamification widgets are self-contained — one `if (!gamificationEnabled) return` per call site
