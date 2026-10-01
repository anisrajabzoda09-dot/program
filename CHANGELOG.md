# Changelog

## 2.13.0 — 2026-10-01
- Notifications even when the app is closed (native long-poll service, no Firebase): messages, SOS, extra-time requests and answers, new apps, missed calls.
- SOS rings a looping alarm on the parent phone until it is silenced.
- Voice calls between parent and child (WebRTC, server signaling), Telegram-style call screen.
- Study mode («Тамаркузи дарс»): games, social and video apps closed during school hours; phone, SMS, education and always-allowed apps stay open.
- Device alerts: battery below 15 % and phone offline for 20 minutes (each sent once).
- Bedtime and study mode never close the phone/SMS apps.

## 2.12.0
- One-tap in-app update: download, signature check, install over the current app (data and permissions kept).
- Fixed: the app could never install its own updates (missing `REQUEST_INSTALL_PACKAGES`).

## 2.11.0
- Fixed: child location was never sent indoors (now last-known position plus one-shot fixes every minute).
- Child sees blocked apps, limits and schedules («Қоидаҳои ман»), can request extra time, has an SOS button and quick messages.
- Parent: SOS banner, extra-time inbox, weekly report, bonus time, always-allowed apps, bedtime, 24 h location history, safe places, new-app badges, categories, unread badges, battery.

## 2.10.0
- Firebase removed: sign-in (email/password, Google) and all data go through the NIGOH server.
- Fixed: an account first used as parent could never pair as a child (server 403) — the role is now per phone.
- App rewritten into small feature modules; errors are shown instead of silently ignored.

## 2.9.19
- Fixed: parent app list crashed on placeholder icons from the server.
- Server no longer seeds fake apps (TikTok, PUBG…) or fake block rules.
- Coloured app cards; app list sync retries until it reaches the server.
