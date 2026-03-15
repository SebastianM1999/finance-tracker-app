# FinTrack – Personal Finance Tracker App
## Complete Agent Specification

---

## 1. Overview

**App Name:** FinTrack (or "Vaultly" – agent can finalize)
**Platform:** Flutter (Android primary, iOS compatible)
**Distribution:** Google Play Store + GitHub Releases (APK download)
**Purpose:** A personal finance overview app where users manually enter all their financial positions and get a unified net worth dashboard across all asset classes.

---

## 2. Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (latest stable) + Dart |
| Auth | Firebase Authentication (Google Sign-In) |
| Database | Cloud Firestore |
| Push Notifications | firebase_messaging + flutter_local_notifications |
| State Management | Riverpod (flutter_riverpod) |
| Charts | fl_chart |
| Date/Number Formatting | intl |
| Theme Persistence | shared_preferences |
| Navigation | go_router |

### pubspec.yaml dependencies (key packages)
```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.x
  firebase_auth: ^5.x
  cloud_firestore: ^5.x
  firebase_messaging: ^15.x
  flutter_local_notifications: ^18.x
  google_sign_in: ^6.x
  flutter_riverpod: ^2.x
  fl_chart: ^0.69.x
  intl: ^0.19.x
  go_router: ^14.x
  shared_preferences: ^2.x
  flutter_animate: ^4.x
  cached_network_image: ^3.x
```

---

## 3. Firebase Setup

- Enable **Google Sign-In** in Firebase Auth
- Create Firestore database in production mode
- Enable **Firebase Cloud Messaging** for push notifications
- Firestore security rules: users can only read/write their own documents
  ```
  rules_version = '2';
  service cloud.firestore {
    match /databases/{database}/documents {
      match /users/{userId}/{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
  ```
- All user data lives under: `users/{userId}/` as subcollections

---

## 4. Data Models

### 4.1 GiroKonto (Checking/Salary Account)
```
Collection: users/{userId}/giro_accounts
{
  id: String (auto)
  bankName: String           // "DKB", "Sparkasse", etc.
  accountLabel: String       // "Gehaltskonto", "Haushaltskonto"
  balance: double            // current balance in EUR
  currency: String           // default "EUR"
  notes: String?
  updatedAt: Timestamp
  createdAt: Timestamp
}
```

### 4.2 Festgeld (Fixed-Term Deposit)
```
Collection: users/{userId}/festgeld
{
  id: String (auto)
  bankName: String
  amount: double             // deposited amount
  interestRate: double       // annual interest rate in % (e.g. 3.5)
  startDate: Timestamp
  durationMonths: int        // e.g. 12
  endDate: Timestamp         // auto-calculated: startDate + durationMonths
  projectedPayout: double    // auto-calculated: amount + (amount * rate/100 * months/12)
  notes: String?
  notificationsEnabled: bool // default true
  notifiedDays: List<int>    // which notification days already fired [30, 7, 1]
  createdAt: Timestamp
}
```

### 4.3 ETF / Stocks
```
Collection: users/{userId}/etf_stocks
{
  id: String (auto)
  broker: String             // "ING", "Trade Republic", etc.
  name: String               // "MSCI World", "Apple Inc."
  ticker: String?            // "IWDA", "AAPL"
  shares: double             // number of shares/units
  buyPrice: double           // average buy price per share in EUR
  currentPrice: double       // manually entered current price
  currency: String           // default "EUR"
  assetType: String          // "ETF" | "Stock"
  lastPriceUpdate: Timestamp?
  notes: String?
  createdAt: Timestamp
}
```

### 4.4 Crypto
```
Collection: users/{userId}/crypto
{
  id: String (auto)
  exchange: String           // "Binance", "Coinbase", "Kraken"
  coinName: String           // "Bitcoin", "Ethereum"
  coinSymbol: String         // "BTC", "ETH"
  amount: double             // how many coins held
  buyPrice: double           // average buy price per coin in EUR
  currentPrice: double       // manually entered current price in EUR
  notes: String?
  createdAt: Timestamp
}
```

