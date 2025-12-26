# Backend Environment Variables Setup

## Required Environment Variables

To support both **Web** and **iOS** Google Sign-In, add these environment variables to your Next.js backend:

### Option 1: Separate Variables (Recommended)

```env
# Web Client ID (for your web app)
GOOGLE_CLIENT_ID_WEB=your-web-client-id.apps.googleusercontent.com

# iOS Client ID (for your iOS app)
GOOGLE_CLIENT_ID_IOS=893085484645-7788sam2d7posge2bcild48duripv8h4.apps.googleusercontent.com

# Fallback (if you want to keep backward compatibility)
GOOGLE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```

### Option 2: Single Variable (iOS Only)

If you only want to use the iOS Client ID for now:

```env
GOOGLE_CLIENT_ID=893085484645-7788sam2d7posge2bcild48duripv8h4.apps.googleusercontent.com
```

## Where to Add These

### Local Development (.env.local)

Create or update `.env.local` in your Next.js project root:

```bash
# .env.local
GOOGLE_CLIENT_ID_WEB=your-web-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_ID_IOS=893085484645-7788sam2d7posge2bcild48duripv8h4.apps.googleusercontent.com
NEXTAUTH_SECRET=your-secret-here
AUTH_SECRET=your-secret-here
```

### Vercel Deployment

1. Go to your Vercel project dashboard
2. Navigate to **Settings** → **Environment Variables**
3. Add the following variables:
   - `GOOGLE_CLIENT_ID_WEB` = `your-web-client-id.apps.googleusercontent.com`
   - `GOOGLE_CLIENT_ID_IOS` = `893085484645-7788sam2d7posge2bcild48duripv8h4.apps.googleusercontent.com`
4. **Important**: Make sure to add them to all environments (Production, Preview, Development)
5. **Redeploy** your application after adding the variables

### Other Hosting Platforms

Add the environment variables through your hosting platform's dashboard or CLI, then restart/redeploy your application.

## Verification

After updating your environment variables:

1. **Restart your local development server** (if running locally)
2. **Redeploy your application** (if on Vercel or another platform)
3. **Test the iOS app** - the Google Sign-In should now work

## Troubleshooting

### Still getting 401 errors?

1. **Verify environment variables are set:**
   ```bash
   # In your Next.js project
   echo $GOOGLE_CLIENT_ID_IOS
   ```

2. **Check the backend logs** - the error message should indicate which client ID is being used

3. **Ensure the iOS Client ID matches** exactly what's in `PaperBoxdApp.swift`:
   - iOS App: `893085484645-7788sam2d7posge2bcild48duripv8h4.apps.googleusercontent.com`
   - Backend: Should accept this same ID

4. **Clear Next.js cache:**
   ```bash
   rm -rf .next
   npm run dev
   ```

