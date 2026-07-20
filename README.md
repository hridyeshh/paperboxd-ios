# PaperBoxd for iOS

> *Your reading universe, in your pocket.*

The native SwiftUI client for [PaperBoxd](https://paperboxd.in) — a social book-tracking platform inspired by the simplicity and community spirit of Letterboxd, but built exclusively for books.

**Website:** [paperboxd.in](https://paperboxd.in) · **API:** [api.paperboxd.com](https://api.paperboxd.com) · **Contact:** paperboxd@gmail.com

---

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Architecture](#architecture)
- [Project Layout](#project-layout)
- [App State Machine](#app-state-machine)
- [Navigation & The Dock](#navigation--the-dock)
- [Networking Layer](#networking-layer)
- [Error Handling](#error-handling)
- [Authentication & Security](#authentication--security)
- [Features](#features)
- [Scan & Know](#scan--know)
- [Design System](#design-system)
- [Models](#models)
- [Endpoints Reference](#endpoints-reference)
- [Notifications (App-Wide Events)](#notifications-app-wide-events)
- [Dependencies](#dependencies)
- [Conventions](#conventions)
- [Troubleshooting](#troubleshooting)
- [Related Repositories](#related-repositories)

---

## Overview

This is the iOS surface of PaperBoxd. It talks to the Go backend over REST/JSON with a long-lived JWT — no cookies, no session state, no local database. Everything on screen is either fetched live or read from a small encrypted cache (the JWT and the session `User`).

**At a glance:**

| | |
|---|---|
| Language | Swift 5 |
| UI | SwiftUI (100% — no UIKit view controllers except system pickers) |
| Minimum OS | iOS 17.0 |
| Architecture | MVVM + a root state machine |
| Networking | `URLSession` + `async/await`, wrapped in an `actor` |
| Persistence | Keychain (JWT + cached user), `@AppStorage` for trivial prefs |
| Source files | ~109 Swift files |
| Bundle ID | `com.paperboxd.PaperBoxd` |
| Third-party runtime deps | none in the shipping code paths (see [Dependencies](#dependencies)) |

**Design stance:** the app is globally forced dark (`UIWindow.appearance().overrideUserInterfaceStyle = .dark`) with a small number of deliberately light-mode screens (Home, Book Detail, the Profile tab, the Scan games) that mirror the "brutalist mobile" prototypes in the design-elements repo. Colors on those screens are hardcoded light values rather than asset-catalog colors, because the catalog colorsets are single-appearance dark.

---

## Requirements

| Tool | Version |
|---|---|
| Xcode | 16 or newer |
| iOS deployment target | 17.0 |
| Swift | 5.0 toolchain |
| Apple Developer account | required for device builds (signing team is set in the project) |

No CocoaPods, no Carthage, no `Podfile`. Swift Package Manager resolves everything, and `Package.resolved` is committed.

---

## Getting Started

```bash
git clone git@github.com:hridyeshh/paperboxd-ios.git
cd paperboxd-ios
open PaperBoxd.xcodeproj
```

Then in Xcode: select the **PaperBoxd** scheme → pick a simulator (or your device) → **⌘R**.

### Pointing at a local backend

Both `DEBUG` and `RELEASE` currently hit the Railway production backend. To develop against a local Go server, edit the `#if DEBUG` branch in `PaperBoxd/Config/Config.swift`:

```swift
return URL(string: "http://localhost:8080")!
```

Plaintext HTTP to `localhost` is permitted by App Transport Security by default in the simulator; for a device, add an ATS exception for your Mac's LAN address.

### Google Sign-In

`Config.googleClientID` holds the OAuth 2.0 **iOS client ID** (a public identifier — it is not a secret, and PKCE is what actually protects the flow). To regenerate:

1. [console.cloud.google.com](https://console.cloud.google.com) → Credentials → Create → OAuth 2.0 Client → **iOS**
2. Enter the bundle ID
3. Paste the generated client ID into `Config.swift`

The backend must have this client ID in its `GOOGLE_OAUTH_ALLOWED_AUDIENCES` allowlist, or `/api/mobile/auth/google` will reject the ID token.

No `Info.plist` URL scheme is required — `ASWebAuthenticationSession` handles the redirect internally.

---

## Architecture

```
┌────────────────────────────────────────────────────────────┐
│                      PaperBoxdApp                          │
│              (@StateObject AppState — root)                │
└──────────────────────────┬─────────────────────────────────┘
                           │ switch on AppScreen
        ┌──────────┬───────┴────────┬──────────────┐
        ▼          ▼                ▼              ▼
    SplashView  AuthContainer  OnboardingContainer  MainTabView
                                                        │
                              ┌─────────────────────────┴───────┐
                              │  4 tabs + floating Pip button   │
                              │  Home · Search · Leaders · You  │
                              └─────────────────────────────────┘
                                           │
                              ┌────────────┴─────────────────────┐
                              │   Feature ViewModels             │
                              │   (@MainActor, ObservableObject) │
                              └────────────┬─────────────────────┘
                                           │ async/await
                              ┌────────────▼──────────────┐
                              │   APIClient (actor)       │
                              │   URLSession · Bearer JWT │
                              └────────────┬──────────────┘
                                           │ HTTPS / REST JSON
                              ┌────────────▼──────────────┐
                              │   Go backend (Railway)    │
                              └───────────────────────────┘
```

**Layer rules:**

- Views never call `APIClient` directly for anything non-trivial — a `ViewModel` owns the call, the loading flag, and the error string.
- ViewModels are `@MainActor final class … : ObservableObject`. Published state is `@Published private(set)` where practical.
- `APIClient` is an `actor`, so concurrent requests from multiple ViewModels serialize their access to shared config without locks.
- There is no repository layer. The endpoint constants in `Network/Endpoints.swift` are the seam; ViewModels call `APIClient.shared.request(path: Endpoints.…)` directly. This is deliberate — an extra layer of pass-through protocols would buy nothing while the app has exactly one data source.

---

## Project Layout

```
PaperBoxd/
├── App/
│   ├── PaperBoxdApp.swift          # @main — window setup, root switch
│   ├── AppState.swift              # Root state machine + bootstrap
│   ├── MainTabView.swift           # Tab container, dock, Pip, celebrations
│   └── HideDockPreference.swift    # PreferenceKey that lets a child hide the dock
├── Config/
│   └── Config.swift                # Backend URL, user agent, keychain service, OAuth client ID
├── Network/
│   ├── APIClient.swift             # Actor-isolated HTTP client
│   ├── APIError.swift              # Typed errors + backend envelope decoding
│   ├── Endpoints.swift             # Every path the app touches, in one file
│   ├── GoogleOAuth.swift           # Authorization Code + PKCE via ASWebAuthenticationSession
│   └── NetworkMonitor.swift        # NWPathMonitor → @Published isOnline
├── Keychain/
│   └── KeychainManager.swift       # JWT + cached User, Security framework
├── Models/                         # Codable wire models (13 files)
├── Components/                     # Shared UI: PBStyle, buttons, covers, spinner, cropper…
├── Extensions/                     # Color+Hex, String+HTML
├── Features/                       # One folder per feature (see below)
├── Preview/                        # Preview fixtures + a preview-only runtime shim
└── Assets.xcassets/                # Colorsets, app icon, Google logo
```

### Features

| Folder | Contents |
|---|---|
| `Auth/` | `AuthContainerView`, `LoginView`, `RegisterView`, `OTPView`, `AuthViewModel`, `DarkFields`, `LegalSheetView`, `LegalText` |
| `BookDetail/` | `BookDetailView` + VM, `BookActionButton`, `PageProgressView`, `RateReviewSheet`, `BrutalKit` (light-mode token kit) |
| `Diary/` | `DiaryView`, `DiaryEntryDetailView`, `DiaryViewModel` |
| `Home/` | `HomeView` + VM, `MasonryGridView`, `BookCardView`, `NotificationsView` |
| `Leaderboard/` | `LeaderboardView` + VM (global / friends / per-dimension) |
| `Onboarding/` | `OnboardingContainerView`, `OnboardingSteps`, `OnboardingAhaViews`, VM |
| `Profile/` | `ProfileView` + VM, `ProfileHeaderView`, `ProfileGridView`, `ProfileDockView`, `FollowListView`, `EditProfileView`, `ReadingHeatmapView`, `ShareProfileSheet` |
| `Scan/` | The Scan & Know flow — 15 files, see [below](#scan--know) |
| `Search/` | `SearchView` + VM, `BookSearchResultRow`, `UserSearchResultRow` |
| `Settings/` | `SettingsView`, `DeleteAccountSheet`, `GoodreadsImportView` |
| `Share/` | `BookShareCardView`, `BookShareSheet`, `ShareService` |
| `Splash/` | `SplashView` |
| `Write/` | `WriteView` + VM, `RatingPickerView` |

---

## App State Machine

`AppState` owns the only global navigation decision the app makes.

```swift
enum AppScreen: Equatable {
    case splash                // bootstrap holding state
    case auth                  // login / register / OTP
    case onboarding(User)      // registered, not yet onboarded
    case main(User)            // fully authenticated session
}
```

### Bootstrap flow

`AppState.bootstrap()` runs once on launch:

1. **Read the JWT from the Keychain.** Missing or empty → `.auth`.
2. **Probe `GET /api/health`** (unauthenticated). If the backend is unreachable, *keep* the token — a flaky network is not a logout — and route from the cached `User`. No cached user → `.auth`.
3. **Call `POST /api/mobile/auth/refresh`** with the Bearer token. Success re-mints the token and persists it. Failure clears the keychain and routes to `.auth`.
4. **Route** on the refreshed user: `needsOnboarding(user)` → `.onboarding(user)`, else `.main(user)`.
5. **Hold the splash** for a minimum of 2.5 seconds throughout, so a warm start doesn't flash three screens in 200 ms.

### Onboarding gate

```swift
private func needsOnboarding(_ user: User) -> Bool {
    if let completed = user.onboardingCompleted { return !completed }
    return user.username == nil || user.username?.isEmpty == true
}
```

`onboardingCompleted` is nil for users cached by an older build. Falling back to username presence means existing users never get dropped back into onboarding after an app update.

### Session expiry

Any 401 from anywhere in the app causes `APIClient` to clear the keychain and post `.paperboxdSessionExpired`. `AppState` observes it, nils `currentUser`, and transitions to `.auth`. No screen has to handle logout itself.

---

## Navigation & The Dock

`MainTabView` ships two tab bars and picks at runtime:

| OS | Implementation |
|---|---|
| **iOS 26+** | Native `TabView` with Liquid Glass, `.tabBarMinimizeBehavior(.onScrollDown)`, and a sliding indicator |
| **iOS 17–25** | `CustomDock` — a hand-built glass pill, icon-only, positioned in a `ZStack` |

| Tab | Icon | Screen |
|---|---|---|
| Home | `house` | `HomeView` — masonry wall + activity |
| Search | `magnifyingglass` | `SearchView` — books and users |
| Leaderboard | `trophy` | `LeaderboardView` |
| You | user's avatar, or `person` | `ProfileView` inside a `NavigationStack` |

On the iOS 26 path the avatar is **downloaded and baked into a 30×30 circular `UIImage`** with `.alwaysOriginal` rendering, because the system tab bar would otherwise tint it into a flat glyph. It's rebuilt whenever `.paperboxdAvatarUpdated` fires.

**Floating elements layered above the dock:**

- `PipScanButton` — the Scan & Know entry point, bottom-trailing, offset 18/84. Slides away with the dock.
- `CelebrationOverlayView` — full-screen takeovers for shelving a book, extending a streak, or levelling up.

**Hiding the dock:** any descendant view can set `HideDockPreferenceKey` to `true`; `MainTabView` reads it via `.onPreferenceChange` and springs the dock and Pip off-screen. This is how full-bleed detail screens get the whole viewport without prop-drilling a binding.

**The Profile tab is light-mode only** — it applies both `.environment(\.colorScheme, .light)` and `.preferredColorScheme(.light)` inside the tab.

---

## Networking Layer

`APIClient` is an actor with a single shared instance.

```swift
let profile: UserProfile = try await APIClient.shared.request(
    path: Endpoints.profile(username: "hridyesh"),
    method: .get,
    requiresAuth: true
)
```

**Session configuration:**

| Setting | Value | Why |
|---|---|---|
| `timeoutIntervalForRequest` | 15 s | Fails fast enough to show a retry affordance |
| `waitsForConnectivity` | `true` | Queues rather than instantly failing on a dead radio |
| `requestCachePolicy` | `.reloadIgnoringLocalCacheData` | Pull-to-refresh was serving stale JSON from `URLCache` |
| `urlCache` | `nil` | Same reason — API responses must never be cached |
| Default headers | `Content-Type`, `Accept`, `User-Agent: PaperBoxd-iOS/<version> (iOS)` | The backend uses the UA to separate surfaces in its logs |

**Three entry points:**

| Method | Use |
|---|---|
| `request<Response: Decodable>(path:method:body:requiresAuth:)` | The common case. Pass `Empty` for void responses. |
| `upload<Response>(path:fileData:fileName:mimeType:fieldName:requiresAuth:)` | `multipart/form-data` — avatar and banner upload, which the backend forwards to Cloudinary with a server-side signature. |
| `rawRequest(path:method:body:requiresAuth:)` | Returns `Data` for endpoints with bespoke decoding. |

All three funnel into one private `send(_:)`, so 401 handling and error-envelope parsing live in exactly one place.

**Cancellation is not an error.** A `URLError.cancelled` (typical when a pull-to-refresh gesture ends, or a `.task` is torn down) is re-thrown as `CancellationError` rather than `APIError.transport`, so callers can silently ignore it instead of flashing a bogus banner.

---

## Error Handling

The backend returns:

```json
{ "error": "Human readable message", "code": "SNAKE_CASE_CODE" }
```

`BackendErrorEnvelope` decodes both this flat shape *and* the older nested `{"error": {"code": …, "message": …}}` shape, because both are still in circulation across routes.

`APIError` maps that envelope onto a typed enum:

| Backend code | HTTP | `APIError` case |
|---|---|---|
| `UNAUTHORIZED` / `INVALID_TOKEN` / `EXPIRED_TOKEN` | 401 | `.unauthorized` |
| `FORBIDDEN` | 403 | `.forbidden` |
| `NOT_FOUND` | 404 | `.notFound` |
| `VALIDATION_ERROR` | 400 | `.validation` |
| `RATE_LIMITED` | 429 | `.rateLimited` |
| `INTERNAL_ERROR` | 500 | `.server` |
| — | any | falls back to status-code mapping, then `.unknown` |

Plus three transport-level cases the UI needs to distinguish: `.transport`, `.decoding`, `.invalidResponse`.

**Display-string precedence** (`APIError.displayString`): explicit `message` → friendly copy for a known machine code → the raw `error` string → `"Something went wrong — please try again"`.

Known machine codes get hand-written copy rather than being surfaced raw:

| Code | Shown to the reader |
|---|---|
| `book_not_found` | "Couldn't find this book — try searching by title" |
| `scans_exhausted` | "You've used all your free scans" |
| `scoring_failed` | "Something took too long — your scan hasn't been used" |

Errors are surfaced to the UI, never silently swallowed — this matters most in the scan and bookshelf flows, where a dropped write looks identical to a successful one.

---

## Authentication & Security

| Concern | Implementation |
|---|---|
| Token storage | **Keychain** via `KeychainManager` — `kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlock`. Never `UserDefaults`. |
| Cached user | Also Keychain, JSON-encoded under `auth.user`. |
| Service identifier | `in.paperboxd.app` — stable across builds so tokens survive reinstall-from-Xcode during development. |
| Transport | Pure `Authorization: Bearer <jwt>`. **No cookies are ever written or read.** |
| Token lifetime | 30 days (mobile default). Re-minted on every launch via `/api/mobile/auth/refresh`. |
| 401 handling | Keychain cleared + `.paperboxdSessionExpired` posted. Forced logout, from anywhere. |
| Google Sign-In | OAuth 2.0 **Authorization Code + PKCE** through `ASWebAuthenticationSession` (`Network/GoogleOAuth.swift`). SHA-256 code challenge, random `state`, redirect URI derived from the reversed client ID. No SDK required, no client secret in the app. |

**Auth methods available:** email + password, 6-digit email OTP, Google. Password reset posts to `https://paperboxd.in/api/auth/forgot-password` (an absolute URL, deliberately bypassing `Config.backendURL`) because the Go backend's `/api/v1/auth/forgot-password` only mints the token — the Next.js proxy is what actually sends the email via Resend.

---

## Features

### Home
Light-mode brutalist wall. Masonry book grid (`MasonryGridView`), currently-reading card, activity from people you follow, and a notifications sheet.

### Search
Debounced book search (backend-first, ~10–50 ms from PostgreSQL, falling back to Google Books) plus user search, in one screen with two result-row types.

### Book Detail
Cover, metadata, and the action row: shelve / like / rate / review / track progress. Below the fold: **friends reading**, **friends' reviews**, all reviews, and similar books from the recommendation engine. `RateReviewSheet` writes rating and review text through a single `PATCH …/bookshelf/{bookId}`. `PageProgressView` drives `PUT …/bookshelf/{bookId}/progress`.

### Profile
Header with avatar, banner (wide-crop via the in-house `ImageCropper` — no third-party cropper), stats, and follow button. Section grids for Bookshelf, Favorites, TBR, Likes, DNF, Authors, Lists, and Diary. A **reading heatmap** (`ReadingHeatmapView`) renders a year of `…/reading/activity?year=`. Edit Profile broadcasts `.paperboxdAvatarUpdated` on save so the dock avatar and cached user stay in sync.

### Diary
Entry list and detail, with likes. `WriteView` composes an entry: pick a book, pick a date, set a rating, write. Creation and deletion broadcast `.diaryEntryCreated` / `.diaryEntryDeleted` so open lists refresh without polling.

### Leaderboard
Global, friends-only, and per-dimension boards, plus the viewer's own stats from `/api/v1/users/me/leaderboard-stats`.

### Onboarding
Multi-step flow after registration: claim a username (live availability check), pick genres, upload an avatar, then an "aha" loading stage that fetches the first real recommendations before handing off to the main app.

### Settings
Presented as a sheet from the profile header gear. Free-scan quota, share the app, rate the app, legal (privacy policy / terms), Goodreads import, sign out, and account deletion (`DELETE /api/v1/users/me`, soft-delete, behind a confirmation sheet).

### Goodreads import
Parses a Goodreads CSV export entirely on-device: for each row, look the book up by ISBN first, then title + author, then add the match to the shelf with the mapped status. Star ratings are intentionally **not** imported — the mobile progress endpoint tracks pages, not ratings, so shelf placement is the honest working subset. (Export via goodreads.com/review/import → "Export Library".)

### Share
`BookShareCardView` renders a designed share card — cover, title, author, a status pill (`Just finished` / `Now reading` / `Want to read` / `Favourite of 2026`), and PaperBoxd branding — which `ShareService` hands to the system share sheet as an image. `ShareProfileSheet` does the same for a profile, with a QR code to the public URL.

---

## Scan & Know

Point the camera at a book's barcode; get a personalized 0–100 compatibility score.

**Flow** (`ScanFlowView`, presented as a `fullScreenCover` from the Pip button):

```
scan  →  analyzing  →  reveal  →  breakdown
 │           │            │           │
 │           │            │           └─ 5-axis radar + for-you / against-you
 │           │            └─ count-up animation to the final score
 │           └─ POST /api/v1/scan/analyze runs while you play a game
 └─ BarcodeScannerView (AVFoundation) or ScanManualSearch by title
```

**The scoring is real**, not decorative: `POST /api/v1/scan/analyze` returns the book, a `dimensions` block (genre fit, writing style, length/complexity, community love, personal fit — each out of 20), a verdict, for/against bullets, a one-liner, and the live source counts (readers, ratings, shelf, friends) that the analyzing screen displays as it works.

**The games.** The analyze call takes a few seconds, so the wait is filled with one of three endless SpriteKit scenes — Breakout (`ScanGameScene`), Catch (`ScanCatchScene`), and Stack (`ScanStackScene`). All three are light brutalist: paper canvas, ink paddle, book-spine colors as the only color. They report score and lives to the SwiftUI host through a shared `ScanGameHUDChanged` notification.

**Quota.** Scans are limited. The remaining count is persisted in `@AppStorage("pb_scans_remaining")` (default 7) after each scan and shown in Settings. The endpoint's only 403 is `scans_exhausted`, which drives a dedicated exhausted layout rather than a generic error.

`NetworkMonitor` is checked before the camera opens, so an offline reader gets told immediately instead of after a failed analyze.

---

## Design System

Colors live in the asset catalog as **single-appearance dark** colorsets; the app window is forced dark globally.

| Token | Hex | Role |
|---|---|---|
| `Background` | `#0A0A0A` | App background |
| `Surface` | `#141414` | Cards, elevated surfaces |
| `Border` | `#2A2A2A` | Hairlines, dividers |
| `TextPrimary` | `#F5F5F5` | Body and headings |
| `TextSecondary` | `#A0A0A0` | Muted / eyebrow text |
| `Accent` | `#E8D5B7` | Warm paper accent |
| `Error` | `#E05252` | Destructive |

Inline accents that the catalog doesn't carry live on the `PB` enum in `Components/PBStyle.swift`:

| Token | Hex | Use |
|---|---|---|
| `PB.terracotta` | `#D97757` | Avatar ring gradient (start) |
| `PB.terracottaDeep` | `#6B3520` | Avatar ring gradient (end) |
| `PB.likeRed` | `#D72830` | Active "liked" heart |

### Typography

Display faces in the design system are Typekit-only, so SwiftUI system designs approximate them:

| Design intent | SwiftUI equivalent | Helper |
|---|---|---|
| `cofo-glassier` / Playfair Display headings | `.system(design: .serif)` | `PB.serif(_:_:)` |
| Geist Mono / JetBrains Mono eyebrows + numbers | `.system(design: .monospaced)` | `PB.mono(_:_:)` |
| `brooklyn-heritage-script` wordmark | Snell Roundhand | `PB.wordmark(_:)` |

### Shared components

`Eyebrow` (mono, uppercased, 2.0 tracking), `SectionHeader` (eyebrow + serif title + optional trailing action), `SeeAllButton`, `PillButton` (primary / ghost / brutalPrimary / brutalGhost), `BookCoverView`, `BookCoverColumns`, `AvatarView`, `PBSpinner`, `BrutalistRefresh`, `CurrentlyReadingCard`, `HorizontalCarouselView`, `SignalPillView`, `CelebrationOverlay`.

Light-mode screens use their own local token kits — `BrutalKit.BK` for Book Detail, and inline constants in `HomeView` (paper `#F2EDE1`, card `#FDFBF6`, ink `#151513`, muted `#6A6456`, accent `#D23B26`) — mirroring `Home - Brutalist Mobile.html` from the design repo.

---

## Models

| File | Represents |
|---|---|
| `User.swift` | Auth user — id, username, email, avatarURL, level, xp, onboardingCompleted |
| `UserProfile.swift` | Full public profile — bio, stats, pronouns, links |
| `Book.swift` | Book metadata — title, authors, cover, isbn, genres, pages |
| `BookDetailExtras.swift` | Friends reading, reviews |
| `BookshelfAction.swift` | Add / remove / update shelf status |
| `CurrentlyReading.swift` | Progress — current page, percentage |
| `DiaryEntry.swift` | Diary entry — content, book ref, date, likes |
| `ReadingList.swift` | List — id, title, books, privacy |
| `ReadingActivity.swift` | Per-day reading counts (heatmap) |
| `Activity.swift` | Activity-feed event |
| `Leaderboard.swift` | Leaderboard entry — rank, user, score |
| `Onboarding.swift` | Genres, preferences |
| `Recommendation.swift` | Recommended book + reason |

Scan wire types live beside the feature in `Features/Scan/ScanModels.swift`.

---

## Endpoints Reference

Every path the app touches is a constant or a function in `Network/Endpoints.swift` — one file to diff against `MOBILE_API.md` when the backend changes.

| Group | Paths |
|---|---|
| Health | `/api/health` |
| Mobile auth | `/api/mobile/auth/{login,register,otp/send,otp/verify,google,refresh}` |
| Mobile user | `PATCH /api/mobile/users/me`, `DELETE /api/v1/users/me` |
| Onboarding | `/api/v1/users/me/onboarding`, `…/avatar/upload`, `…/banner/upload`, `/api/v1/auth/check-username` |
| Books | `/api/v1/books/{id}`, `/search`, `/public`, `/latest`, `/random`, `…/like`, `…/reviews`, `…/reviews/friends`, `…/friends-reading` |
| Bookshelf | `/api/v1/users/{u}/bookshelf` (+ `/{bookId}`, `/status`, `/progress`) |
| Profile | `/api/v1/users/{u}` and `/followers`, `/following`, `/follow`, `/favorites`, `/likes`, `/tbr`, `/dnf`, `/authors`, `/streak`, `/lists`, `/diary`, `/reading`, `/reading/today`, `/reading/last`, `/reading/activity?year=` |
| Diary | `…/diary/{entryId}`, `…/diary/{entryId}/like` |
| Activity | `/api/v1/activities/following` |
| Leaderboard | `/api/v1/leaderboard/{global,friends,dimension/{d}}`, `/api/v1/users/me/leaderboard-stats` |
| Recommendations | `/api/v1/recommendations/home`, `/api/v1/recommendations/similar/{bookId}` |
| Scan | `POST /api/v1/scan/analyze` |
| Events | `POST /api/v1/events` |
| Password reset | `https://paperboxd.in/api/auth/forgot-password` (absolute — web proxy) |

Full contract: `MOBILE_API.md` in the backend repo.

---

## Notifications (App-Wide Events)

Cross-cutting state changes travel as `NotificationCenter` posts rather than shared observable objects, so a screen deep in a stack can react without being wired to a parent.

| Name | Posted by | Observed by |
|---|---|---|
| `.paperboxdSessionExpired` | `APIClient` on any 401 | `AppState` → routes to `.auth` |
| `.paperboxdAvatarUpdated` | `EditProfileView` after upload | `AppState` (cache), `MainTabView` (dock avatar) |
| `.diaryEntryCreated` | `WriteViewModel` | Diary and profile lists |
| `.diaryEntryDeleted` | `DiaryEntryDetailView` | Diary and profile lists |
| `ScanGameHUDChanged` | The SpriteKit scenes | `ScanGameHost` (score / lives HUD) |

---

## Dependencies

Resolved by SPM and pinned in `Package.resolved`:

| Package | Version | Status |
|---|---|---|
| [GoogleSignIn-iOS](https://github.com/google/GoogleSignIn-iOS) | 9.0.0 | Pinned, **not used** — sign-in runs through the in-house PKCE flow in `GoogleOAuth.swift` |
| [Kingfisher](https://github.com/onevcat/Kingfisher) | 8.6.2 | Pinned, **not used** — image loading is SwiftUI `AsyncImage` |
| [Mantis](https://github.com/guoyingtao/Mantis) | 1.9.0 | Pinned; banner cropping ships as the in-house `ImageCropper` |
| AppAuth-iOS, GTMAppAuth, GTMSessionFetcher, GoogleUtilities, Promises, app-check | — | Transitive dependencies of GoogleSignIn |

The shipping code paths use first-party APIs throughout — `URLSession`, `AsyncImage`, `Security`, `AVFoundation`, `SpriteKit`, `Network`, `AuthenticationServices`. The pins above are residue from earlier exploration and can be dropped from the project when someone next touches package settings.

---

## Conventions

- **One file, one purpose.** A view and its ViewModel sit side by side in the feature folder.
- **`@MainActor` on ViewModels.** No `DispatchQueue.main.async` anywhere.
- **`private(set)` on published state.** Mutation goes through intent methods, not from the view.
- **Endpoints are never inlined** into a call site — they go in `Endpoints.swift`.
- **Errors reach the reader.** Critical mobile flows (auth, shelving, scan, diary writes) surface the failure in the UI. Best-effort silent `catch` is a bug, not a style choice.
- **Comments explain *why*.** The codebase is dense with rationale comments on non-obvious decisions (the disabled `URLCache`, the 2.5 s splash floor, the baked circular avatar, the absolute forgot-password URL). Keep that up — they are why the next person doesn't re-break it.
- **Previews.** `Preview/PreviewData.swift` and `PreviewRuntime.swift` provide fixtures so feature previews render without a network.

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Stuck on the splash | The 2.5 s floor is intentional. If it never resolves, the health probe is hanging — check `Config.backendURL`. |
| Immediately bounced to login | `/api/mobile/auth/refresh` returned 401. The token expired or `JWT_SECRET` changed on the backend. |
| Google Sign-In fails with `invalid_client` | `Config.googleClientID` doesn't match the bundle ID's OAuth client in Google Cloud. |
| Backend rejects a valid Google token | The client ID isn't in the backend's `GOOGLE_OAUTH_ALLOWED_AUDIENCES`. |
| Stale data after pull-to-refresh | Should be impossible — `urlCache` is nil. If it recurs, check that a new `URLSession` wasn't introduced somewhere with default config. |
| Scan returns 403 | `scans_exhausted` — the free quota is used up. Expected, and has its own layout. |
| Avatar shows as a grey glyph in the tab bar (iOS 26) | The circular bake failed (bad URL or a non-HTTPS URL). `loadCircularAvatar` rewrites `http://` to `https://`; check the stored `avatarURL`. |

---

## Related Repositories

| Repository | Description | Stack |
|---|---|---|
| `paperboxd-backend` | REST API server | Go 1.25, PostgreSQL 16, Redis 7 |
| `paperboxd` | Web frontend | Next.js 15, React 19, TypeScript 5 |
| `paperboxd-android` | Native Android app | Kotlin, Jetpack Compose |
| `Paperboxd design elements` | Design system & UI specs | CSS tokens, HTML prototypes |

---

## Contact

**Developer:** Hridyesh
**Email:** paperboxd@gmail.com
**Website:** [paperboxd.in](https://paperboxd.in)
