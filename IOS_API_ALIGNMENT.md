# iOS API Alignment with Web Version

This document tracks how the iOS app's API usage aligns with the web version.

## ✅ Home Page - Fully Aligned

### Web Version (Mobile) - `authenticated-home-mobile.tsx`
- Fetches `/api/books/latest?page=1&pageSize=200` (always)
- If authenticated, fetches in parallel:
  - `/api/books/personalized?type=recommended&limit=100`
  - `/api/books/personalized?type=onboarding&limit=100`
  - `/api/books/personalized?type=friends&limit=100`

### iOS Version - `HomeViewModel.swift`
- ✅ Fetches `/api/books/latest?page=1&pageSize=200` (always)
- ✅ If authenticated, fetches in parallel:
  - `/api/books/personalized?type=recommended&limit=100`
  - `/api/books/personalized?type=onboarding&limit=100`
  - `/api/books/personalized?type=friends&limit=100`
- ✅ Combines and deduplicates books (matches web logic)
- ✅ Latest books get priority (matches web logic)

**Status**: ✅ **Fully Aligned**

---

## ✅ Profile Page - Fully Aligned

### Web Version - `app/u/[username]/ClientPage.tsx`
- Uses `/api/users/[username]` to get full profile data
- Returns all books, lists, stats in one response
- Also uses `/api/users/[username]/books?type=...` for paginated collections (optional)

### iOS Version - `ProfileViewModel.swift`
- ✅ Uses `/api/users/[username]` to get full profile data
- ✅ Returns all books, lists, stats in one response
- ✅ Displays: Favorites, Lists, Bookshelf, DNF (matches web tabs)

**Status**: ✅ **Fully Aligned**

---

## ✅ Authentication - Fully Aligned

### Web Version
- Uses NextAuth session cookies (web)
- `/api/auth/google-mobile` for mobile (iOS/Android)

### iOS Version
- ✅ Uses `/api/auth/google-mobile` for Google Sign-In
- ✅ Uses `/api/auth/token/verify` to verify JWT tokens
- ✅ Stores JWT in Keychain
- ✅ Sends `Authorization: Bearer <token>` header

**Status**: ✅ **Fully Aligned**

---

## API Endpoints Currently Used in iOS

### Authentication
- ✅ `POST /api/auth/google-mobile` - Google Sign-In
- ✅ `GET /api/auth/token/verify` - Verify JWT token

### Books
- ✅ `GET /api/books/latest` - Latest books (with pagination)
- ✅ `GET /api/books/personalized` - Personalized recommendations
- ✅ `GET /api/books/sphere` - Sphere visualization books

### Users
- ✅ `GET /api/users/[username]` - User profile data

---

## API Endpoints Available for Future Use

These endpoints exist in the web version but aren't needed yet for iOS:

### Books
- `GET /api/books/search` - Book search (for future search feature)

### Users
- `GET /api/users/[username]/books` - Paginated book collections by type
- `GET /api/users/[username]/lists` - User's reading lists
- `GET /api/users/[username]/lists/[listId]` - Specific reading list
- `GET /api/users/[username]/diary` - User's diary entries
- `POST /api/users/[username]/books` - Add book to collection
- `PATCH /api/users/[username]` - Update profile

### Other
- `GET /api/onboarding/status` - Check onboarding status
- `POST /api/onboarding` - Submit onboarding questionnaire

---

## Notes

1. **No Web Codebase Changes**: All alignment is done in iOS code only
2. **API Compatibility**: iOS uses the same endpoints as web, ensuring consistency
3. **Future Features**: Additional endpoints are available when needed
4. **Error Handling**: iOS handles errors gracefully, matching web patterns

