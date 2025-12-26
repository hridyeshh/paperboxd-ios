# Backend Authentication Setup for iOS

This document explains the backend authentication endpoints created for the PaperBoxd iOS app.

## Overview

The iOS app uses **JWT (JSON Web Tokens)** for authentication, stored securely in the iOS Keychain. When a user signs in with Google on iOS, the app receives a Google ID Token, which is then verified by your Next.js backend before issuing a PaperBoxd JWT.

## Endpoints Created

### 1. `/api/auth/google-mobile` (POST)

**Purpose:** Verify Google ID Token from iOS and return PaperBoxd JWT

**Request Body:**
```json
{
  "idToken": "eyJhbGciOiJSUzI1NiIsImtpZCI6Ij..."
}
```

**Response (Success):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "507f1f77bcf86cd799439011",
    "email": "user@example.com",
    "username": "user",
    "name": "John Doe",
    "image": "https://lh3.googleusercontent.com/..."
  }
}
```

**Response (Error):**
```json
{
  "error": "Invalid or expired Google ID token"
}
```

**How it works:**
1. Receives Google ID Token from iOS app
2. Verifies token using `google-auth-library` with `GOOGLE_CLIENT_ID`
3. Extracts user info (email, name, picture) from verified token
4. Finds or creates user in MongoDB:
   - **New user:** Creates account with auto-generated username
   - **Existing user:** Updates last active timestamp
5. Generates PaperBoxd JWT (30-day expiration)
6. Returns token and user data

**Security:**
- Token verification ensures the ID token is legitimate and not tampered with
- Uses the same `GOOGLE_CLIENT_ID` as your web app (or a separate iOS OAuth client)
- JWT is signed with `NEXTAUTH_SECRET` for consistency with web auth

---

### 2. `/api/auth/refresh` (POST)

**Purpose:** Refresh an existing JWT token before it expires

**Request Body:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response (Success):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "507f1f77bcf86cd799439011",
    "email": "user@example.com",
    "username": "user",
    "name": "John Doe",
    "image": "https://..."
  }
}
```

**How it works:**
1. Verifies the existing JWT token
2. Finds user in MongoDB
3. Updates `lastActive` timestamp
4. Generates new JWT with fresh 30-day expiration
5. Returns new token and user data

**When to use:**
- The iOS app's `TokenRefreshService` automatically calls this when a token is within 7 days of expiration
- Can be called manually if needed

---

## Environment Variables Required

Make sure these are set in your `.env.local`:

```bash
# Google OAuth (same as web app, or separate iOS client)
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com

# JWT Secret (same as web app)
NEXTAUTH_SECRET=your-nextauth-secret
# OR
AUTH_SECRET=your-auth-secret
```

---

## Package Dependencies

The following package was installed:

```bash
npm install google-auth-library
```

This package is used to verify Google ID tokens on the server side.

---

## User Creation Logic

When a new user signs in with Google:

1. **Username Generation:**
   - Extracts base username from email (e.g., `john@example.com` → `john`)
   - Removes special characters
   - Ensures uniqueness by appending numbers if needed (`john1`, `john2`, etc.)

2. **User Fields:**
   - `email`: From Google profile
   - `name`: From Google profile (or email prefix as fallback)
   - `username`: Auto-generated (unique)
   - `avatar`: Google profile picture URL
   - `provider`: Set to `"google"`
   - `password`: Random hash (OAuth users never use password login)
   - All other fields initialized to defaults (empty arrays, zero counts, etc.)

3. **Existing Users:**
   - If user already exists (matched by email), updates:
     - `name` (if changed in Google)
     - `avatar` (if not already set)
     - `lastActive` timestamp

---

## Testing the Endpoints

### Test Google Mobile Auth

```bash
# Using curl (replace with actual ID token from iOS)
curl -X POST http://localhost:3000/api/auth/google-mobile \
  -H "Content-Type: application/json" \
  -d '{"idToken": "YOUR_GOOGLE_ID_TOKEN"}'
```

### Test Token Refresh

```bash
# Using curl (replace with actual JWT token)
curl -X POST http://localhost:3000/api/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"token": "YOUR_JWT_TOKEN"}'
```