### 4.5 Physical Assets (Gold / Silver / Other)
```
Collection: users/{userId}/physical_assets
{
  id: String (auto)
  assetType: String          // "Gold" | "Silver" | "Other"
  description: String        // "Goldmünze 1oz", "Silberbarren 100g"
  quantity: double           // number of units
  weightPerUnit: double?     // grams per unit (optional)
  buyPrice: double           // total buy price in EUR
  currentValue: double       // manually entered current total value
  notes: String?
  createdAt: Timestamp
}
```

### 4.6 Schulden (Debts / Money Owed)
```
Collection: users/{userId}/schulden
{
  id: String (auto)
  type: String               // "I_OWE" | "OWED_TO_ME"
  personOrInstitution: String // "Max Mustermann", "Autokredit Bank"
  amount: double             // outstanding amount
  description: String?       // "Urlaub Vorauszahlung", "KFZ-Kredit"
  dueDate: Timestamp?        // optional repayment date
  createdAt: Timestamp
}
```

### 4.7 Net Worth Snapshots (optional history)
```
Collection: users/{userId}/net_worth_history
{
  id: String (auto)
  totalNetWorth: double
  breakdown: {
    giro: double,
    festgeld: double,
    etf_stocks: double,
    crypto: double,
    physical: double,
    schulden: double         // negative value
  }
  recordedAt: Timestamp
}
// Auto-saved once per day when user opens app
```

---

## 5. App Screens & Navigation

### Navigation Structure
Bottom navigation bar with 5 tabs:
1. **Home** (Dashboard icon)
2. **Investments** (chart/trending icon) → Festgeld + ETF/Stocks + Crypto + Physical
3. **Accounts** (wallet icon) → Giro accounts
4. **Debts** (balance-scale icon) → Schulden
5. **Settings** (gear icon)

### 5.1 Home Screen (Dashboard)
- **Hero section**: Large total net worth number, subtitle "Gesamtvermögen"
- **Net worth change**: Show +/- since last snapshot (yesterday)
- **Category cards** (horizontal scroll or grid):
  - Giro Konten → total balance
  - Festgeld → total deposited + projected payout
  - ETF/Stocks → total current value + P&L %
  - Crypto → total current value + P&L %
  - Physische Assets → total current value
  - Schulden → outstanding (shown in red/negative)
- **Tap any card** → navigates to that category's detail screen
- **Quick net worth chart**: Simple line chart showing last 30 days of net worth snapshots
- **Upcoming Festgeld maturities**: Banner/chip showing next maturity within 60 days

### 5.2 Investments Screen
Tabbed view (TabBar):
- **Festgeld tab**: List of fixed deposit cards + total at top + FAB to add
- **ETF/Stocks tab**: List of positions + total value + FAB to add
- **Crypto tab**: List of crypto positions + total + FAB to add
- **Assets tab**: Physical assets list + total + FAB to add

### 5.3 Festgeld Detail Card (within Investments)
Each card shows:
- Bank name + label
- Deposited amount
- Interest rate % + projected payout
- Start date → End date (with countdown "noch 47 Tage")
- Progress bar showing elapsed duration %
- Bell icon to toggle notifications
- Edit / Delete via swipe or long press

### 5.4 ETF/Stocks Position Card
- Name + Ticker
- Shares × current price = current value
- Buy price total vs current value → P&L in EUR and %
- Color: green if profit, red if loss
- "Update Preis" button to quickly update current price

### 5.5 Crypto Position Card
- Coin name + symbol + exchange
- Amount × current price = current value
- P&L calculation same as stocks

### 5.6 Accounts Screen
- List of Giro accounts
- Each shows bank, label, balance
- FAB to add new account
- Tap card to edit balance (quick balance update dialog)

