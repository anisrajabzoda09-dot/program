# Changelog

## Server — 2026-10-04
- Faster pages: visit statistics are written in the background after the page is sent, instead of blocking every request; Russian and English pages are now counted too.
- Browser caching: versioned CSS/JS files are cached for a year, others for an hour (APK downloads are never cached).
- Deploy refuses any APK that is not signed with the NIGOH release certificate (SHA-256 pinned), so phones can always update in place.
- README rewritten: project history, numbers, architecture, problems solved, tests, screenshots.

## 2.19.0 — 2026-10-04
- Sign in with GitHub on the website and in the Android app (appears once GitHub keys are set on the server; see docs/GITHUB_SIGNIN_SETUP.md).
- Permissions wizard: an «App info» card on the three restricted-setting steps (usage access, display over other apps, Accessibility) with a button to the app page and four numbered steps to turn off Android 13+'s "restricted setting".
- Every server, app and website source file now has a Tajik comment at the top saying what it is for, and Tajik comments above functions.

## 2.18.0 — 2026-10-03
- Sign in with Apple on the website and in the Android app (appears once Apple keys are set on the server; see docs/APPLE_SIGNIN_SETUP.md).
- Website: a new tall 19.5:9 phone in the hero and on the features page, drawn in HTML/CSS (three languages, light/dark).
- Website motion system: hero entrance, phone float and tilt, scroll reveals, header progress bar, smooth FAQ, theme view transition, page cross-fade — all off with reduced motion.
- FAQ: live search with highlighting, result count, «/» shortcut, expand/collapse all, deep links with copy buttons, shareable ?q= searches.
- Download page: device-aware layout (Android / iPhone / computer), APK signing-certificate fingerprint, QR enlarge dialog, share and copy links, sticky Android download bar.
- Site-wide: skip link, consistent focus rings, back-to-top, better contrast, print styles, breadcrumbs, "next page" links and many smaller polish items.
- App: Windows/Linux/web platform code removed; every Dart and Kotlin file documented.

## 2.17.0 — 2026-10-03
- Clearer interface on every screen: one-line purpose text, labelled groups, units on every number («45 min of 60»), empty states that say what to do next, dominant primary actions.
- Motion throughout: staggered list entrances, animated progress bars and pills, fade-through between tabs, smooth chat message entry — all off when the system asks for reduced motion.
- Fixed: on the parent map the bottom panel could cover half the screen with large system fonts; it is now height-capped and scrolls inside.
- Child phone: a visible «Uninstall app» row in Settings that requires the parent's PIN before Android's uninstall screen opens.
- Website: sections fade in on scroll.
- The Windows (.exe) app is discontinued: installer, download page, /download/windows and the Windows build are removed.

## 2.16.0 — 2026-10-02
- Windows app (parent mode): family, app rules, map, chat, voice calls, requests, reports; in-app alerts and SOS alarm while the app is open; navigation rail on wide screens.
- Windows installer and portable zip are built by GitHub Actions and published to the «windows-latest» release; /download/windows on the site.

## 2.15.0 — 2026-10-02
- App in Tajik, Russian and English (language picker on the sign-in screen and in settings); server error messages and notifications follow the chosen language.
- Website in three languages: / (Tajik), /ru, /en with hreflang and a language switch.
- Incoming calls and SOS open full-screen even while the phone is in use (with the «display over other apps» permission; new wizard step for parents).
- Native block screen, PIN screen and updater texts translated (blocking logic unchanged).

## 2.14.0 — 2026-10-01
- Step-by-step permissions wizard after sign-up (child: location, notifications, usage access, overlay, Accessibility, device admin, microphone, battery; parent: notifications, full-screen, camera, microphone, battery). Each step has an «Allow» button, a fallback button to the exact settings screen and expandable instructions.
- Profile photos for parents and children (settings, cards, chat, calls, map marker).
- Removing a child always requires the parent PIN (created first if missing).
- Fixed: map info card text was laid out one letter per line.

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
