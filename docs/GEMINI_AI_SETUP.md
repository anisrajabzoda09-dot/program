# NIGOH AI / Gemini setup

Gemini is called only by the NIGOH server. The Android app never receives the API key.

## Configure

Add these values to the production server's private `.env` file:

```env
GEMINI_API_KEY=replace-with-a-new-server-key
GEMINI_MODEL=gemini-3.5-flash-lite
GEMINI_TIMEOUT_SECONDS=20
```

Restart the API service after changing `.env`. If the key is missing, AI endpoints return `503`; all parental-control, geofence and reporting features continue to work normally.

## Safety boundaries

- AI produces a preview. A parent must explicitly confirm before any app rule or category is saved.
- Returned package names are checked against the child's currently installed apps.
- Dialer, phone, SMS, Settings, System UI and NIGOH packages cannot be blocked by an AI proposal.
- Rule values, schedules and categories are validated again by the server.
- The weekly summary receives aggregate dates, app labels and minutes only. Names, chat messages, photos and locations are not sent.
- Requests are rate-limited to control cost and abuse.

Never commit a real key to Git. Rotate any key that was pasted into chat, a ticket, terminal history or another shared channel before using it in production.