### 5.7 Debts Screen (Schulden)
Two sections:
- **Ich schulde** (I owe) – shown in red
- **Mir wird geschuldet** (owed to me) – shown in green
- Net position at top
- FAB to add new debt entry

### 5.8 Settings Screen
- User profile section (Google avatar, name, email)
- **Dark mode / Light mode toggle** (persisted)
- **Currency** (default EUR, allow USD, GBP, CHF)
- **Notifications settings**: toggle all, preview scheduled notifications
- **Data**: Export as JSON button, "Alle Daten löschen" (danger zone)
- **Logout** button
- App version info

---

## 6. Push Notifications (Festgeld Maturity Reminders)

### Strategy
Use **flutter_local_notifications** for scheduling. When a Festgeld entry is created or edited, schedule local notifications for:
- **30 days before end date**: "⏰ Festgeld läuft bald ab – [BankName] – noch 30 Tage bis [EndDate]"
- **7 days before end date**: "⚠️ Festgeld läuft in 7 Tagen ab – [BankName] – [Amount]€"
- **1 day before end date**: "🔔 Morgen läuft dein Festgeld ab! [BankName] – [Amount]€ wird fällig"
- **On end date**: "✅ Festgeld [BankName] ist heute fällig! [Amount]€ + Zinsen verfügbar"

### Implementation Notes
- Cancel existing notifications when a Festgeld entry is deleted or edited
- Store notification IDs in Firestore on the Festgeld document (`scheduledNotificationIds: List<int>`)
- Request notification permissions on first launch
- On Android: use notification channels ("Festgeld Fälligkeiten")
- Background FCM: Also send FCM notification via Cloud Functions (if user has multiple devices). Optional v2 feature.

---

## 7. Design System

### Color Palette

**Dark Mode (default):**
```dart
background:      Color(0xFF0D0F14)   // near-black
surface:         Color(0xFF161B22)   // card background
surfaceVariant:  Color(0xFF1E2530)   // elevated card
primary:         Color(0xFF6C63FF)   // purple-blue accent
secondary:       Color(0xFFFF6B6B)   // coral/red for negatives
positive:        Color(0xFF4CAF82)   // green for profits
warning:         Color(0xFFFFB347)   // orange for warnings
text:            Color(0xFFF0F0F0)
textSecondary:   Color(0xFF8B8FA8)
border:          Color(0xFF2A3142)
```

**Light Mode:**
```dart
background:      Color(0xFFF4F6FA)
surface:         Color(0xFFFFFFFF)
surfaceVariant:  Color(0xFFEEF1F7)
primary:         Color(0xFF5B52E8)
secondary:       Color(0xFFE5534B)
positive:        Color(0xFF3A9A6B)
warning:         Color(0xFFE8930A)
text:            Color(0xFF0D0F14)
textSecondary:   Color(0xFF6B7280)
border:          Color(0xFFDDE1EB)
```

**Category Gradient Cards:**
- Giro Konto:     `[Color(0xFF667EEA), Color(0xFF764BA2)]` (blue-purple)
- Festgeld:       `[Color(0xFFF093FB), Color(0xFFF5576C)]` (pink-red)
- ETF/Stocks:     `[Color(0xFF4FACFE), Color(0xFF00F2FE)]` (cyan-blue)
- Crypto:         `[Color(0xFFFA709A), Color(0xFFFEE140)]` (pink-yellow)
- Physical Assets:`[Color(0xFF43E97B), Color(0xFF38F9D7)]` (green-teal)
- Schulden:       `[Color(0xFFFF6B6B), Color(0xFFEE0979)]` (red-pink)

### Typography
```dart
// Use Google Fonts: Inter or DM Sans
headlineLarge:  28sp, FontWeight.w700
headlineMedium: 22sp, FontWeight.w600
titleLarge:     18sp, FontWeight.w600
titleMedium:    16sp, FontWeight.w500
bodyLarge:      15sp, FontWeight.w400
bodyMedium:     13sp, FontWeight.w400
labelSmall:     11sp, FontWeight.w500, letter-spacing: 0.5
```

