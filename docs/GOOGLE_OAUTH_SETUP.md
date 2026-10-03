# Google Sign-In setup for NIGOH Family

## 1. Create OAuth credentials

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project or select the project used by NIGOH Family.
3. Open **Google Auth Platform → Branding** (or **OAuth consent screen** in the older UI).
4. Set the app name to `NIGOH Family`, choose a support email, and add the scopes `openid`, `email`, and `profile`.
5. If the app is in testing mode, add the Google accounts that are allowed to sign in as test users.
6. Open **Google Auth Platform → Clients** (or **Credentials → Create Credentials → OAuth client ID**).
7. Choose **Web application**.
8. Add these authorized JavaScript origins:

   - `https://nigohfamily.qobus.tj`
   - `http://localhost:8000` (local development only)

9. Add these authorized redirect URIs:

   - `https://nigohfamily.qobus.tj/auth/google/callback`
   - `http://localhost:8000/auth/google/callback` (local development only)

10. Copy the generated Client ID and Client Secret. Never commit the secret or put it in frontend JavaScript.

### Android Firebase Google Sign-In certificate

The release APK is signed with a persistent production certificate. In the
Firebase project `nigoh-family`, open **Project settings → Your apps → Android
app → SHA certificate fingerprints** and add both fingerprints from the
release keystore:

- SHA-1: `64:90:65:86:75:86:00:D9:D6:5B:45:5A:94:09:1C:EC:FB:30:3A:7C`
- SHA-256: `D4:D3:E4:FA:C3:D7:0D:6B:4D:88:1B:7F:73:F7:E7:98:CC:F0:4F:10:9F:F6:F8:BB:D0:50:4D:FB:79:DF:08:DF`

The checked-in `google-services.json` currently contains the older Android
fingerprint, so Google Sign-In can fail in the release APK until the new
fingerprints are registered and a fresh `google-services.json` is downloaded
from Firebase and placed at `android/app/google-services.json`. This step
requires Firebase project-owner access; it cannot be safely obtained from a
third-party account.

For the one-tap test login in the mobile app, enable **Authentication → Sign-in
method → Anonymous** in the same Firebase project. Anonymous accounts are
isolated from real family accounts and are intended only for UI/device testing.

## 2. Configure the server

Create `/home/dev/munis/.env` on production, or `.env` in the project root for local development:

```dotenv
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
GOOGLE_REDIRECT_URI=https://nigohfamily.qobus.tj/auth/google/callback
```

Restart Uvicorn after changing the file. The server loads these values at startup. If the credentials are missing, the button shows a clear configuration message and no unverified login is allowed.

## 3. How the flow works

- `GET /auth/google/login` creates a short-lived CSRF state and redirects to Google.
- `GET /auth/google/callback` verifies the state cookie, exchanges the authorization code, and reads the verified Google OpenID user profile.
- The user is matched by email or created as a `parent` in the existing SQLite `users` table.
- A normal NIGOH HttpOnly session cookie is then issued.
- `POST /api/auth/google` remains available for trusted mobile clients, but it now requires a real Google access token and verifies it with Google before creating a session.
