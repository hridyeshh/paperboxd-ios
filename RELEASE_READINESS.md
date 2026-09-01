# PaperBoxd for iOS — Release Readiness Report

_Generated 2026-07-23 · branch `phase1-rebuild` · commit `d6564f3`_

> **Verdict:** The app is **feature-complete and shippable in substance.** It is **not yet submittable** — three hard blockers stand between the current build and an App Store Connect upload, and all three are configuration/legal, not code. None require new features. Estimated work to clear them: a few hours, most of it outside Xcode (Google console, a legal decision, exporting one icon).

---

## 1. Snapshot

| | |
|---|---|
| Language / UI | Swift 5 · SwiftUI (100%, no view controllers except system pickers) |
| Min OS | iOS 17.0 |
| Architecture | MVVM + a root state machine (`AppState`) |
| Source | 114 Swift files · ~21,600 LOC · 40 commits |
| Networking | `URLSession` + `async/await`, wrapped in an `actor` |
| Persistence | Keychain (JWT + cached user) · `@AppStorage` for trivial prefs · no local DB |
| Backend | Go on Railway (prod), hit by both Debug and Release |
| Version | Marketing `1.0`, build `1` |
| Signing | Automatic, team `JHJZJSU6SA` set |
| Privacy manifest | Present (`PrivacyInfo.xcprivacy`) with 5 declared data types |
| Automated tests | None |

---

## 2. What is built (and works)

The app is not a skeleton. Every tab and flow is wired end-to-end to the live backend. By feature area:

### Auth & account
- Email + password login/register
- 6-digit email OTP (send + verify)
- Google Sign-In — hand-rolled OAuth Authorization Code + PKCE via `ASWebAuthenticationSession` (no SDK dependency)
- Password reset (posts to the web proxy so Resend sends the email)
- Username availability check
- Delete account (soft-delete) + full delete-account sheet
- Keychain-backed token storage, token refresh endpoint wired

### Onboarding
- Multi-step onboarding + an "aha" moment sequence (`OnboardingAhaViews`)
- Avatar / banner upload during setup
- Bad-cover filtering heuristic so onboarding never shows placeholder covers

### Core reading loop
- **Home** — recommendation feed, masonry grid, trending/latest/random walls, currently-reading card, notifications view
- **Search** — books and users, dedicated result rows
- **Book detail** — shelve/unshelve, rate (1–5), review, reading-progress by page, like, similar books, friends-reading, reviews (all + friends-only)
- **Write / log** — rating picker + review composer with the brutalist post button
- **Diary** — diary list, entry detail, like, delete

### Profile & social
- Profile header, grid, dock, edit profile
- Followers / following lists, follow/unfollow
- Favorites, likes, TBR, DNF, authors, reading lists + list detail
- **Reading heatmap** (GitHub-style activity calendar) + streak
- Share-profile sheet + a rendered share card

### Discovery & play
- **Scan & Know** — barcode scanner → SpriteKit mini-game while the backend scores the book → reveal → score breakdown, with a manual-search fallback and a free-scan quota footer
- **Jazy** — swipe-deck recommendation experience (Tinder-style), extended
- **Leaderboard** — global, friends, per-dimension, plus "my stats"

### Trust & sharing
- **Moderation** — block user, report content
- **Share** — book share card rendered to image, Instagram Stories hand-off
- **Settings** — Goodreads import, legal sheet, delete account, rate-app entry

### Platform plumbing
- Full endpoint catalog in one file (`Network/Endpoints.swift`) — easy to diff against the backend's `MOBILE_API.md`
- Actor-wrapped `APIClient`, typed `APIError`, `NetworkMonitor` for offline state
- App-wide event bus via `NotificationCenter`
- Privacy manifest declares email, name, user ID, photos, and user content — all "linked, not tracking, app-functionality" (accurate)
- Camera + photo-library usage strings present in `Info.plist`
- `ITSAppUsesNonExemptEncryption = false` set (skips the export-compliance prompt)

**Bottom line:** there is no missing feature blocking launch. The product is done.

---

## 3. Blockers — must fix before submission

These will stop an App Store Connect upload or a review. All are necessary. All are quick.

### 🔴 B1 — App icon is empty
`Assets.xcassets/AppIcon.appiconset/` contains only `Contents.json` with **no image files**. App Store Connect rejects any binary without a 1024×1024 marketing icon, and the device home-screen icon would be blank.
- A source icon already exists at `Assets.xcassets/icon.imageset/icon.png` — it just needs to be exported/dropped into the `AppIcon` set (single 1024×1024 slot for iOS 17 is enough).
- **Necessary. ~10 minutes.**