### Spacing & Shape
- Border radius: 16dp for cards, 12dp for chips, 24dp for bottom sheets
- Card padding: 20dp
- Section spacing: 24dp
- Bottom nav height: 64dp
- FAB: rounded rectangle style

### Key UI Patterns
- **Glassmorphism** for the hero net worth card (light blur + semi-transparent)
- **Gradient cards** for each category (inspired by reference image)
- **Swipe-to-delete** on list items with red background
- **Hero animations** when navigating from dashboard card to detail screen
- **Shimmer loading** placeholders while Firestore data loads
- **Pull-to-refresh** on all list screens
- **Haptic feedback** on important actions (add, delete, confirm)
- Numbers animate/count-up on home screen load (flutter_animate)

---

## 8. Folder Structure

```
lib/
├── main.dart
├── firebase_options.dart          // generated by flutterfire configure
├── app.dart                       // MaterialApp + ThemeData + GoRouter
├── core/
│   ├── theme/
│   │   ├── app_theme.dart         // dark + light ThemeData
│   │   ├── app_colors.dart
│   │   └── app_text_styles.dart
│   ├── router/
│   │   └── app_router.dart        // go_router configuration
│   ├── utils/
│   │   ├── currency_formatter.dart
│   │   ├── date_formatter.dart
│   │   └── number_utils.dart
│   └── constants/
│       └── app_constants.dart
├── features/
│   ├── auth/
│   │   ├── data/auth_repository.dart
│   │   ├── providers/auth_providers.dart
│   │   └── screens/login_screen.dart
│   ├── home/
│   │   ├── providers/home_providers.dart
│   │   ├── screens/home_screen.dart
│   │   └── widgets/
│   │       ├── net_worth_hero.dart
│   │       ├── category_card.dart
│   │       ├── mini_chart.dart
│   │       └── upcoming_maturity_banner.dart
│   ├── giro/
│   │   ├── data/giro_repository.dart
│   │   ├── models/giro_account.dart
│   │   ├── providers/giro_providers.dart
│   │   ├── screens/giro_screen.dart
│   │   └── widgets/giro_account_card.dart
│   ├── festgeld/
│   │   ├── data/festgeld_repository.dart
│   │   ├── models/festgeld.dart
│   │   ├── providers/festgeld_providers.dart
│   │   ├── screens/festgeld_screen.dart
│   │   └── widgets/
│   │       ├── festgeld_card.dart
│   │       └── add_festgeld_sheet.dart
│   ├── etf_stocks/
│   │   ├── data/etf_repository.dart
│   │   ├── models/etf_position.dart
│   │   ├── providers/etf_providers.dart
│   │   ├── screens/etf_screen.dart
│   │   └── widgets/
│   │       ├── position_card.dart
│   │       └── add_position_sheet.dart
│   ├── crypto/
│   │   ├── data/crypto_repository.dart
│   │   ├── models/crypto_position.dart
│   │   ├── providers/crypto_providers.dart
│   │   ├── screens/crypto_screen.dart
│   │   └── widgets/
│   │       ├── crypto_card.dart
│   │       └── add_crypto_sheet.dart
│   ├── physical_assets/
│   │   ├── data/assets_repository.dart
│   │   ├── models/physical_asset.dart
│   │   ├── providers/assets_providers.dart
│   │   ├── screens/assets_screen.dart
│   │   └── widgets/asset_card.dart
│   ├── schulden/
│   │   ├── data/schulden_repository.dart
│   │   ├── models/schuld.dart
│   │   ├── providers/schulden_providers.dart
│   │   ├── screens/schulden_screen.dart
│   │   └── widgets/schuld_card.dart
│   ├── investments/
│   │   └── screens/investments_screen.dart  // TabBar combining festgeld/etf/crypto/assets
│   └── settings/
│       ├── providers/settings_providers.dart
│       └── screens/settings_screen.dart
└── shared/
    ├── widgets/
    │   ├── gradient_card.dart         // reusable gradient container
    │   ├── app_bottom_nav.dart
    │   ├── loading_shimmer.dart
    │   ├── confirm_dialog.dart
    │   ├── add_edit_bottom_sheet.dart // base sheet template
    │   ├── currency_input_field.dart  // formatted number input
    │   └── pnl_chip.dart             // green/red P&L badge
    └── services/
        └── notification_service.dart  // flutter_local_notifications setup + scheduling
```

