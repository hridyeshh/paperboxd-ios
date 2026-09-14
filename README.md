# PaperBoxd for iOS

> *Your reading universe, in your pocket.*

The native SwiftUI client for [PaperBoxd](https://paperboxd.in) — a social book-tracking platform inspired by the simplicity and community spirit of Letterboxd, but built exclusively for books.

**Website:** [paperboxd.in](https://paperboxd.in) · **API:** [api.paperboxd.com](https://api.paperboxd.com) · **Contact:** contact@paperboxd.in

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
- [Ask Jazy](#ask-jazy)
- [Scan & Know](#scan--know)
- [Monthly Wrapped](#monthly-wrapped)
- [Fusion](#fusion)
- [Design System](#design-system)
- [Models](#models)
- [Endpoints Reference](#endpoints-reference)
- [Notifications (App-Wide Events)](#notifications-app-wide-events)
- [Dependencies](#dependencies)
- [Conventions](#conventions)
- [Known Gaps](#known-gaps)
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
| Source files | ~134 Swift files |
| Bundle ID | `com.paperboxd.PaperBoxd` |
| Third-party deps | **none** — no Swift packages, no pods (see [Dependencies](#dependencies)) |

**Design stance:** paper and ink, everywhere. The window still boots dark (`UIWindow.appearance().overrideUserInterfaceStyle = .dark`) so the splash has a dark ground, but every screen a reader actually uses — auth, onboarding, Home, Search, Leaderboard, Profile, Book Detail, Write, Settings, Jazy, Scan, Wrapped — opts into `.preferredColorScheme(.light)` and draws the light brutalist kit from the "brutalist mobile" prototypes in the design-elements repo. The asset catalog carries a light appearance with the same hexes, so anything that falls back to catalog colors resolves to paper too.

---

## Requirements

| Tool | Version |
|---|---|
| Xcode | 16 or newer |
| iOS deployment target | 17.0 |
| Swift | 5.0 toolchain |
| Apple Developer account | required for device builds (signing team is set in the project) |

No CocoaPods, no Carthage, no Swift packages. Clone, open, run — there is nothing to resolve.

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
                              │  4 tabs + floating Pip (Jazy)   │
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
│   ├── Analytics.swift             # Fire-and-forget product events → POST /api/v1/events
│   ├── Endpoints.swift             # Every path the app touches, in one file
│   ├── GoogleOAuth.swift           # Authorization Code + PKCE via ASWebAuthenticationSession
│   └── NetworkMonitor.swift        # NWPathMonitor → @Published isOnline
├── Keychain/
│   └── KeychainManager.swift       # JWT + cached User, Security framework
├── Models/                         # Codable wire models (17 files)
├── Components/                     # Shared UI: PBStyle, buttons, covers, spinner, cropper…
├── Extensions/                     # Color+Hex, String+HTML
├── Features/                       # One folder per feature (see below)
├── Preview/                        # Preview fixtures + a preview-only runtime shim
├── PrivacyInfo.xcprivacy           # App Store privacy manifest
├── PaperBoxd.entitlements          # applinks:paperboxd.in (Fusion universal links)
└── Assets.xcassets/                # Colorsets (dark + light appearances), app icon, Google logo
```

### Features

| Folder | Contents |
|---|---|
| `Auth/` | `AuthContainerView`, `LoginView`, `RegisterView`, `OTPView`, `AuthViewModel`, `PaperFields`, `LegalSheetView`, `LegalText` |
| `Author/` | `AuthorDetailView` — portrait, Wikipedia blurb, and the books PaperBoxd holds by them |
| `BookDetail/` | `BookDetailView` + VM, `BookActionButton`, `PageProgressView`, `RateReviewSheet`, `BrutalKit` (light-mode token kit) |
| `Diary/` | `DiaryView`, `DiaryEntryDetailView`, `DiaryViewModel` |
| `Fusion/` | `FusionRootView`, `FusionPlayerView`, `FusionChapters`, `FusionKit`, `FusionsSection` — see [Fusion](#fusion) |
| `Home/` | `HomeView` + VM, `MasonryGridView`, `BookCardView`, `FriendActivityPopup`, `NotificationsView` |
| `Jazy/` | `JazyView`, `JazyResultsDeck`, `JazyService`, `JazyTasteGate` — see [Ask Jazy](#ask-jazy) |
| `Leaderboard/` | `LeaderboardView` + VM (global / friends / per-dimension) |
| `Onboarding/` | `OnboardingContainerView`, `OnboardingSteps`, `OnboardingAhaViews`, VM |
| `Moderation/` | `ModerationService` — report content, block / unblock readers |
| `Profile/` | `ProfileView` + VM, `ProfileHeaderView`, `ProfileGridView`, `ProfileDockView`, `ProfileTabMarks`, `ProfileLevelSheet`, `FollowListView`, `ListDetailView`, `EditProfileView`, `ReadingHeatmapView`, `ShareProfileSheet` |
| `Scan/` | The Scan & Know flow — 16 files, see [below](#scan--know) |
| `Search/` | `SearchView` + VM, `BookSearchResultRow`, `UserSearchResultRow` |
| `Settings/` | `SettingsView`, `DeleteAccountSheet`, `GoodreadsImportView` |
| `Share/` | `BookShareCardView`, `BookShareSheet`, `ShareService` |
| `Splash/` | `SplashView`, `SplashVideoView` + bundled `splash.mp4` |
| `Wrapped/` | `WrappedView` + VM, `WrappedChapters`, `WrappedKit`, `WrappedEntryCard` — see [Monthly Wrapped](#monthly-wrapped) |
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
5. **Hold the splash** for a minimum of 4.6 seconds — long enough for the bundled splash clip (4.87 s source played at 1.25×) plus its outro fade, and so a warm start doesn't flash three screens in 200 ms.

`AppState` also owns `fusionRoute`: `handleIncomingURL` turns a `https://paperboxd.in/fusion/<token>` universal link or a `paperboxd://fusion/<token>` URL into a route, and `MainTabView` presents `FusionRootView` as a full-screen cover over the tabs. A link opened while signed out waits in `UserDefaults` until sign-in.

Every time the scene becomes active, `AppState.recordDailyOpen()` posts `/api/v1/users/me/daily-open`. Streaks count **activity days**, so opening the app is enough to keep one alive.

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

- `PipScanButton` — bottom-trailing, offset 18/84, slides away with the dock. It opens **Ask Jazy** as a `fullScreenCover`; the barcode scanner rises from inside Jazy on the camera tap.
- `CelebrationOverlayView` — full-screen takeovers for shelving a book, extending a streak, or levelling up.

**Hiding the dock:** any descendant view can set `HideDockPreferenceKey` to `true`; `MainTabView` reads it via `.onPreferenceChange` and springs the dock and Pip off-screen. This is how full-bleed detail screens get the whole viewport without prop-drilling a binding.

**Every tab is light-mode.** Search, Leaderboard and the Profile tab each apply both `.environment(\.colorScheme, .light)` and `.preferredColorScheme(.light)`; Home draws its own paper palette. Both are needed — the environment value fixes the subtree, the preference fixes the system chrome around it.

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
Light-mode brutalist wall, top to bottom:

- **Greeting** — the server's time-of-day line in the reader's zone ("Good evening, maya"), falling back to "Hello".
- **Currently reading** hero, linking to Book Detail where `PageProgressView` logs today's pages.
- **"Between covers."** — what your friends are doing; tapping a card opens `FriendActivityPopup`, which fetches the cover and rating on open and shows the activity's title while it loads. **"What readers are into."** from `/api/v1/community` takes its place when your friends have no activity.
- **Feed modules** from `GET /api/v1/recommendations/feed?tz=<device zone>` — server-titled (*Because you loved X*, *Your people are reading*, *You probably haven't discovered this*…) with a short client eyebrow per `kind`. If the feed fails, the legacy rails render untouched.
- **For you** — recommendation cards with the reason line and a confidence tier. Long-press for a `.contextMenu` verdict (*Love it · Maybe · Not for me · Already read · Not now*) posted to `/api/v1/recommendations/feedback`. Reason chips stay on web.
- **Discovery shelves** — *Trending on Paperboxd*, *Picking up speed*, *Going onto TBRs*, *New on the shelves* — all from real shelf data.

Every legacy rail is deduped against the feed modules (`usedIDs`), so a book never appears twice. Recommendation cards emit `rec_impression` with `reason_type`.

### Search
Debounced book search (backend-first, ~10–50 ms from PostgreSQL, falling back to Google Books) plus user search, in one screen with two result-row types.

### Book Detail
Cover, metadata, and the action row: shelve / like / rate / review / track progress. Below the fold: **social proof** from `/api/v1/books/{id}/social` (Paperboxd readers, friends who read it, lists it's on), **friends reading**, **friends' reviews**, all reviews, and similar books from the recommendation engine. The author name pushes `AuthorDetailView`. Rating needs 20 pages read or a finish — the backend refuses an unearned rating. `RateReviewSheet` writes rating and review text through a single `PATCH …/bookshelf/{bookId}`. `PageProgressView` drives `PUT …/bookshelf/{bookId}/progress`.

### Profile
Header with avatar inside an **XP ring** (`XPRingAvatar` — the web's `xpRingGrad` verbatim; tap it for `ProfileLevelSheet` with the total, remainder and bar), banner (wide-crop via the in-house `ImageCropper` — no third-party cropper), stats, and follow button. `ProfileDockView` switches sections with hand-drawn, stroke-trimmed icons (`ProfileTabMarks` — SF Symbols are glyphs with no path to trim). Section grids for Bookshelf, Favorites, TBR, Likes, DNF, Authors, Lists (`ListDetailView`), and Diary. Your own profile carries the **Monthly Wrapped** entry card and the **Fusions** section (`FusionsSection` — your Fusions, Create, Invite with the share link); someone else's offers Report and Block. Reviews on Book Detail can be reported too. Following a private account sends a request. A **reading heatmap** (`ReadingHeatmapView`) renders a year of `…/reading/activity?year=`. Edit Profile broadcasts `.paperboxdAvatarUpdated` on save so the dock avatar and cached user stay in sync.

### Diary
Entry list and detail, with likes. `WriteView` composes an entry: pick a book, pick a date, set a rating, write. Creation and deletion broadcast `.diaryEntryCreated` / `.diaryEntryDeleted` so open lists refresh without polling.

### Leaderboard
Global, friends-only, and per-dimension boards, plus the viewer's own stats from `/api/v1/users/me/leaderboard-stats`.

### Onboarding
Multi-step flow after registration: claim a username (live availability check) → pick genres → **books you love** → **readers to follow** (`/api/v1/users/suggested`, each with a reason) → an "aha" loading stage and reveal that fetch the first real recommendations before handing off to the main app. Each step emits an event (`onboarding_started`, `book_selected_during_onboarding`, `person_followed_during_onboarding`, `onboarding_completed`).

### Settings
Presented as a sheet from the profile header gear, in sections: **Privacy** (private account toggle via `PATCH /api/v1/users/me/visibility`, plus pending follow requests with Confirm / Decline), **Account** (change password — reset by email, never in-app), **Scan & Know** (free scans remaining), **Your Data** (Goodreads import), **Discover** (invite friends, rate PaperBoxd), **About** (privacy policy, terms, version), then sign out and account deletion (`DELETE /api/v1/users/me`, soft-delete, behind a confirmation sheet).

### Goodreads import
Parses a Goodreads CSV export entirely on-device: for each row, look the book up by ISBN first, then title + author, then add the match to the shelf with the mapped status. Star ratings are intentionally **not** imported — the mobile progress endpoint tracks pages, not ratings, so shelf placement is the honest working subset. (Export via goodreads.com/review/import → "Export Library".)

### Share
`BookShareCardView` renders a designed share card — cover, title, author, a status pill (`Just finished` / `Now reading` / `Want to read` / `Favourite of 2026`), and PaperBoxd branding — which `ShareService` hands to the system share sheet as an image. `ShareProfileSheet` does the same for a profile, with a QR code to the public URL.

---

## Ask Jazy

The Pip button's destination: describe a feeling, get a deck of books. `JazyView` runs the same four beats as the Scan flow so the two read as one feature, drawn as a shelf:

```
01 raw       shelf label   write a feeling on a label; preset tabs: cosy · wreck me · found family · gothic
02 machine   pulling       the shelf runs past while POST /api/v1/jazy works
03 hinge     the pull      one spine turns face-out
04 calm      the match     JazyResultsDeck — whitespace, hairlines, serif
```

**Jazy can ask back.** `JazyService.ask()` posts the query with a session id. The response is either a `jazy#question` — one clarifying question with tappable options, drawn as `pendingQuestion` — or a `jazy#deck`. Answering sends the same session, so the backend folds the answer into the ask. Follow-ups like *"shorter"* refine rather than restart: the deck header quotes the accumulated ask the server `understood`, and Jazy's `intro` line sits on the first card.

Each card shows a `% match` and a reason, plus one honest `matchCaveat` about what might not land. Logged-out calls carry an `AnonID` so the session still works.

**The camera lives here.** Scan & Know opens from Jazy's camera tap — gated by `JazyTasteGate`: under five books (shelf + TBR) the camera asks for a few books first, because a compatibility score against an empty shelf is a random number wearing a confident face. The gate fails **open** if the shelf count can't be fetched — a network hiccup is not a reason to take a feature away.

---

## Scan & Know

Point the camera at a book's barcode; get a personalized 0–100 compatibility score.

**Flow** (`ScanFlowView`, opened from Ask Jazy's camera tap):

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

**Quota.** Scans are limited. The remaining count is persisted in `@AppStorage("pb_scans_remaining")` (default 7) after each scan and shown in Settings and on the reveal and breakdown screens (`ScansRemainingFooter`). The endpoint's only 403 is `scans_exhausted`, which drives a dedicated exhausted layout rather than a generic error. The backend reserves a scan before calling Claude and refunds it on failure, so "your scan hasn't been used" is enforced server-side. The app emits `scan_started` the moment the camera hands over an ISBN; success and failure are recorded by the backend.

`NetworkMonitor` is checked before the camera opens, so an offline reader gets told immediately instead of after a failed analyze.

---

## Monthly Wrapped

A fourteen-chapter story player, ported from the design repo's *Monthly Wrapped.html*. The prototype previewed the story inside phone mockups; here the story *is* the screen.

- **Data:** one call, `GET /api/v1/users/me/wrapped?month=YYYY-MM&tz=<zone>` — totals, books, authors, genres, rhythm, streak, top-rated, the book that stalled, rank, a reader archetype, and a dare for next month. Reading time is labelled an estimate because it's derived from pages, not a timer.
- **Player:** stories-style — chapters auto-advance on a timer, tap either side to step, press and hold to pause, and a share sheet exports the recap. VoiceOver gets next / previous / pause actions. Chapters are drawn on the 402 pt design grid and scaled to the device, while the chrome around them stays at true size so tap targets and safe-area insets don't scale with it.
- **Entry:** `WrappedEntryCard` on your own profile. `has_data: false` shows an empty state rather than a story about nothing.

---

## Fusion

Two readers' shelves side by side, from a one-time link. You create a Fusion on your profile, send the link to one person; when they open it and tap **Fuse**, a ten-page story is built from both profiles and each reader sees it from their own side.

```
Profile → Create a Fusion → Invite (share link)          them: link → web join page → app → Fuse
       ← "X fused with you" (Updates sheet)             → Analyzing → Story → Explore
       → Play your Fusion
```

- **Pages** (`FusionChapters`, on the same 402 pt grid the Wrapped player scales): Score · Numbers · Both loved · Agree · Split · Their shelf · Your shelf · The pick · Wildcard · Verdict. A page the two shelves can't fill honestly is **skipped, not shown empty** — the server sends empty arrays and the player drops them. `low_data` gets its own page.
- **`FusionRootView`** routes on the link's state — join, analyzing, "they joined", story, or `own` / `used` / `expired` / `unavailable`. `FusionKit` is a Swiss-style kit over the Wrapped motion primitives; `FusionPlayerView` adds Explore and a share card.
- **Links:** the `applinks:paperboxd.in` entitlement (served from the web repo's `apple-app-site-association`) plus a `paperboxd://` scheme for the join page's "Open in the app" button.
- **Notifications:** tapping a `fusion_joined` update opens the Fusion with the "X fused with you" intro. No push — the inviter learns from the Updates sheet.
- **Known fix, worth keeping:** reading the window's safe-area insets inside the player's body caused an AttributeGraph cycle that froze page 1. Chrome now lives in an `.overlay` and uses layout safe areas.

---

## Design System

Colors live in the asset catalog with **two appearances**. The light values are the ones readers see — every screen forces light — and they match the brutalist kit hex for hex, so a view that falls back to the catalog lands on paper, not charcoal.

| Token | Light (shipped) | Dark (splash ground) | Role |
|---|---|---|---|
| `Background` | `#F2EDE1` paper | `#0A0A0A` | App background |
| `Surface` | `#FDFBF6` card | `#141414` | Cards, elevated surfaces |
| `Border` | `#E6DFD0` | `#2A2A2A` | Hairlines, dividers |
| `TextPrimary` | `#151513` ink | `#F5F5F5` | Body and headings |
| `TextSecondary` | `#6A6456` muted | `#A0A0A0` | Muted / eyebrow text |
| `Accent` | `#D23B26` | `#E8D5B7` | Progress fills, marks |
| `Error` | — | `#E05252` | Destructive (kit uses `crimson` `#C0271C` on paper) |

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

`Eyebrow` (mono, uppercased, 2.0 tracking), `SectionHeader` (eyebrow + serif title + optional trailing action), `SeeAllButton`, `PillButton` (primary / ghost / brutalPrimary / brutalGhost), `BookCoverView`, `BookCoverColumns`, `BookShelfHero` (the auth screens' shelf of cloth-and-foil spines, with the occasional leaner), `AvatarView`, `PBSpinner`, `BrutalistRefresh`, `CurrentlyReadingCard`, `HorizontalCarouselView`, `SignalPillView`, `CelebrationOverlay`, `ImageCropper`, `ImagePicker`.

**`BrutalKit.BK`** is the shared light kit — paper `#F2EDE1`, card `#FDFBF6`, ink `#151513`, muted `#6A6456`, accent `#D23B26`, plus `crimson` (primary CTA), `ochre`, `forest`, `cream`, `field` (input wells), `sepia`, `sage` and `plank` (shelf boards) — mirroring `Home - Brutalist Mobile.html` from the design repo. Scan and Jazy share `ScanKit` (`SK`); Wrapped has `WrappedKit`. The Android app's `Color.kt` carries the same hexes.

---

## Models

| File | Represents |
|---|---|
| `User.swift` | Auth user — id, username, email, avatarURL, level, xp, onboardingCompleted |
| `UserProfile.swift` | Full public profile — bio, stats, pronouns, links |
| `Book.swift` | Book metadata — title, authors, cover, isbn, genres, pages |
| `BookDetailExtras.swift` | Friends reading, reviews |
| `BookshelfAction.swift` | Add / remove / update shelf status |
| `Community.swift` | Public community snapshot — trending, activity, lists, readers |
| `CurrentlyReading.swift` | Progress — current page, percentage |
| `DiaryEntry.swift` | Diary entry — content, book ref, date, likes |
| `ReadingList.swift` | List — id, title, books, privacy |
| `ReaderProgress.swift` | XP standing for the avatar ring and level sheet — level and name from the server, thresholds mirroring the backend's `CalculateLevel` |
| `ReadingActivity.swift` | Per-day reading counts (heatmap) |
| `Activity.swift` | Activity-feed event |
| `Leaderboard.swift` | Leaderboard entry — rank, user, score |
| `Onboarding.swift` | Genres, preferences |
| `Recommendation.swift` | Recommended book + reason, `reason_type`, confidence tier; `FeedModule` / `FeedResponse` |
| `Wrapped.swift` | The monthly Wrapped payload |
| `Fusion.swift` | Fusion invite preview, list, and the ten-page story — mirrors the Go JSON; `PreviewData.fusionStory` is decoded from real builder output |

Scan wire types live beside the feature in `Features/Scan/ScanModels.swift`; Jazy's (`VibeMatch`, `ConciergeResponse`) in `Features/Jazy/JazyService.swift`.

---

## Endpoints Reference

Every path the app touches is a constant or a function in `Network/Endpoints.swift` — one file to diff against `MOBILE_API.md` when the backend changes.

| Group | Paths |
|---|---|
| Health | `/api/health` |
| Mobile auth | `/api/mobile/auth/{login,register,otp/send,otp/verify,google,apple,refresh}` |
| Mobile user | `PATCH /api/mobile/users/me`, `DELETE /api/v1/users/me` |
| Onboarding | `/api/v1/users/me/onboarding`, `/api/v1/users/suggested`, `…/avatar/upload`, `…/banner/upload`, `/api/v1/auth/check-username` |
| App open | `POST /api/v1/users/me/daily-open` |
| Books | `/api/v1/books/{id}`, `/search`, `/public`, `/latest`, `/random`, `/by-author`, `…/like`, `…/social`, `…/reviews`, `…/reviews/friends`, `…/friends-reading` |
| Authors | `/api/v1/authors/info` |
| Bookshelf | `/api/v1/users/{u}/bookshelf` (+ `/{bookId}`, `/status`, `/progress`) |
| Profile | `/api/v1/users/{u}` and `/followers`, `/following`, `/follow`, `/block`, `/favorites`, `/likes`, `/tbr`, `/dnf`, `/authors`, `/streak`, `/lists`, `/lists/{id}`, `/diary`, `/reading`, `/reading/today`, `/reading/last`, `/reading/activity?year=` |
| Privacy & moderation | `PATCH /api/v1/users/me/visibility`, `/api/v1/users/me/follow-requests[/{u}]`, `POST /api/v1/reports` |
| Diary | `…/diary/{entryId}`, `…/diary/{entryId}/like` |
| Activity | `/api/v1/activities/following`, `/api/v1/community` |
| Leaderboard | `/api/v1/leaderboard/{global,friends,dimension/{d}}`, `/api/v1/users/me/leaderboard-stats` |
| Recommendations | `/api/v1/recommendations/home`, `/feed?tz=`, `/similar/{bookId}`, `POST /feedback` |
| Jazy | `POST /api/v1/jazy` |
| Scan | `POST /api/v1/scan/analyze` |
| Wrapped | `/api/v1/users/me/wrapped?month=&tz=` |
| Fusion | `/api/v1/fusions`, `POST\|DELETE\|GET /api/v1/fusions/invites[/{token}]`, `POST …/{token}/accept`, `GET\|DELETE /api/v1/fusions/{id}` |
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
| `ScanGameHUDChanged`, `ScanGameScoreChanged` | The SpriteKit scenes | `ScanGameHost` (score / lives HUD) |

---

## Dependencies

**None.** The project has no Swift package references and no `Package.resolved`. The GoogleSignIn, Kingfisher and Mantis pins left over from early exploration (and GoogleSignIn's six transitive packages) have been removed — none of them was on a shipping code path.

Everything is first-party: `URLSession`, `AsyncImage`, `Security`, `AVFoundation` (scanner, splash clip), `SpriteKit`, `Network`, `AuthenticationServices` (Google PKCE), `CoreImage` (profile QR code). Adding a package is a decision, not a convenience.

---

## Conventions

- **One file, one purpose.** A view and its ViewModel sit side by side in the feature folder.
- **`@MainActor` on ViewModels.** No `DispatchQueue.main.async` anywhere.
- **`private(set)` on published state.** Mutation goes through intent methods, not from the view.
- **Endpoints are never inlined** into a call site — they go in `Endpoints.swift`.
- **Errors reach the reader.** Critical mobile flows (auth, shelving, scan, diary writes) surface the failure in the UI. Best-effort silent `catch` is a bug, not a style choice.
- **Comments explain *why*.** The codebase is dense with rationale comments on non-obvious decisions (the disabled `URLCache`, the 2.5 s splash floor, the baked circular avatar, the absolute forgot-password URL). Keep that up — they are why the next person doesn't re-break it.
- **Previews.** `Preview/PreviewData.swift` and `PreviewRuntime.swift` provide fixtures so feature previews render without a network.
- **Name the Android twin.** Jazy, Wrapped, moderation and the feed all exist on both apps; when a file mirrors a Kotlin counterpart, the doc comment says so.
- **`ponytail:` comments mark deliberate shortcuts** and name their ceiling (Jazy's four preset tabs, the taste gate counting a shelf+TBR book twice).

---

## Known Gaps

What the backend supports and this app doesn't yet — so nobody mistakes an absence for a bug:

| Gap | State |
|---|---|
| **Sign in with Apple** | `AuthViewModel.loginWithApple` and `/api/mobile/auth/apple` exist, but no button is wired and the entitlements file is empty. App Store guideline 4.8 requires a privacy-preserving login option alongside Google sign-in, and this is the planned one — **ship blocker**. |
| **Push notifications** | The backend accepts device tokens; the app never requests permission or registers one, and no sender ships server-side yet. |
| **Taste dashboard** | `GET /api/v1/users/me/taste` is web-only. Mobile needs a new screen. |
| **Recommendation reason chips** | Verdicts only (long-press menu); the per-reason chips that train one axis are web-only. |
| **Feed module subtitles** | Not drawn — the carousel header has no slot for a second line. |

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Stuck on the splash | The 4.6 s floor (splash clip + fade) is intentional. If it never resolves, the health probe is hanging — check `Config.backendURL`. |
| Immediately bounced to login | `/api/mobile/auth/refresh` returned 401. The token expired or `JWT_SECRET` changed on the backend. |
| Google Sign-In fails with `invalid_client` | `Config.googleClientID` doesn't match the bundle ID's OAuth client in Google Cloud. |
| Backend rejects a valid Google token | The client ID isn't in the backend's `GOOGLE_OAUTH_ALLOWED_AUDIENCES`. |
| Stale data after pull-to-refresh | Should be impossible — `urlCache` is nil. If it recurs, check that a new `URLSession` wasn't introduced somewhere with default config. |
| Scan returns 403 | `scans_exhausted` — the free quota is used up. Expected, and has its own layout. |
| Camera tap in Jazy asks for books instead of scanning | `JazyTasteGate` — fewer than five books on shelf + TBR. By design. |
| Home shows only the legacy rails | `/recommendations/feed` failed or returned no modules; the legacy home is the fallback. |
| Wrapped shows an empty state | Nothing was logged that month (`has_data: false`). |
| Fusion link opens Safari, not the app | Universal links need the `apple-app-site-association` on `paperboxd.in` to match the team and bundle — check the web repo's `public/.well-known/`. The `paperboxd://` button on the join page still works. |
| Fusion Agree/Split pages show genres instead of taste axes | Trait backfill hasn't run on the backend — expected until it does. |
| Can't rate a book | Rating needs 20 pages logged or a finish — the backend refuses unearned ratings. |
| Avatar shows as a grey glyph in the tab bar (iOS 26) | The circular bake failed (bad URL or a non-HTTPS URL). `loadCircularAvatar` rewrites `http://` to `https://`; check the stored `avatarURL`. |

---

## Related Repositories

| Repository | Description | Stack |
|---|---|---|
| `paperboxd-backend` | REST API server | Go 1.25, PostgreSQL 16, Redis 7 |
| `paperboxd` | Web frontend | Next.js 15, React 19, TypeScript 5 |
| `paperboxd-android` | Native Android app | Kotlin, Jetpack Compose |
| `analytics-paperboxd` | Internal analytics dashboard | Next.js, Tailwind |
| `Paperboxd design elements` | Design system & UI specs | CSS tokens, HTML prototypes |

---

## Contact

**Email:** contact@paperboxd.in  
**Developer:** Hridyesh · hridyesh@paperboxd.in  
**Website:** [paperboxd.in](https://paperboxd.in)