---

## Integration with iOS App

The iOS app's `APIClient` already has methods to call these endpoints:

- `APIClient.shared.signInWithGoogle(idToken:)` → Calls `/api/auth/google-mobile`
- `APIClient.shared.refreshToken()` → Calls `/api/auth/refresh`

The `TokenRefreshService` automatically refreshes tokens when they're close to expiring.

---

## Security Considerations

1. **Token Verification:** The Google ID token is verified server-side to prevent spoofing
2. **JWT Expiration:** Tokens expire after 30 days, requiring refresh
3. **Keychain Storage:** iOS app stores tokens securely in Keychain (not UserDefaults)
4. **HTTPS Required:** In production, all API calls must use HTTPS
5. **Environment Variables:** Never commit secrets to version control

---

## Troubleshooting

### "Invalid or expired Google ID token" (401 Unauthorized)

**This is the most common issue!** It usually means a **Client ID mismatch** between your iOS app and backend.

**Root Cause:**
- Your iOS app uses an **iOS Client ID** to get tokens from Google
- Your backend is configured with a **Web Client ID** 
- Google rejects the verification because the token audience doesn't match

**Solution: Support Multiple Client IDs**

1. **Update your backend route** - See `BACKEND_GOOGLE_MOBILE_ROUTE.ts` for the updated code that accepts both Web and iOS Client IDs
2. **Set environment variables** - See `BACKEND_ENV_SETUP.md` for detailed instructions
3. **Add both Client IDs to your `.env`:**
   ```env
   GOOGLE_CLIENT_ID_WEB=your-web-client-id.apps.googleusercontent.com
   GOOGLE_CLIENT_ID_IOS=893085484645-7788sam2d7posge2bcild48duripv8h4.apps.googleusercontent.com
   ```
4. **Restart your server** after updating environment variables

**Quick Fix (iOS Only):**
If you only want to support iOS for now, set:
```env
GOOGLE_CLIENT_ID=893085484645-7788sam2d7posge2bcild48duripv8h4.apps.googleusercontent.com
```

### "Invalid or expired Google ID token" (Other Causes)
- Verify `GOOGLE_CLIENT_ID` matches the one used in iOS app
- Check that the ID token hasn't expired (they expire quickly)
- Ensure the token is being sent correctly from iOS

### "Authentication configuration error"
- Check that `NEXTAUTH_SECRET` or `AUTH_SECRET` is set
- Verify `GOOGLE_CLIENT_ID` is set

### "User not found" (refresh endpoint)
- The user may have been deleted from the database
- Check MongoDB connection

### Token refresh returns 404
- Ensure `/api/auth/refresh/route.ts` exists
- Check that the endpoint is accessible

---

## Next Steps

1. ✅ Backend endpoints created
2. ✅ `google-auth-library` installed
3. ✅ Configure Google OAuth Client ID in iOS app
4. ⏳ **Update backend route to support multiple Client IDs** - See `BACKEND_GOOGLE_MOBILE_ROUTE.ts`
5. ⏳ **Configure environment variables** - See `BACKEND_ENV_SETUP.md`
6. ⏳ Test Google Sign-In flow end-to-end

## Important Files

- **`BACKEND_GOOGLE_MOBILE_ROUTE.ts`** - Updated route code that supports both Web and iOS Client IDs
- **`BACKEND_ENV_SETUP.md`** - Detailed instructions for setting up environment variables
5. ⏳ Deploy backend to production (Vercel/your hosting)

---

## Related Files

- **iOS App:**
  - `PaperBoxd/Services/APIClient.swift` - API client with auth methods
  - `PaperBoxd/Services/GoogleSignInService.swift` - Google Sign-In SDK wrapper
  - `PaperBoxd/Services/TokenRefreshService.swift` - Automatic token refresh
  - `PaperBoxd/Services/KeychainHelper.swift` - Secure token storage

- **Backend:**
  - `/app/api/auth/google-mobile/route.ts` - Google ID token verification
  - `/app/api/auth/refresh/route.ts` - Token refresh endpoint
  - `/app/api/auth/token/login/route.ts` - Email/password login (existing)