---

## 9. Authentication Flow

1. App launches → check `FirebaseAuth.instance.currentUser`
2. **Not logged in** → show `LoginScreen`
   - Full-screen gradient background
   - App logo + tagline "Dein Vermögen. Auf einen Blick."
   - "Mit Google anmelden" button (Google Sign-In button with branded style)
3. **Logged in** → go to `HomeScreen`
4. Logout → `FirebaseAuth.instance.signOut()` + `GoogleSignIn().signOut()` → back to LoginScreen
5. Auth state managed via Riverpod `StreamProvider` watching `FirebaseAuth.instance.authStateChanges()`

---

## 10. Calculations

### Net Worth Formula
```
totalNetWorth =
  sum(giro.balance) +
  sum(festgeld.amount) +                  // use deposited amount (not projected)
  sum(etf.shares * etf.currentPrice) +
  sum(crypto.amount * crypto.currentPrice) +
  sum(physicalAsset.currentValue) -
  sum(schulden WHERE type=="I_OWE".amount) +
  sum(schulden WHERE type=="OWED_TO_ME".amount)
```

### P&L for ETF/Stocks
```
totalBuyValue = shares * buyPrice
totalCurrentValue = shares * currentPrice
pnlAbsolute = totalCurrentValue - totalBuyValue
pnlPercent = (pnlAbsolute / totalBuyValue) * 100
```

### Festgeld Projected Payout
```
projectedPayout = amount + (amount * (interestRate/100) * (durationMonths/12))
```

### Festgeld Progress
```
elapsed = DateTime.now().difference(startDate).inDays
total = endDate.difference(startDate).inDays
progress = elapsed / total  // 0.0 to 1.0
```

---

## 11. Notification Service

```dart
// notification_service.dart
class NotificationService {
  // Initialize on app start
  Future<void> initialize();

  // Call when Festgeld is created or updated
  Future<void> scheduleFestgeldNotifications(Festgeld festgeld);

  // Call when Festgeld is deleted
  Future<void> cancelFestgeldNotifications(String festgeldId);

  // Notification IDs: use hash of festgeldId + days offset
  // e.g. "${festgeldId}_30".hashCode, "${festgeldId}_7".hashCode, etc.

  // Notification channels (Android):
  // Channel ID: "festgeld_maturity"
  // Channel name: "Festgeld Fälligkeiten"
  // Importance: high
}
```

---

## 12. Localization

- **Primary language: German** (all labels, descriptions, button text in German)
- Number format: German locale (1.234,56 €) using `intl` package
- Date format: DD.MM.YYYY
- Currency symbol: € (default, user can change in settings)

### Key German strings
```
"Gesamtvermögen" – Total net worth
"Giro Konto" – Checking account
"Festgeld" – Fixed-term deposit
"ETF & Aktien" – ETF & Stocks
"Krypto" – Crypto
"Physische Assets" – Physical assets
"Schulden" – Debts
"Ich schulde" – I owe
"Mir wird geschuldet" – Owed to me
"Noch X Tage" – X days remaining
"Fällig am" – Due on
"Zinssatz" – Interest rate
"Anlagebetrag" – Deposit amount
"Voraussichtliche Auszahlung" – Projected payout
"Eintrag hinzufügen" – Add entry
"Speichern" – Save
"Abbrechen" – Cancel
"Löschen" – Delete
"Bearbeiten" – Edit
```

