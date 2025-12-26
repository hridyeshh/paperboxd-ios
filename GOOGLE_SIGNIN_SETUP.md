# Google Sign-In Setup for iOS

This guide will help you set up Google Sign-In for the PaperBoxd iOS app.

## Prerequisites

1. Google Cloud Console account
2. Xcode project with Swift Package Manager

## Step 1: Add Google Sign-In SDK

1. Open your Xcode project
2. Go to **File** → **Add Package Dependencies**
3. Enter the URL: `https://github.com/google/GoogleSignIn-iOS`
4. Select the latest version and click **Add Package**
5. Add `GoogleSignIn` to your target

## Step 2: Configure Google OAuth in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create a new one)
3. Navigate to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth client ID**
5. If prompted, configure the OAuth consent screen:
   - **User Type**: External (for testing) or Internal (for organization)
   - **App name**: PaperBoxd iOS
   - **User support email**: Your email
   - **Developer contact**: Your email
   - **Scopes**: Add `email` and `profile`

6. Create OAuth client ID:
   - **Application type**: iOS
   - **Name**: PaperBoxd iOS Client
   - **Bundle ID**: Your app's bundle ID (e.g., `com.paperboxd.ios`)
   - Click **Create**

7. **Important**: Copy the **Client ID** - you'll need this in the next step

## Step 3: Configure iOS App

### Option A: Using GoogleService-Info.plist (Recommended)

1. Download `GoogleService-Info.plist` from Firebase Console (if using Firebase) or create it manually
2. Add the file to your Xcode project
3. Ensure it's added to your target
4. The app will automatically read `CLIENT_ID` from this file

### Option B: Using Environment Variable

1. In Xcode, go to your target's **Build Settings**
2. Add `GOOGLE_CLIENT_ID` to your environment variables
3. Or set it in `PaperBoxdApp.swift`:

```swift
GoogleSignInService.shared.configure(clientID: "YOUR_CLIENT_ID_HERE")
```

### Option C: Using Info.plist

1. Open `Info.plist`
2. Add a new key: `GOOGLE_CLIENT_ID` with your Client ID as the value

## Step 4: Update URL Scheme

1. Open `Info.plist`
2. Add a new URL Type:
   - **Identifier**: `GoogleSignIn`
   - **URL Schemes**: Your reversed client ID (e.g., `com.googleusercontent.apps.YOUR_CLIENT_ID`)

Or add this to your `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

## Step 5: Install google-auth-library

First, install the required package:

```bash
npm install google-auth-library
```

## Step 6: Create Backend Endpoint

The backend endpoint has been created at `/app/api/auth/google-mobile/route.ts`. 

**The endpoint:**
- Verifies the Google ID token using `google-auth-library`
- Finds or creates the user in MongoDB
- Returns a JWT token in the same format as `/api/auth/token/login`

**Important Notes:**
- The endpoint uses `GOOGLE_CLIENT_ID` from your environment variables
- For iOS, you can use the same Client ID as your web app, OR create a separate iOS OAuth client
- The endpoint matches your existing user creation logic from the web version

**The endpoint code is already created. Here's what it does:**

```typescript
import { NextRequest, NextResponse } from "next/server";
import { OAuth2Client } from "google-auth-library";
import jwt from "jsonwebtoken";
import connectDB from "@/lib/db/mongodb";
import User from "@/lib/db/models/User";

export const dynamic = "force-dynamic";

const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