### 🔴 B2 — Bundle ID is inconsistent and probably wrong
The Xcode project ships `PRODUCT_BUNDLE_IDENTIFIER = com.paperboxd.PaperBoxd` (the default template value) in **both** Debug and Release. But everything else in the brand points at **`in.paperboxd.app`**:
- Keychain service = `in.paperboxd.app`
- Google OAuth iOS client was registered against `in.paperboxd.app` (per the setup comment in `Config.swift` / `GoogleOAuth.swift`)
- Domain is `paperboxd.in`

**Why it matters:**
1. The App Store bundle ID is **permanent** once the app record is created — pick wrong and you cannot change it later.
2. A Google iOS OAuth client is bound to a specific bundle ID. If the app ships as `com.paperboxd.PaperBoxd` while the client was issued for `in.paperboxd.app`, **Google Sign-In will fail in production.**

**Decision needed:** lock the real bundle ID (almost certainly `in.paperboxd.app`), set it in the project, and make sure the Google OAuth client matches. If you deliberately keep `com.paperboxd.PaperBoxd`, re-issue the Google client for that ID.
- **Necessary. Verify before creating the App Store record.**

### 🔴 B3 — Legal text still has `[PLACEHOLDER]` blocks, shown in-app
`Features/Auth/LegalText.swift` powers the in-app Terms & Privacy sheet. It still contains unresolved placeholders users would read:
- Governing law / jurisdiction — flagged as a **business + legal decision** (Indian courts vs. arbitration)
- Age gate wording (18+ confirmation at signup)
- Hosting region (Railway Singapore — confirm)
- Legacy MongoDB decommission status
- Billing section (fine for now — no paid features — but the placeholder wording should be cleaned)

App Store review requires a functional privacy policy and terms. Placeholder text in the live legal copy is a rejection risk and a real-world liability.
- **Necessary. The governing-law clause needs a human decision; the rest is cleanup.**

---

## 4. Should-check — recommended, not hard blockers

### 🟡 S1 — Apple Sign-In is scaffolded but not surfaced
The backend endpoint (`/api/mobile/auth/apple`) and `AuthViewModel.loginWithApple(...)` exist, but there is **no Sign-in-with-Apple button, no `ASAuthorizationController`, and the entitlements file is empty.**
- App Store **Guideline 4.8** requires a privacy-preserving login option alongside a social login. **Email + OTP already satisfies this**, so Apple Sign-In is *not strictly mandatory.*
- But the backend already supports it, so finishing it is cheap (a button + the "Sign in with Apple" entitlement) and removes any reviewer ambiguity. **Recommend, don't require.**

### 🟡 S2 — Unused Google SDK dependencies
`Package.resolved` pulls in `GoogleSignIn-iOS`, `AppAuth-iOS`, `GTMAppAuth`, `app-check`, `promises`, etc. — but `GoogleOAuth.swift` is hand-rolled and explicitly needs **no** GoogleSignIn SDK. These are dead weight inflating the binary and the dependency surface. `Kingfisher` (image loading) and `Mantis` (image cropper) **are** used and should stay.
- **Remove the Google SDK packages** unless something else references them. Not a blocker.

### 🟡 S3 — Documentation drift in `README.md`
- Overview claims "Third-party runtime deps: none in the shipping code paths" — but Kingfisher and Mantis are shipped.
- Says "globally forced dark," while `Info.plist` sets `UIUserInterfaceStyle = Light` and other README sections describe a mixed light/dark design. Reconcile the copy.
- Cosmetic only.

### 🟡 S4 — No automated tests
Zero XCTest/Testing targets. For a solo/indie v1 this is an acceptable trade — the flows are exercised manually and the risk of a test-suite-for-its-own-sake is real. Add tests around the money/security-ish paths (auth token refresh, scan quota) only if you keep iterating. **Not required to ship.**

---

## 5. Intentionally-deferred features (safe to ship without)

These surface "coming soon" copy in the UI and are **not** defects — they are deliberately gated:
- **Profile share-card customisation** — "Card customisation coming soon" (`ShareProfileSheet`)
- **Scan paid tier** — "You've used your free scans. More scans coming soon." (free quota works today)
- **`SKStoreReviewController`** — Settings has a `// TODO` to swap in the native review prompt *after* the app has an App Store listing (it cannot work before submission anyway)

None block launch. Skip all of them for v1.

---

## 6. Pre-submission checklist

```
[ ] B1  Export icon.png → AppIcon.appiconset (1024×1024)
[ ] B2  Lock bundle ID (likely in.paperboxd.app); align Google OAuth client to match
[ ] B3  Resolve legal placeholders — governing law (needs a decision), age gate, hosting region
[ ] S1  (optional) Add Sign-in-with-Apple button + entitlement — backend already supports it
[ ] S2  (optional) Drop unused GoogleSignIn/AppAuth SPM packages
[ ] --   Create App Store Connect record, screenshots, description, privacy policy URL
[ ] --   Archive → validate → upload → TestFlight → submit
```

**The code is ready. What's left is packaging, one legal decision, and one identity decision — not engineering.**