---

## 13. Android-Specific Setup

- `android/app/build.gradle`: minSdkVersion 21, targetSdkVersion 34
- `AndroidManifest.xml` permissions:
  - `RECEIVE_BOOT_COMPLETED` (reschedule notifications after reboot)
  - `VIBRATE`
  - `POST_NOTIFICATIONS` (Android 13+)
  - `SCHEDULE_EXACT_ALARM` (for exact notification timing)
- App icon: generate with `flutter_launcher_icons`
- Splash screen: `flutter_native_splash`
- Signing config: document keystore setup for Play Store release

---

## 14. Build & Release

### APK for GitHub Releases
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Play Store
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### GitHub Actions CI (optional)
- Trigger on tag push `v*`
- Build release APK
- Create GitHub Release with APK attached
- `google-github-actions/upload-cloud-storage` for AAB to Play Store (optional)

---

## 15. Implementation Order (for Claude Agent Sessions)

Build in this sequence to ship a working app incrementally:

### Session 1: Project Setup & Auth
1. `flutter create fintrack` with correct package name
2. Add all dependencies to pubspec.yaml
3. `flutterfire configure` – connect to Firebase project
4. Implement dark/light theme with full color system (app_theme.dart, app_colors.dart)
5. Implement go_router with all named routes
6. Build LoginScreen (Google Sign-In)
7. Auth flow with Riverpod StreamProvider
8. Main scaffold with bottom navigation (empty screens)

### Session 2: Home Dashboard
1. Giro + Festgeld data models + Firestore repositories
2. Home screen hero card (net worth)
3. Category cards with gradients
4. Mini net worth chart (fl_chart)
5. Upcoming maturity banner for Festgeld

### Session 3: Giro & Festgeld Features
1. Giro accounts screen (add/edit/delete)
2. Festgeld screen (add/edit/delete with all fields)
3. Notification service + schedule notifications on Festgeld create/edit/delete
4. Festgeld progress bars + countdown

### Session 4: ETF/Stocks & Crypto
1. ETF/Stocks data model + repository + screen
2. Crypto data model + repository + screen
3. P&L calculations + color coding
4. "Update Preis" quick dialog

### Session 5: Physical Assets, Schulden & Settings
1. Physical assets screen
2. Schulden screen (two sections: I owe / owed to me)
3. Settings screen (theme toggle, logout, export JSON)
4. Net worth history snapshots (auto-save on app open)

### Session 6: Polish & Release
1. Animations (flutter_animate count-up, hero transitions)
2. Shimmer loading placeholders
3. Pull-to-refresh everywhere
4. Haptic feedback
5. App icon + splash screen
6. Build release APK + test on device
7. GitHub Release setup

---

## 16. Notes for the Agent

- **Always use Riverpod** (not Provider, not BLoC) for state management
- **Never hardcode Firebase credentials** – use `firebase_options.dart` generated by FlutterFire CLI
- **Firestore realtime streams** – use `StreamProvider` + `.snapshots()` for live data, not one-time `.get()`
- **Bottom sheets** for add/edit forms, not full-screen routes (better UX on mobile)
- **Responsive input fields** – use `currency_input_field.dart` widget that formats numbers as user types (e.g., "1234" → "1.234,00 €")
- **Error handling** – show `SnackBar` for Firestore errors, never crash silently
- **Null safety** – all Dart code must be sound null-safe
- **const constructors** everywhere possible for performance
- **Theme-aware** – never hardcode colors, always use `Theme.of(context).colorScheme`
- **German UI language** throughout (see strings in Section 12)
- The `investments_screen.dart` is just a `TabBarView` that renders the four sub-screens (Festgeld, ETF, Crypto, Assets) – no duplicate code