export async function POST(req: NextRequest) {
  try {
    await connectDB();

    const { idToken } = await req.json();

    if (!idToken) {
      return NextResponse.json(
        { error: "ID token is required" },
        { status: 400 }
      );
    }

    // Verify the Google ID token
    const ticket = await client.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();
    if (!payload) {
      return NextResponse.json(
        { error: "Invalid ID token" },
        { status: 401 }
      );
    }

    const { email, name, picture } = payload;

    if (!email) {
      return NextResponse.json(
        { error: "Email not provided by Google" },
        { status: 400 }
      );
    }

    // Find or create user
    let user = await User.findOne({ email: email.toLowerCase() });

    if (!user) {
      // Create new user
      const username = email.split("@")[0].replace(/[^a-zA-Z0-9]/g, "");
      let uniqueUsername = username;
      let counter = 1;

      // Ensure username is unique
      while (await User.findOne({ username: uniqueUsername })) {
        uniqueUsername = `${username}${counter}`;
        counter++;
      }

      user = await User.create({
        email: email.toLowerCase(),
        name: name || email.split("@")[0],
        username: uniqueUsername,
        avatar: picture,
        provider: "google",
      });
    } else {
      // Update existing user
      user.name = name || user.name;
      user.avatar = picture || user.avatar;
      user.lastActive = new Date();
      await user.save();
    }

    // Generate JWT token
    const secret = process.env.NEXTAUTH_SECRET || process.env.AUTH_SECRET;
    if (!secret) {
      return NextResponse.json(
        { error: "Authentication configuration error" },
        { status: 500 }
      );
    }

    const token = jwt.sign(
      {
        userId: String(user._id),
        email: user.email,
        username: user.username,
      },
      secret,
      { expiresIn: "30d" }
    );

    return NextResponse.json({
      token,
      user: {
        id: String(user._id),
        email: user.email,
        username: user.username,
        name: user.name,
        image: user.avatar,
      },
    });
  } catch (error) {
    console.error("[Google Mobile Auth] Error:", error);
    return NextResponse.json(
      { error: "Authentication failed" },
      { status: 500 }
    );
  }
}
```

**Install required package:**

```bash
npm install google-auth-library
```

## Step 7: Token Refresh Endpoint

The token refresh endpoint has been created at `/app/api/auth/refresh/route.ts`.

**The endpoint:**
- Verifies the existing JWT token
- Updates the user's last active timestamp
- Returns a new JWT token with a fresh 30-day expiration

**The endpoint code is already created. Here's what it does:**

```typescript
import { NextRequest, NextResponse } from "next/server";
import jwt from "jsonwebtoken";
import connectDB from "@/lib/db/mongodb";
import User from "@/lib/db/models/User";

export const dynamic = "force-dynamic";

export async function POST(req: NextRequest) {
  try {
    await connectDB();

    const { token } = await req.json();

    if (!token) {
      return NextResponse.json(
        { error: "Token is required" },
        { status: 400 }
      );
    }

    const secret = process.env.NEXTAUTH_SECRET || process.env.AUTH_SECRET;
    if (!secret) {
      return NextResponse.json(
        { error: "Authentication configuration error" },
        { status: 500 }
      );
    }

    // Verify and decode the token
    let decoded: any;
    try {
      decoded = jwt.verify(token, secret);
    } catch (error) {
      return NextResponse.json(
        { error: "Invalid or expired token" },
        { status: 401 }
      );
    }

    // Get user
    const user = await User.findById(decoded.userId);
    if (!user) {
      return NextResponse.json(
        { error: "User not found" },
        { status: 404 }
      );
    }

    // Generate new token
    const newToken = jwt.sign(
      {
        userId: String(user._id),
        email: user.email,
        username: user.username,
      },
      secret,
      { expiresIn: "30d" }
    );

    return NextResponse.json({
      token: newToken,
      user: {
        id: String(user._id),
        email: user.email,
        username: user.username,
        name: user.name,
        image: user.avatar,
      },
    });
  } catch (error) {
    console.error("[Token Refresh] Error:", error);
    return NextResponse.json(
      { error: "Token refresh failed" },
      { status: 500 }
    );
  }
}
```

## Testing

1. Build and run your iOS app
2. Tap "Continue with Google" on the login screen
3. You should see the Google Sign-In flow
4. After signing in, you should be authenticated and redirected to the home screen

## Troubleshooting

### "No presenting view controller" error
- Ensure you're calling `handleGoogleSignIn()` from the main thread
- The app must have a root view controller

### "Invalid client ID" error
- Verify your Client ID matches the one in Google Cloud Console
- Check that the URL scheme is correctly configured

### "Redirect URI mismatch" error
- This shouldn't occur with native iOS Sign-In, but if it does, check your OAuth client configuration

### Token refresh not working
- Ensure the `/api/auth/refresh` endpoint is created
- Check that the endpoint returns the same format as `/api/auth/token/login`

