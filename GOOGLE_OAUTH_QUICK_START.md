# Google OAuth Quick Start Guide

## Current Step: Fill Out Google Cloud Console Form

### In the Google Cloud Console form you're seeing:

1. **Application type**: ✅ Already set to "iOS" (correct)

2. **Name**: ✅ Already set to "PaperBoxd" (you can keep this or change to "PaperBoxd iOS")

3. **Bundle ID** ⚠️ **REQUIRED**: 
   ```
   com.paperboxd.PaperBoxd
   ```
   **Copy and paste this exactly** into the Bundle ID field.

4. **App Store ID**: 
   - Leave this **empty** for now (you'll add it later when you publish to App Store)

5. **Team ID**: 
   - Leave this **empty** for now (optional, only needed for App Store distribution)

6. **Firebase App Check**: 
   - Leave **unchecked** for now (optional feature)

7. Click **"Create"** button

---

## After Creating the OAuth Client:

### Step 2: Copy the Client ID

After clicking "Create", Google will show you a popup with:
- **Client ID**: A long string like `123456789-abcdefghijklmnop.apps.googleusercontent.com`
- **Client secret**: (Not shown for iOS - this is normal)

**⚠️ IMPORTANT**: Copy the **Client ID** immediately - you won't be able to see it again easily!

---

## Step 3: Configure Your iOS App

You have 3 options. **Option A is recommended**:

### Option A: Add Client ID to PaperBoxdApp.swift (Easiest)

1. Open `PaperBoxdApp.swift` in Xcode
2. Find this line:
   ```swift
   GoogleSignInService.shared.configure(clientID: "")
   ```
3. Replace the empty string with your Client ID:
   ```swift
   GoogleSignInService.shared.configure(clientID: "YOUR_CLIENT_ID_HERE")
   ```

### Option B: Create GoogleService-Info.plist

1. Create a new file in Xcode: **File** → **New** → **File** → **Property List**
2. Name it `GoogleService-Info.plist`
3. Add this structure:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>CLIENT_ID</key>
       <string>YOUR_CLIENT_ID_HERE</string>
   </dict>
   </plist>
   ```
4. Replace `YOUR_CLIENT_ID_HERE` with your actual Client ID
5. Add the file to your target

### Option C: Environment Variable

1. In Xcode, select your target
2. Go to **Edit Scheme** → **Run** → **Arguments**
3. Add environment variable:
   - Name: `GOOGLE_CLIENT_ID`
   - Value: Your Client ID

---

## Step 4: Add URL Scheme to Info.plist

1. Open `Info.plist` in Xcode (or find it in your project)
2. Add a new URL Type:
   - Right-click → **Add Row**
   - Key: `URL types` (or `CFBundleURLTypes`)
   - Type: Array
   - Add item:
     - Key: `URL Schemes` (or `CFBundleURLSchemes`)
     - Type: Array
     - Add item: Your reversed Client ID
       - Format: `com.googleusercontent.apps.YOUR_CLIENT_ID_PREFIX`
       - Example: If your Client ID is `123456789-abc.apps.googleusercontent.com`
       - Use: `com.googleusercontent.apps.123456789-abc`

**Or manually edit Info.plist XML:**
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID_PREFIX</string>
        </array>
    </dict>
</array>
```

**To get the prefix**: Take everything before `.apps.googleusercontent.com` from your Client ID.

---

## Step 5: Test Google Sign-In

1. Build and run your app
2. Tap "Continue with Google" on the login screen
3. You should see the Google Sign-In flow
4. After signing in, you should be authenticated

---

## Troubleshooting

### "Custom scheme URIs are not allowed for 'WEB' client type" error
**This is the most common error!** It means you're using a **Web Client ID** instead of an **iOS Client ID**.
- ❌ **Wrong**: Using a Client ID created for "Web application" type
- ✅ **Correct**: You MUST create a new OAuth client with "iOS" application type
- **Solution**: 
  1. Go to Google Cloud Console → APIs & Services → Credentials
  2. Create a NEW OAuth client ID
  3. Select **Application type: iOS** (NOT Web application)
  4. Enter Bundle ID: `com.paperboxd.PaperBoxd`
  5. Copy the new iOS Client ID and use it in your app
  6. Update the URL scheme in Info.plist to match the new Client ID prefix

### "Invalid client ID" error
- Double-check the Client ID is correct
- Ensure URL scheme matches the reversed Client ID format
- Make sure the Bundle ID in Google Console matches your app's Bundle ID exactly
- Verify you're using an iOS Client ID, not a Web Client ID

### "Redirect URI mismatch" error
- This shouldn't happen with native iOS Sign-In
- If it does, check your OAuth client configuration in Google Console

### Sign-In button doesn't work
- Verify Google Sign-In SDK is added to your project
- Check that `PaperBoxdApp.swift` calls `configure()` in `init()`
- Ensure Client ID is set correctly
- Make sure you're using an iOS Client ID, not a Web Client ID

---

## Next Steps After Setup

1. **Create Backend Endpoint**: You'll need to create `/api/auth/google-mobile` in your Next.js backend (see `GOOGLE_SIGNIN_SETUP.md` for code)

2. **Test the Flow**: 
   - Sign in with Google
   - Verify token is saved to Keychain
   - Check that you're redirected to HomeView

3. **Optional**: Add Firebase App Check for additional security

