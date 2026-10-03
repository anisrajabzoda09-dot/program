# NIGOH mobile API

Base URL: `https://nigohfamily.qobus.tj`. JSON in and out. Errors: HTTP status + `{"detail": "<Tajik message>"}`.

Every authenticated request sends:
- `Authorization: Bearer ngh_…` — token from sign-in (only its SHA-256 is stored on the server)
- `X-NIGOH-Role: parent | child` — the side this phone acts for (one account may be a parent on one phone and a child on another)

## Sign-in — `/api/mobile/v3`
| Method | Path | Body / notes |
|---|---|---|
| POST | `/auth/register` | `{email, password (≥8), full_name}` → `{token, user}` |
| POST | `/auth/login` | `{email, password}` → `{token, user}` |
| POST | `/auth/google` | `{id_token}` — verified with Google, audience must be in `GOOGLE_MOBILE_CLIENT_IDS` |
| POST | `/auth/logout` | revokes the token |
| GET / PUT | `/me` | profile; PUT `{full_name?, role?}` |

## Family — `/api/mobile/v2`
| Method | Path | Who | Notes |
|---|---|---|---|
| GET | `/snapshot` | both | parent: `{children:[…]}`, child: `{child: {…} \| null}` |
| POST | `/pair/code` | child | `{child_name, gender, age}` → 6-digit `pairing_code` |
| POST | `/pair` | parent | `{pairing_code}` |
| DELETE | `/children/{id}` | parent | unlink child |
| POST | `/children/{id}/apps/sync` | child | installed apps + usage (`usage_minutes` 0–1440) |
| PUT | `/children/{id}/apps/{package}` | parent | `{is_blocked?, daily_limit_minutes?, schedule?, always_allowed?}` |
| POST | `/children/{id}/apps/{package}/bonus` | parent | `{minutes}` extra time for today |
| POST | `/children/{id}/location` | child | `{latitude, longitude, accuracy?, battery_level?}` |
| GET | `/children/{id}/locations?hours=24` | both | location history |
| GET | `/children/{id}/usage?days=7` | both | screen time per day + top apps |
| GET / POST | `/children/{id}/chat` | both | messages; POST `{content, message_type: text\|urgent}` (`urgent` = SOS) |
| POST | `/children/{id}/chat/read` | both | mark the other side's messages read |
| POST | `/children/{id}/requests` | child | `{package_name, minutes, reason?}` extra-time request |
| GET | `/children/{id}/requests?status=pending` | both | |
| POST | `/children/{id}/requests/{rid}/decision` | parent | `{approve, minutes?}` |
| PUT | `/children/{id}/settings` | parent | `{bedtime?: {enabled,start,end}, study?: {enabled,start,end,weekdays}}` |
| GET / POST / DELETE | `/children/{id}/places[/{pid}]` | parent writes | safe places `{name, latitude, longitude, radius_meters}` |

## Realtime — `/api/mobile/v3`
| Method | Path | Notes |
|---|---|---|
| GET | `/events?after_id=N&wait=25` | long-poll notifications; `after_id=0` returns only `latest_id`. Kinds: `message, sos, time_request, time_decision, low_battery, offline, new_app, call, call_end, missed_call` |
| GET | `/calls/config` | ICE servers (STUN + optional TURN from env) |
| POST | `/calls` | `{child_id}` → call (rings the other side) |
| GET | `/calls/{id}` | status: `ringing, active, ended, declined, missed` (ringing > 45 s → missed) |
| POST | `/calls/{id}/accept \| decline \| end` | |
| POST | `/calls/{id}/signal` | `{kind: offer\|answer\|ice, payload: JSON string}` |
| GET | `/calls/{id}/signals?after_id=N&wait=10` | the other side's signals + current status |

## Updates
`GET /api/mobile/version?current_version_code=N` → `{version, version_code, update_available, release_notes, download_url}`.

End-to-end check of all of the above: `venv/bin/python tests/test_mobile_v3.py`.
