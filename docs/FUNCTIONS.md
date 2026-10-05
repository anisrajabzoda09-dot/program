# NIGOH Family — ҳамаи функсияҳо

Ин файлро скрипти `scripts/gen_function_docs.py` аз шарҳҳои тоҷикии худи код месозад —
онро дастӣ таҳрир накунед. Барои фаҳмидани он ки қисмҳо бо ҳам чӣ гуна кор мекунанд,
[HOW_IT_WORKS.md](HOW_IT_WORKS.md)-ро хонед.

**144 файл · 1724 функсия ва синф**

## Мундариҷа

- [Сервер — роутҳо (API ва саҳифаҳо)](#сервер--роутҳо-api-ва-саҳифаҳо) — 11 файл, 211 функсия ва синф
- [Сервер — мантиқи асосӣ](#сервер--мантиқи-асосӣ) — 21 файл, 140 функсия ва синф
- [Сервер — моделҳои база](#сервер--моделҳои-база) — 20 файл, 62 функсия ва синф
- [Сервер — оғоз](#сервер--оғоз) — 1 файл, 6 функсия ва синф
- [Скриптҳо](#скриптҳо) — 4 файл, 25 функсия ва синф
- [Санҷишҳои сервер](#санҷишҳои-сервер) — 15 файл, 70 функсия ва синф
- [Барнома — асос (core)](#барнома--асос-core) — 11 файл, 255 функсия ва синф
- [Барнома — экранҳои волидайн](#барнома--экранҳои-волидайн) — 13 файл, 225 функсия ва синф
- [Барнома — экранҳои фарзанд](#барнома--экранҳои-фарзанд) — 4 файл, 116 функсия ва синф
- [Барнома — воридшавӣ ва танзимот](#барнома--воридшавӣ-ва-танзимот) — 13 файл, 173 функсия ва синф
- [Барнома — чат ва занг](#барнома--чат-ва-занг) — 4 файл, 134 функсия ва синф
- [Барнома — UI ва тарҷума](#барнома--ui-ва-тарҷума) — 13 файл, 74 функсия ва синф
- [Android (Kotlin)](#android-kotlin) — 14 файл, 233 функсия ва синф

## Сервер — роутҳо (API ва саҳифаҳо)

### `app/routers/__init__.py`

содир кардани ҷузъҳои ин package барои истифода дар бахшҳои дигар.

### `app/routers/admin.py`

dashboard-и admin ва API-и идоракунии фарзандон.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class ChildUpdateRequest` |  | Маълумоти `ChildUpdateRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class ChildDeleteRequest` |  | Маълумоти `ChildDeleteRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `admin_dashboard()` | `GET /admin` | Дархости `GET /admin`-ро барои admin dashboard коркард мекунад. |
| `api_admin_stats()` | `GET /api/admin/stats` | Дархости `GET /api/admin/stats`-ро барои admin stats коркард мекунад. |
| `api_admin_update_child()` | `POST /api/admin/child/update` | Дархости `POST /api/admin/child/update`-ро барои admin update фарзанд коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `api_admin_delete_child()` | `POST /api/admin/child/delete` | Дархости `POST /api/admin/child/delete`-ро барои admin delete фарзанд коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |

### `app/routers/auth.py`

бақайдгирӣ, воридшавӣ, баромадан ва OAuth-и website.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `_web_lang()` |  | Забони саҳифаи воридшавӣ аз header-и X-NIGOH-Lang (tg, ru, en). |
| `_google_configured()` |  | Маълумоти ёрирасони Google configured-ро омода карда, ба caller бармегардонад. |
| `_safe_next_path()` |  | Маълумоти ёрирасони бехатар next path-ро омода карда, ба caller бармегардонад. |
| `_request_is_https()` |  | Маълумоти ёрирасони дархост is https-ро омода карда, ба caller бармегардонад. |
| `_prune_oauth_states()` |  | prune OAuth states-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `_set_session_cookie()` |  | set session cookie-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `_google_userinfo_from_access_token()` |  | Маълумоти ёрирасони Google userinfo from access token-ро омода карда, ба caller бармегардонад. |
| `_exchange_google_code()` |  | Маълумоти ёрирасони exchange Google code-ро омода карда, ба caller бармегардонад. |
| `_sign_in_google_user()` |  | Маълумоти ёрирасони sign in Google корбар-ро омода карда, ба caller бармегардонад. |
| `auth_page()` | `GET /auth` | Дархости `GET /auth`-ро барои auth саҳифа коркард мекунад. |
| `api_register()` | `POST /api/auth/register` | Дархости `POST /api/auth/register`-ро барои register коркард мекунад. |
| `api_login()` | `POST /api/auth/login` | Дархости `POST /api/auth/login`-ро барои login коркард мекунад. |
| `api_google_auth()` | `POST /api/auth/google` | Дархости `POST /api/auth/google`-ро барои Google auth коркард мекунад. |
| `google_login()` | `GET /auth/google/login` | Дархости `GET /auth/google/login`-ро барои Google login коркард мекунад. |
| `google_callback()` | `GET /auth/google/callback` | Дархости `GET /auth/google/callback`-ро барои Google callback коркард мекунад. |
| `_apple_auth_page()` |  | Маълумоти ёрирасони Apple auth саҳифа-ро омода карда, ба caller бармегардонад. |
| `apple_login()` | `GET /auth/apple/login` | Дархости `GET /auth/apple/login`-ро барои Apple login коркард мекунад. |
| `apple_callback()` | `POST /auth/apple/callback` | Дархости `POST /auth/apple/callback`-ро барои Apple callback коркард мекунад. |
| `apple_android_bridge()` | `POST /auth/apple/android` | Дархости `POST /auth/apple/android`-ро барои Apple android bridge коркард мекунад. |
| `_github_auth_page()` |  | Маълумоти ёрирасони GitHub auth саҳифа-ро омода карда, ба caller бармегардонад. |
| `_github_redirect()` |  | Маълумоти ёрирасони GitHub redirect-ро омода карда, ба caller бармегардонад. |
| `_app_return()` |  | Маълумоти ёрирасони app return-ро омода карда, ба caller бармегардонад. |
| `github_login()` | `GET /auth/github/login` | Дархости `GET /auth/github/login`-ро барои GitHub login коркард мекунад. |
| `github_mobile_start()` | `GET /auth/github/mobile` | Дархости `GET /auth/github/mobile`-ро барои GitHub start коркард мекунад. |
| `github_callback()` | `GET /auth/github/callback` | Дархости `GET /auth/github/callback`-ро барои GitHub callback коркард мекунад. |
| `logout()` | `GET /logout` | Дархости `GET /logout`-ро барои logout коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |

### `app/routers/contact.py`

саҳифаи «Тамос бо мо» — форма бо се забон, ҳифз аз спам ва нигоҳдории паём.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `_client_ip()` |  | IP-и корбарро бо назардошти nginx (X-Forwarded-For) муайян мекунад. |
| `_rate_limited()` |  | Агар аз ин IP дар як соат аллакай RATE_LIMIT паём омада бошад, True бармегардонад. |
| `validate_contact()` |  | Майдонҳои формаро месанҷад ва рӯйхати калидҳои хатоҳоро бармегардонад. |
| `_prefix()` |  | Пешванди URL-и забонро бармегардонад ("" барои тоҷикӣ). |
| `_register()` |  | Роутҳои GET ва POST-и саҳифаи тамосро барои як забон сабт мекунад. |

### `app/routers/download.py`

download-и APK ва санҷиши version-и mobile.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `current_download_url()` |  | Маълумоти ёрирасони current download url-ро омода карда, ба caller бармегардонад. |
| `download_qr()` | `GET /api/qr/download` | Дархости `GET /api/qr/download`-ро барои download qr коркард мекунад. |
| `download_android_apk()` | `GET /qr, GET /install, GET /apk, GET /nigoh.apk, GET /app.apk, GET /download, GET /download/android` | Дархости `GET /qr`-ро барои download android apk коркард мекунад. |

### `app/routers/mobile.py`

API-и mobile барои pairing, назорат, chat, location ва usage.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class ChildRenameRequest` |  | Маълумоти `ChildRenameRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class SOSAlertRequest` |  | Маълумоти `SOSAlertRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class GeofenceRequest` |  | Маълумоти `GeofenceRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class BedtimeScheduleRequest` |  | Маълумоти `BedtimeScheduleRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class DeviceLockRequest` |  | Маълумоти `DeviceLockRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class WebFilterRequest` |  | Маълумоти `WebFilterRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class ScreenTimeBonusRequest` |  | Маълумоти `ScreenTimeBonusRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `_get_owned_child()` |  | Барои гирифтан ё санҷидани get owned фарзанд истифода мешавад. |
| `_rule_payload()` |  | Маълумоти ёрирасони қоида payload-ро омода карда, ба caller бармегардонад. |
| `_mobile_child()` |  | Маълумоти ёрирасони фарзанд-ро омода карда, ба caller бармегардонад. |
| `_mobile_child_payload()` |  | Маълумоти ёрирасони фарзанд payload-ро омода карда, ба caller бармегардонад. |
| `_json_or_none()` |  | Маълумоти ёрирасони json or none-ро омода карда, ба caller бармегардонад. |
| `_unread()` |  | Маълумоти ёрирасони unread-ро омода карда, ба caller бармегардонад. |
| `_last_urgent()` |  | Маълумоти ёрирасони last urgent-ро омода карда, ба caller бармегардонад. |
| `_mobile_snapshot()` |  | Маълумоти ёрирасони snapshot-ро омода карда, ба caller бармегардонад. |
| `mobile_app_page()` | `GET /mobile` | Дархости `GET /mobile`-ро барои app саҳифа коркард мекунад. |
| `get_app_version()` | `GET /api/mobile/version` | Дархости `GET /api/mobile/version`-ро барои get app version коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `sync_dynamic_bundle()` | `GET /api/mobile/sync-bundle` | Дархости `GET /api/mobile/sync-bundle`-ро барои sync dynamic bundle коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `publish_dynamic_bundle()` | `POST /api/mobile/bundles` | Дархости `POST /api/mobile/bundles`-ро барои publish dynamic bundle коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `set_user_role()` | `POST /api/mobile/role-select` | Дархости `POST /api/mobile/role-select`-ро барои set корбар нақш коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `setup_child_profile()` | `POST /api/mobile/setup-child` | Дархости `POST /api/mobile/setup-child`-ро барои setup фарзанд профил коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `get_mobile_status()` | `GET /api/mobile/status` | Дархости `GET /api/mobile/status`-ро барои get ҳолат коркард мекунад. |
| `send_mobile_chat_message()` | `POST /api/mobile/chat/send` | Дархости `POST /api/mobile/chat/send`-ро барои send chat паём коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `pair_device()` | `POST /api/mobile/pair` | Дархости `POST /api/mobile/pair`-ро барои pairing дастгоҳ коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `mobile_snapshot_v2()` | `GET /api/mobile/v2/snapshot` | Дархости `GET /api/mobile/v2/snapshot`-ро барои snapshot коркард мекунад. |
| `create_mobile_pair_code_v2()` | `POST /api/mobile/v2/pair/code` | Дархости `POST /api/mobile/v2/pair/code`-ро барои create pairing code коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `pair_mobile_device_v2()` | `POST /api/mobile/v2/pair` | Дархости `POST /api/mobile/v2/pair`-ро барои pairing дастгоҳ коркард мекунад. |
| `link_existing_mobile_family_v2()` | `POST /api/mobile/v2/link-existing` | Дархости `POST /api/mobile/v2/link-existing`-ро барои link existing оила коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `sync_mobile_apps_v2()` | `POST /api/mobile/v2/children/{child_id}/apps/sync` | Дархости `POST /api/mobile/v2/children/{child_id}/apps/sync`-ро барои sync app-ҳо коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `update_mobile_app_rule_v2()` | `PUT /api/mobile/v2/children/{child_id}/apps/{package_name}` | Дархости `PUT /api/mobile/v2/children/{child_id}/apps/{package_name}`-ро барои update app қоида коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `update_mobile_location_v2()` | `POST /api/mobile/v2/children/{child_id}/location` | Дархости `POST /api/mobile/v2/children/{child_id}/location`-ро барои update location коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `get_mobile_chat_v2()` | `GET /api/mobile/v2/children/{child_id}/chat` | Дархости `GET /api/mobile/v2/children/{child_id}/chat`-ро барои get chat коркард мекунад. |
| `send_mobile_chat_v2()` | `POST /api/mobile/v2/children/{child_id}/chat` | Дархости `POST /api/mobile/v2/children/{child_id}/chat`-ро барои send chat коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `unlink_mobile_child_v2()` | `DELETE /api/mobile/v2/children/{child_id}` | Дархости `DELETE /api/mobile/v2/children/{child_id}`-ро барои unlink фарзанд коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `list_child_apps_v1()` | `GET /api/v1/children/{child_id}/apps/` | Дархости `GET /api/v1/children/{child_id}/apps/`-ро барои list фарзанд app-ҳо коркард мекунад. |
| `update_child_app_limit_v1()` | `PUT /api/v1/children/{child_id}/apps/{package_name}/limits` | Дархости `PUT /api/v1/children/{child_id}/apps/{package_name}/limits`-ро барои update фарзанд app limit коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `report_child_usage_v1()` | `POST /api/v1/children/{child_id}/apps/report-usage` | Дархости `POST /api/v1/children/{child_id}/apps/report-usage`-ро барои ҳисобот фарзанд истифода коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `process_time_extension_v1()` | `POST /api/v1/children/{child_id}/requests/time-extension` | Дархости `POST /api/v1/children/{child_id}/requests/time-extension`-ро барои process вақт тамдид коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `toggle_child_app()` | `POST /api/mobile/apps/toggle` | Дархости `POST /api/mobile/apps/toggle`-ро барои toggle фарзанд app коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `set_child_app_limit_endpoint()` | `POST /api/mobile/apps/limit` | Дархости `POST /api/mobile/apps/limit`-ро барои set фарзанд app limit коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `rename_child_profile()` | `POST /api/mobile/child/rename` | Дархости `POST /api/mobile/child/rename`-ро барои rename фарзанд профил коркард мекунад. |
| `trigger_sos_alert()` | `POST /api/mobile/sos` | Дархости `POST /api/mobile/sos`-ро барои trigger SOS alert коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `set_geofence_safe_zone()` | `POST /api/mobile/geofence` | Дархости `POST /api/mobile/geofence`-ро барои set geofence бехатар zone коркард мекунад. |
| `set_bedtime_schedule()` | `POST /api/mobile/schedule/bedtime` | Дархости `POST /api/mobile/schedule/bedtime`-ро барои set вақти хоб schedule коркард мекунад. |
| `toggle_device_lock()` | `POST /api/mobile/device/lock` | Дархости `POST /api/mobile/device/lock`-ро барои toggle дастгоҳ lock коркард мекунад. |
| `set_web_filter()` | `POST /api/mobile/webfilter` | Дархости `POST /api/mobile/webfilter`-ро барои set web филтр коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `ping_live_location()` | `GET /api/mobile/location/ping` | Дархости `GET /api/mobile/location/ping`-ро барои ping live location коркард мекунад. |
| `update_child_location()` | `POST /api/mobile/location/update` | Дархости `POST /api/mobile/location/update`-ро барои update фарзанд location коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `reward_screen_time_bonus()` | `POST /api/mobile/screentime/bonus` | Дархости `POST /api/mobile/screentime/bonus`-ро барои reward экран вақт вақти иловагӣ коркард мекунад. |
| `get_recently_installed_apps()` | `GET /api/mobile/apps/recent` | Дархости `GET /api/mobile/apps/recent`-ро барои get recently насбшуда app-ҳо коркард мекунад. |
| `check_battery_status()` | `GET /api/mobile/battery/alert` | Дархости `GET /api/mobile/battery/alert`-ро барои check батарея ҳолат коркард мекунад. |
| `get_daily_family_report()` | `GET /api/mobile/reports/daily` | Дархости `GET /api/mobile/reports/daily`-ро барои get рӯзона оила ҳисобот коркард мекунад. |

### `app/routers/mobile_auth.py`

endpoint-ҳои воридшавӣ ва профили app-и Android.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class RegisterRequest` |  | Маълумоти `RegisterRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class LoginRequest` |  | Маълумоти `LoginRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class GoogleRequest` |  | Маълумоти `GoogleRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class ProfileUpdate` |  | Маълумоти `ProfileUpdate`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `_device()` |  | Маълумоти ёрирасони дастгоҳ-ро омода карда, ба caller бармегардонад. |
| `_auth_response()` |  | Маълумоти ёрирасони auth response-ро омода карда, ба caller бармегардонад. |
| `register()` | `POST /api/mobile/v3/auth/register` | Дархости `POST /auth/register`-ро барои register коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `login()` | `POST /api/mobile/v3/auth/login` | Дархости `POST /auth/login`-ро барои login коркард мекунад. |
| `google()` | `POST /api/mobile/v3/auth/google` | Дархости `POST /auth/google`-ро барои Google коркард мекунад. |
| `apple_config()` | `GET /api/mobile/v3/auth/apple/config` | Дархости `GET /auth/apple/config`-ро барои Apple танзимот коркард мекунад. |
| `class AppleRequest` |  | Маълумоти `AppleRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `apple()` | `POST /api/mobile/v3/auth/apple` | Дархости `POST /auth/apple`-ро барои Apple коркард мекунад. |
| `github_config()` | `GET /api/mobile/v3/auth/github/config` | Дархости `GET /auth/github/config`-ро барои GitHub танзимот коркард мекунад. |
| `class GitHubRequest` |  | Маълумоти `GitHubRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `github()` | `POST /api/mobile/v3/auth/github` | Дархости `POST /auth/github`-ро барои GitHub коркард мекунад. |
| `logout()` | `POST /api/mobile/v3/auth/logout` | Дархости `POST /auth/logout`-ро барои logout коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `me()` | `GET /api/mobile/v3/me` | Дархости `GET /me`-ро барои me коркард мекунад. |
| `update_me()` | `PUT /api/mobile/v3/me` | Дархости `PUT /me`-ро барои update me коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `class AvatarUpload` |  | Маълумоти `AvatarUpload`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `upload_avatar()` | `POST /api/mobile/v3/me/avatar` | Дархости `POST /me/avatar`-ро барои upload avatar коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `delete_avatar()` | `DELETE /api/mobile/v3/me/avatar` | Дархости `DELETE /me/avatar`-ро барои delete avatar коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |

### `app/routers/mobile_family.py`

history, дархости вақт, bonus, bedtime ва safe place-ҳои оила.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `_child()` |  | Маълумоти ёрирасони фарзанд-ро омода карда, ба caller бармегардонад. |
| `_parent_only()` |  | Маълумоти ёрирасони parent only-ро омода карда, ба caller бармегардонад. |
| `_child_only()` |  | Маълумоти ёрирасони фарзанд only-ро омода карда, ба caller бармегардонад. |
| `_add_bonus()` |  | Маълумоти ёрирасони add вақти иловагӣ-ро омода карда, ба caller бармегардонад. |
| `location_history()` | `GET /api/mobile/v2/children/{child_id}/locations` | Дархости `GET /locations`-ро барои location таърих коркард мекунад. |
| `usage_history()` | `GET /api/mobile/v2/children/{child_id}/usage` | Дархости `GET /usage`-ро барои истифода таърих коркард мекунад. |
| `class TimeRequestCreate` |  | Маълумоти `TimeRequestCreate`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class TimeRequestDecision` |  | Маълумоти `TimeRequestDecision`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `_request_payload()` |  | Маълумоти ёрирасони дархост payload-ро омода карда, ба caller бармегардонад. |
| `create_time_request()` | `POST /api/mobile/v2/children/{child_id}/requests` | Дархости `POST /requests`-ро барои create вақт дархост коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад ва notification мефиристад. |
| `list_time_requests()` | `GET /api/mobile/v2/children/{child_id}/requests` | Дархости `GET /requests`-ро барои list вақт дархостҳо коркард мекунад. |
| `decide_time_request()` | `POST /api/mobile/v2/children/{child_id}/requests/{request_id}/decision` | Дархости `POST /requests/{request_id}/decision`-ро барои decide вақт дархост коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад ва notification мефиристад. |
| `class BonusRequest` |  | Маълумоти `BonusRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `give_bonus()` | `POST /api/mobile/v2/children/{child_id}/apps/{package_name}/bonus` | Дархости `POST /apps/{package_name}/bonus`-ро барои give вақти иловагӣ коркард мекунад. |
| `class Bedtime` |  | Маълумоти `Bedtime`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class StudyMode` |  | Маълумоти `StudyMode`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class WebFilterSettings` |  | Танзими филтри сайтҳо: сатҳи синну сол ва сайтҳое, ки волидайн дастӣ бастанд. |
| `class ChildSettings` |  | Маълумоти `ChildSettings`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `update_child_settings()` | `PUT /api/mobile/v2/children/{child_id}/settings` | Дархости `PUT /settings`-ро барои update фарзанд танзимот коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `class WebFilterState` |  | Ҳолати филтри сайтҳо, ки телефони фарзанд хабар медиҳад. |
| `report_web_filter_state()` | `POST /api/mobile/v2/children/{child_id}/web-filter/state` | Дархости `POST /web-filter/state`: телефони фарзанд мегӯяд, ки филтр фаъол аст ё не. |
| `class SafePlaceCreate` |  | Маълумоти `SafePlaceCreate`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `list_places()` | `GET /api/mobile/v2/children/{child_id}/places` | Дархости `GET /places`-ро барои list маконҳо коркард мекунад. |
| `add_place()` | `POST /api/mobile/v2/children/{child_id}/places` | Дархости `POST /places`-ро барои add макон коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `class PlaceAppRule` |  | Қоидаи як барнома дар ҷой: баста, бо лимит ё ҳамеша кушода. |
| `class PlaceRules` |  | Қоидаҳои ҷой: барномаҳо ва огоҳии омадан/рафтан. |
| `class SafePlaceUpdate` |  | Тағйири ҷой: ном, радиус ва/ё қоидаҳо (майдонҳои холӣ иваз намешаванд). |
| `update_place()` | `PUT /api/mobile/v2/children/{child_id}/places/{place_id}` | Дархости `PUT /places/{place_id}`: ном, радиус ва қоидаҳои барномаҳоро дар ин ҷой иваз мекунад. |
| `delete_place()` | `DELETE /api/mobile/v2/children/{child_id}/places/{place_id}` | Дархости `DELETE /places/{place_id}`-ро барои delete макон коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `mark_chat_read()` | `POST /api/mobile/v2/children/{child_id}/chat/read` | Дархости `POST /chat/read`-ро барои mark chat read коркард мекунад. |

### `app/routers/mobile_realtime.py`

long-poll notification ва signaling-и WebRTC барои зангҳо.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `_my_children()` |  | Маълумоти ёрирасони my фарзандон-ро омода карда, ба caller бармегардонад. |
| `_role()` |  | Маълумоти ёрирасони нақш-ро омода карда, ба caller бармегардонад. |
| `events()` | `GET /api/mobile/v3/events` | Дархости `GET /events`-ро барои event-ҳо коркард мекунад. |
| `class CallCreate` |  | Маълумоти `CallCreate`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class SignalCreate` |  | Маълумоти `SignalCreate`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `_call()` |  | Маълумоти ёрирасони занг-ро омода карда, ба caller бармегардонад. |
| `_expire()` |  | Занги дар 45 сония беҷавобмондаро missed карда, event мефиристад. |
| `call_config()` | `GET /api/mobile/v3/calls/config` | Дархости `GET /calls/config`-ро барои занг танзимот коркард мекунад. |
| `start_call()` | `POST /api/mobile/v3/calls` | Дархости `POST /calls`-ро барои start занг коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад ва notification мефиристад. |
| `get_call()` | `GET /api/mobile/v3/calls/{call_id}` | Дархости `GET /calls/{call_id}`-ро барои get занг коркард мекунад. |
| `_set_status()` |  | Маълумоти ёрирасони set ҳолат-ро омода карда, ба caller бармегардонад. |
| `accept_call()` | `POST /api/mobile/v3/calls/{call_id}/accept` | Дархости `POST /calls/{call_id}/accept`-ро барои accept занг коркард мекунад. |
| `decline_call()` | `POST /api/mobile/v3/calls/{call_id}/decline` | Дархости `POST /calls/{call_id}/decline`-ро барои decline занг коркард мекунад ва notification мефиристад. |
| `end_call()` | `POST /api/mobile/v3/calls/{call_id}/end` | Дархости `POST /calls/{call_id}/end`-ро барои end занг коркард мекунад ва notification мефиристад. |
| `send_signal()` | `POST /api/mobile/v3/calls/{call_id}/signal` | Дархости `POST /calls/{call_id}/signal`-ро барои send signal коркард мекунад; тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `get_signals()` | `GET /api/mobile/v3/calls/{call_id}/signals` | Дархости `GET /calls/{call_id}/signals`-ро барои get signals коркард мекунад. |

### `app/routers/otp.py`

роутҳои ҳимояи дуқабата — қадами рамз пас аз парол, рамз ба почта ва танзими

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class TicketCode` |  | Чипта аз қадами аввал ва рамзи 6-рақама (ё рамзи эҳтиётӣ). |
| `class EmailOnly` |  | Почта барои фиристодани рамз. |
| `class EmailCodeIn` |  | Почта ва рамзи 6-рақама аз мактуб. |
| `class CodeOnly` |  | Як рамз барои тасдиқ, хомӯш кардан ё рамзҳои эҳтиётӣ. |
| `_lang()` |  | Забони ҷавоб: header-и X-NIGOH-Lang ё ?lang= ё тоҷикӣ. |
| `_fail()` |  | OtpError-ро ба ҷавоби HTTP бо матни забони корбар табдил медиҳад. |
| `_client_ip()` |  | IP-и корбар бо назардошти nginx. |
| `otp_config()` | `GET /api/auth/otp/config, GET /api/mobile/v3/auth/otp/config` | Кадом навъҳои OTP дар сервер фаъоланд (барои нишон додан ё пинҳон кардани тугмаҳо). |
| `_web_session()` |  | Сессияи сайтро бо cookie месозад (ҳамон тавре ки воридшавии оддӣ). |
| `web_login_otp()` | `POST /api/auth/login/otp` | Қадами дуюми воридшавии сайт: рамзи Authenticator ё рамзи эҳтиётӣ. |
| `email_code_request()` | `POST /api/auth/email-code, POST /api/mobile/v3/auth/email-code` | Рамзи воридшавиро ба почта мефиристад. Ҷавоб ҳамеша якхела аст (почтаҳо ошкор намешаванд). |
| `web_email_code_verify()` | `POST /api/auth/email-code/verify` | Рамзи почтаро месанҷад; агар Authenticator фаъол бошад, қадами дуюмро талаб мекунад. |
| `mobile_login_otp()` | `POST /api/mobile/v3/auth/login/otp` | Қадами дуюми воридшавии барнома; token-и барномаро медиҳад. |
| `mobile_email_code_verify()` | `POST /api/mobile/v3/auth/email-code/verify` | Рамзи почтаро дар барнома месанҷад; бо Authenticator — қадами дуюм. |
| `_status()` |  | Ҳолати ҳимояи дуқабата барои экран. |
| `_setup()` |  | Калиди навро месозад ва QR-ро бармегардонад. |
| `_confirm()` |  | Аввалин рамзро месанҷад ва рамзҳои эҳтиётиро бармегардонад. |
| `_disable()` |  | Ҳимояи дуқабатаро бо рамз хомӯш мекунад. |
| `_recovery()` |  | Рамзҳои эҳтиётии навро медиҳад. |
| `_web_user()` |  | Корбари воридшудаи сайтро аз база мегирад; бе сессия — 401. |
| `_mobile_db_user()` |  | Корбари барномаро аз token мегирад. |
| `_account_page()` |  | Саҳифаи «Ҳимояи ҳисоб»-ро барои забони додашуда месозад. |
| `web_totp_status()` | `GET /api/account/totp` | Ҳолати Authenticator барои корбари сайт. |
| `web_totp_setup()` | `POST /api/account/totp/setup` | Оғози танзими Authenticator дар сайт. |
| `web_totp_confirm()` | `POST /api/account/totp/confirm` | Тасдиқи Authenticator дар сайт. |
| `web_totp_disable()` | `POST /api/account/totp/disable` | Хомӯш кардани Authenticator дар сайт; сессияҳои дигари сайти ин корбар баста мешаванд. |
| `web_totp_recovery()` | `POST /api/account/totp/recovery` | Рамзҳои эҳтиётии нав дар сайт. |
| `mobile_totp_status()` | `GET /api/mobile/v3/me/totp` | Ҳолати Authenticator барои корбари барнома. |
| `mobile_totp_setup()` | `POST /api/mobile/v3/me/totp/setup` | Оғози танзими Authenticator дар барнома. |
| `mobile_totp_confirm()` | `POST /api/mobile/v3/me/totp/confirm` | Тасдиқи Authenticator дар барнома. |
| `mobile_totp_disable()` | `POST /api/mobile/v3/me/totp/disable` | Хомӯш кардани Authenticator дар барнома. |
| `mobile_totp_recovery()` | `POST /api/mobile/v3/me/totp/recovery` | Рамзҳои эҳтиётии нав дар барнома. |
| `_close_other_web_sessions()` |  | Ҳамаи сессияҳои сайти ин корбарро, ба ғайр аз ҳозира, мебандад. |

### `app/routers/public.py`

саҳифаҳои оммавӣ, SEO, health ва endpoint-ҳои verification.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `get_robots_txt()` | `GET /robots.txt` | Дархости `GET /robots.txt`-ро барои get robots txt коркард мекунад. |
| `_lang_url()` |  | Суроғаи пурраи саҳифаро барои забони додашуда месозад (тоҷикӣ бе пешванд). |
| `build_sitemap()` |  | XML-и sitemap-ро бо ҳамаи саҳифаҳо ва пайвандҳои hreflang байни забонҳо месозад. |
| `get_sitemap_xml()` | `GET /sitemap.xml` | Дархости `GET /sitemap.xml`: харитаи сайт бо се забон барои Google ва Yandex. |
| `health_check()` | `GET /health` | Дархости `GET /health`-ро барои health check коркард мекунад. |
| `_site_page()` |  | Саҳифаи оммавиро бо template ва забони мувофиқи URL месозад. |
| `_register_translated()` |  | Маълумоти ёрирасони register translated-ро омода карда, ба caller бармегардонад. |
| `_register_info_page()` |  | Як саҳифаи иттилоотиро барои забони додашуда (GET ва HEAD) сабт мекунад. |
| `landing_page()` | `GET /` | Дархости `GET /`-ро барои landing саҳифа коркард мекунад. |
| `features_page()` | `GET /features` | Дархости `GET /features`-ро барои features саҳифа коркард мекунад. |
| `how_it_works_page()` | `GET /how-it-works` | Дархости `GET /how-it-works`-ро барои how it works саҳифа коркард мекунад. |
| `security_page()` | `GET /security` | Дархости `GET /security`-ро барои security саҳифа коркард мекунад. |
| `faq_page()` | `GET /faq` | Дархости `GET /faq`-ро барои faq саҳифа коркард мекунад. |
| `get_app_page()` | `GET /get` | Дархости `GET /get`-ро барои get app саҳифа коркард мекунад. |
| `favicon()` | `GET /favicon.ico` | Браузерҳо /favicon.ico-ро худашон мепурсанд; ба нишонаи сайт мефиристем (бе 404 дар log). |
| `nigoh_3d_presentation()` | `GET /3d, GET /nigoh3d` | Дархости `GET /3d`-ро барои nigoh 3d presentation коркард мекунад. |
| `weevolve_showcase_page()` | `GET /weevolve, GET /evolve` | Дархости `GET /weevolve`-ро барои weevolve showcase саҳифа коркард мекунад. |
| `google_verification_exact()` | `GET /googleee0fc42c18bef62a.html` | Дархости `GET /googleee0fc42c18bef62a.html`-ро барои Google verification exact коркард мекунад. |
| `google_verification_url_prefix()` | `GET /google4e211d699041db6f.html` | Дархости `GET /google4e211d699041db6f.html`-ро барои Google verification url prefix коркард мекунад. |


## Сервер — мантиқи асосӣ

### `app/core/apple_auth.py`

воридшавӣ бо Apple, санҷиши token ва пайваст кардани ҳисоб.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `apple_private_key()` |  | Калиди хусусии .p8-и Apple-ро аз танзимот ё файл мехонад. |
| `apple_configured()` |  | Мавҷуд будани ҳамаи танзимоти Sign in with Apple-ро месанҷад. |
| `apple_audiences()` |  | Client ID-ҳои иҷозатдодашудаи Apple token-ро ҷамъ мекунад. |
| `client_secret()` |  | Барои Apple client secret-и кӯтоҳмуддати ES256 месозад. |
| `nonce_hash()` |  | Барои nonce hash-и SHA-256 месозад. |
| `_jwks_client()` |  | Client-и муштаракро барои калидҳои имзои Apple медиҳад. |
| `verify_identity_token()` |  | Имзо, issuer, audience, мӯҳлат ва nonce-и Apple token-ро месанҷад. |
| `exchange_code()` |  | Authorization code-и Apple-ро ба identity token иваз мекунад. |
| `upsert_apple_user()` |  | Ҳисоби Apple-ро меёбад ё сохта, пайванди онро дар пойгоҳи додаҳо нигоҳ медорад. |

### `app/core/config.py`

танзимоти server, роҳҳо, credential-ҳо ва қиматҳои пешфарз.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class Settings` |  | Маълумоти `Settings`-ро барои санҷиш ва коркарди request нигоҳ медорад. |

### `app/core/events.py`

сохтан ва навбатгузории notification-ҳои оилавӣ.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `emit()` |  | Event-и оилавиро ба навбат мегузорад; commit-ро caller анҷом медиҳад. |
| `on_battery()` |  | Ҳангоми аз 15% паст шудани батарея як бор волидро огоҳ мекунад. |
| `on_seen()` |  | Ҳозир будани телефонро сабт карда, огоҳии offline-и ояндаро иҷозат медиҳад. |
| `check_offline()` |  | Пас аз 20 дақиқа хомӯш будани телефон волидро огоҳ мекунад. |

### `app/core/firebase_mobile.py`

санҷиши Firebase ID token барои API-и mobile.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `_bearer()` |  | Firebase bearer token-ро мегирад ё request-ро рад мекунад. |
| `_lookup()` |  | Firebase token-ро бо Google санҷида, identity-ро омода мекунад. |
| `require_firebase_user()` |  | Firebase token-ро санҷида, корбари маҳаллиро медиҳад. |
| `find_user_by_firebase_uid()` |  | Корбари ба Firebase UID пайвастшударо меёбад. |

### `app/core/github_auth.py`

воридшавӣ бо GitHub, профил ва ticket-и яккаратаи app.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `github_configured()` |  | Мавҷуд будани credential-ҳои GitHub OAuth-ро месанҷад. |
| `sha256_hex()` |  | Барои қимат hash-и SHA-256-и hexadecimal месозад. |
| `_api_get()` |  | Бо access token ба GitHub REST API дархости GET мефиристад. |
| `fetch_identity()` |  | OAuth code-и GitHub-ро иваз карда, профил ва email-и тасдиқшударо мегирад. |
| `upsert_github_user()` |  | Ҳисоби GitHub-ро меёбад ё сохта, маълумоти онро сабт мекунад. |
| `_prune_tickets()` |  | Ticket-ҳои кӯҳнаи воридшавиро аз хотира пок мекунад. |
| `issue_ticket()` |  | Барои app ticket-и кӯтоҳмуддат ва яккарата месозад. |
| `redeem_ticket()` |  | Ticket ва nonce-ро як бор санҷида, ID-и корбарро медиҳад. |

### `app/core/i18n.py`

интихоб ва тарҷумаи паёмҳои API барои app-и mobile.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `request_lang()` |  | Забони ҷавоби mobile-ро аз header-и request интихоб мекунад. |
| `translate()` |  | Паёми маълуми тоҷикиро тарҷума карда, паёми номаълумро нигоҳ медорад. |

### `app/core/mobile_auth.py`

аутентификатсия, session token ва Google sign-in-и app-и Android.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `_hash()` |  | Барои session token hash-и барнагардонандаи захирашаванда месозад. |
| `issue_token()` |  | Session-и mobile-ро сабт карда, bearer token медиҳад. |
| `revoke_token()` |  | Session-и bearer token-ро аз пойгоҳи додаҳо нест мекунад. |
| `bearer_token()` |  | Bearer token-и ҳатмиро аз request-и mobile мехонад. |
| `_role_hint()` |  | Нақши оилавии дастгоҳро аз header муайян мекунад. |
| `_user_dict()` |  | Маълумоти корбарро бо нақши дастгоҳ барои API омода мекунад. |
| `_session_user()` |  | Session-и фаъолро ба корбар пайваста, вақти фаъолиятро нав мекунад. |
| `require_mobile_user()` |  | Корбари mobile-ро аз NIGOH token ё Firebase token муайян мекунад. |
| `_allowed_google_audiences()` |  | OAuth client ID-ҳои иҷозатдодашудаи Google-ро мехонад. |
| `verify_google_id_token()` |  | Google ID token-ро санҷида, identity-и эътимоднокро медиҳад. |
| `upsert_google_user()` |  | Ҳисоби Google-ро месозад ё маълумоти онро нав мекунад. |

### `app/core/otp.py`

ҳимояи дуқабата (OTP) — Authenticator (TOTP, RFC 6238), рамзҳои эҳтиётӣ, рамз ба почта

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class OtpError` |  | Хатои OTP бо калиди кӯтоҳ (масалан «locked», «invalid») ва вақти боқимонда. |
| `OtpError.__init__()` |  | Калиди хато ва сонияҳо то кӯшиши навбатиро нигоҳ медорад. |
| `totp_available()` |  | Authenticator танҳо вақте кор мекунад, ки калиди рамзгузорӣ дар сервер гузошта шудааст. |
| `email_available()` |  | Рамз ба почта танҳо бо SMTP-и танзимшуда кор мекунад. |
| `_fernet()` |  | Объекти Fernet аз OTP_ENCRYPTION_KEY ё None, агар калид нест ё нодуруст аст. |
| `_encrypt()` |  | Калиди Authenticator-ро барои база рамзгузорӣ мекунад. |
| `_decrypt()` |  | Калиди Authenticator-ро аз база мекушояд; хато бошад, None. |
| `_sha256()` |  | Hash-и SHA-256 барои рамзҳои эҳтиётӣ ва рамзҳои почта. |
| `_now()` |  | Вақти ҳозира бе минтақа (UTC) — ҳамон тавре ки SQLite нигоҳ медорад. |
| `_naive()` |  | Вақтро ба UTC-и бе минтақа меорад. |
| `new_secret()` |  | Калиди нави тасодуфӣ (160 бит) бо base32 барои Authenticator. |
| `_b32()` |  | Base32-ро бо padding-и лозимӣ мекушояд. |
| `totp_at()` |  | Рамзи 6-рақамаи TOTP барои рақами қадам (HMAC-SHA1, RFC 4226/6238). |
| `current_step()` |  | Рақами қадами ҳозираи 30-сонияӣ. |
| `match_totp()` |  | Агар рамз дар ±1 қадам дуруст бошад ва пештар истифода нашуда бошад, қадамро бармегардонад. |
| `otpauth_uri()` |  | Суроғаи otpauth:// барои QR дар Google Authenticator ва барномаҳои монанд. |
| `qr_data_uri()` |  | Рамзи QR-ро ҳамчун тасвири PNG дар data: URI месозад (бе файл ва бе хидмати беруна). |
| `begin_setup()` |  | Калиди навро месозад ва нигоҳ медорад (ҳоло хомӯш). Барои QR ва дастӣ бармегардонад. |
| `_new_recovery_codes()` |  | 8 рамзи эҳтиётии якдафъаина, масалан «7KQ2-M9XD». |
| `_normalize_recovery()` |  | Рамзи эҳтиётиро бе фосила ва бо ҳарфҳои калон меорад. |
| `confirm_setup()` |  | Аввалин рамзро месанҷад, TOTP-ро фаъол мекунад ва рамзҳои эҳтиётиро (як бор) бармегардонад. |
| `disable()` |  | Ҳимояи дуқабатаро бо рамзи ҷорӣ ё рамзи эҳтиётӣ хомӯш мекунад. |
| `regenerate_recovery()` |  | Рамзҳои эҳтиётии навро месозад (кӯҳнаҳо беэътибор мешаванд). |
| `recovery_left()` |  | Чанд рамзи эҳтиётӣ боқӣ мондааст. |
| `check_not_locked()` |  | Агар ҳисоб пас аз кӯшишҳои нодуруст қулф бошад, OtpError("locked") мебарорад. |
| `register_failure()` |  | Кӯшиши нодурустро ҳисоб мекунад; пас аз OTP_MAX_ATTEMPTS ҳисобро қулф мекунад. |
| `_invalid()` |  | Хатои «рамз нодуруст» ё, агар ин кӯшиш қулф кард, «қулф шуд». |
| `reset_failures()` |  | Пас аз рамзи дуруст ҳисобкунаки хатоҳо ва қулфро пок мекунад. |
| `verify_second_factor()` |  | Рамзи Authenticator ё рамзи эҳтиётиро месанҷад. Натиҷа: «totp» ё «recovery». |
| `needs_second_factor()` |  | Оё ин корбар баъди парол ё рамзи почта бояд рамзи Authenticator ворид кунад. |
| `issue_ticket()` |  | Чиптаи кӯтоҳмуддат: «қадами аввал гузашт, акнун рамз лозим». Худи сессия ҳоло дода намешавад. |
| `_prune_tickets()` |  | Чиптаҳои кӯҳнаро нест мекунад. |
| `redeem_ticket()` |  | Чипта ва рамзро месанҷад; агар дуруст бошад, корбарро бармегардонад ва чиптаро нест мекунад. |
| `_email_code()` |  | Рамзи тасодуфии 6-рақама барои почта. |
| `request_email_code()` |  | Рамзи навро ба почта мефиристад, бо маҳдудиятҳо. |
| `verify_email_code()` |  | Рамзи почтаро месанҷад: мӯҳлат, 5 кӯшиш, якдафъаина. Корбарро бармегардонад. |
| `send_email()` |  | Рамзро бо SMTP мефиристад (се забон дар як мактуб, то забони корбар маълум набошад ҳам). |
| `message()` |  | Матни хато бо забони корбар ва вақти боқимонда (масалан «… (14 дақ)»). |

### `app/core/pairing.py`

рамзи пайвасти телефони фарзанд — мӯҳлати 15 дақиқа, навсозии худкор ва ҳифз аз интихоби рамз.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `_now()` |  | Вақти ҳозираи UTC бе минтақа (мисли SQLite). |
| `_naive()` |  | Вақтро ба UTC-и бе минтақа меорад. |
| `issue_code()` |  | Рамзи нави 6-рақамаи беназир месозад ва мӯҳлаташро 15 дақиқа мегузорад. |
| `is_expired()` |  | Мӯҳлати рамз гузаштааст? Сабтҳои кӯҳна бе мӯҳлат ҳамчун эътибордор ҳисоб мешаванд. |
| `refresh_if_expired()` |  | Агар фарзанд пайваст нашуда ва рамзаш кӯҳна бошад, рамзи нав месозад (телефон онро бо snapshot мегирад). |
| `check_attempt()` |  | Кӯшишҳои пайвастшавиро аз рӯи IP ва ҳисоб маҳдуд мекунад; зиёд бошад — 429. |
| `find_child()` |  | Фарзандро аз рӯи рамз меёбад; рамзи нодуруст — 404, кӯҳна — 410. |

### `app/core/place_rules.py`

қоидаҳои барномаҳо аз рӯи ҷой ва огоҳии «расид / баромад».

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `normalize_rules()` |  | Қоидаҳои ҷойро тоза мекунад: танҳо навъҳои маълум, лимит 5–720 дақ, ҳадди аксар 300 барнома. |
| `load_rules()` |  | Қоидаҳои ҷойро аз база мехонад (ҳамеша бо ҳамаи калидҳо). |
| `distance_meters()` |  | Масофаи байни ду нуқта бо метр (формулаи haversine). |
| `place_at()` |  | Ҷойеро, ки нуқта дар он аст, бармегардонад (наздиктаринашро). |
| `on_location()` |  | Пас аз макони нав ҷойи ҳозираро нав мекунад ва огоҳии «расид / баромад»-ро мефиристад. |

### `app/core/releases.py`

таърихи версияҳои NIGOH Family барои саҳифаи «Чӣ нав аст» (се забон).

### `app/core/security.py`

hash-и password, session-и web, муҳофизати route ва rate limit.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class RateLimiter` |  | Маълумоти `RateLimiter`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `RateLimiter.__init__()` |  | Маълумоти ёрирасони init-ро омода карда, ба caller бармегардонад. |
| `RateLimiter.is_rate_limited()` |  | is rate limited-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `hash_password()` |  | Password-ро бо scrypt ва salt-и ҷудогона hash мекунад. |
| `verify_password()` |  | Password-ро бо hash-и scrypt ё SHA-256-и кӯҳна муқоиса мекунад. |
| `create_session()` |  | Session token-и бехатар месозад ва дар хотира нигоҳ медорад. |
| `get_current_user()` |  | Корбари воридшударо аз cookie ё Authorization header муайян мекунад. |
| `require_auth()` |  | Route-ро танҳо барои корбари воридшуда иҷозат медиҳад. |
| `check_rate_limit()` |  | Ҳангоми зиёд шудани request-ҳо хатои HTTP 429 мебарорад. |

### `app/core/web_filter.py`

қоидаҳои филтри сайтҳо аз рӯи синну сол — сатҳҳо, санҷиши доменҳо ва ҳолати телефон.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `normalize_domain()` |  | Суроға ё доменро ба шакли `example.com` меорад; агар нодуруст бошад, None. |
| `normalize_blocked()` |  | Рӯйхати сайтҳоро тоза мекунад: домени дуруст, бе такрор, ҳадди аксар MAX_BLOCKED. |
| `load()` |  | Танзими филтри фарзандро аз база мехонад (ҳамеша бо ҳамаи калидҳо). |
| `save()` |  | Сатҳ ва рӯйхати сайтҳоро нигоҳ медорад ва танзими тозашударо бармегардонад. |
| `payload()` |  | Маълумоти филтр барои snapshot-и барнома: танзим ва ҳолати охирини телефон. |
| `report_state()` |  | Ҳолати филтрро аз телефони фарзанд сабт мекунад. |

### `app/crud/__init__.py`

амалиёти пойгоҳи додаҳо барои бахши `__init__`.

### `app/crud/crud_analytics.py`

амалиёти пойгоҳи додаҳо барои бахши `crud_analytics`.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `log_analytics_event()` |  | log омор event-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `_is_recent()` |  | Маълумоти ёрирасони is recent-ро омода карда, ба caller бармегардонад. |
| `_daily_series()` |  | Маълумоти ёрирасони рӯзона series-ро омода карда, ба caller бармегардонад. |
| `_top_apps()` |  | Маълумоти ёрирасони top app-ҳо-ро омода карда, ба caller бармегардонад. |
| `get_admin_dashboard_data()` |  | Омори воқеии сайт ва оиларо барои dashboard-и admin ҳисоб мекунад. |

### `app/crud/crud_bundle.py`

амалиёти пойгоҳи додаҳо барои бахши `crud_bundle`.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `canonical_json()` |  | Маълумоти ёрирасони canonical json-ро омода карда, ба caller бармегардонад. |
| `payload_checksum()` |  | Маълумоти ёрирасони payload checksum-ро омода карда, ба caller бармегардонад. |
| `default_bundle_payload()` |  | Маълумоти ёрирасони default bundle payload-ро омода карда, ба caller бармегардонад. |
| `ensure_initial_bundle()` |  | Маълумоти ёрирасони ensure initial bundle-ро омода карда, ба caller бармегардонад. |
| `list_after()` |  | Барои гирифтан ё санҷидани list after истифода мешавад. |
| `create_bundle()` |  | create bundle-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |

### `app/crud/crud_chat.py`

амалиёти пойгоҳи додаҳо барои бахши `crud_chat`.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `get_child_messages()` |  | Барои гирифтан ё санҷидани get фарзанд паёмҳо истифода мешавад. |
| `send_message()` |  | send паём-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |

### `app/crud/crud_child.py`

амалиёти пойгоҳи додаҳо барои бахши `crud_child`.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `ensure_default_child_apps()` |  | Маълумоти ёрирасони ensure default фарзанд app-ҳо-ро омода карда, ба caller бармегардонад. |
| `create_or_get_child_for_user()` |  | create or get фарзанд for корбар-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `get_child_for_user()` |  | Барои гирифтан ё санҷидани get фарзанд for корбар истифода мешавад. |
| `get_child_by_pairing_code()` |  | Барои гирифтан ё санҷидани get фарзанд by pairing code истифода мешавад. |
| `pair_child_with_parent()` |  | pairing фарзанд with parent-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `get_children_list()` |  | Барои гирифтан ё санҷидани get фарзандон list истифода мешавад. |
| `update_child_profile()` |  | update фарзанд профил-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `delete_child()` |  | delete фарзанд-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |

### `app/crud/crud_privacy.py`

нигоҳдории маҳдуди маълумот ва пок кардани таърихи фарзанд (махфият).

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `_utc_naive()` |  | Вақтро ба UTC-и бе минтақа табдил медиҳад (SQLite `CURRENT_TIMESTAMP` ҳамин тавр аст). |
| `prune_location_history()` |  | Нуқтаҳои макони фарзандро, ки аз LOCATION_RETENTION_DAYS кӯҳнаанд, нест мекунад. |
| `purge_child_history()` |  | Таърихи шахсии фарзандро нест мекунад: макон, чат, ҷойҳо, рӯйдодҳо, дархостҳо ва зангҳо. |
| `delete_child_data()` |  | Ҳамаи маълумоти фарзандро, аз ҷумла қоидаҳо ва вақти истифода, нест мекунад. |
| `anonymize_site_analytics()` |  | IP ва user-agent-ро дар сабтҳои омори аз ANALYTICS_RETENTION_DAYS кӯҳна пок мекунад. |

### `app/crud/crud_rules.py`

амалиёти пойгоҳи додаҳо барои бахши `crud_rules`.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `get_child_app_rules()` |  | Барои гирифтан ё санҷидани get фарзанд app қоидаҳо истифода мешавад. |
| `toggle_app_rule()` |  | toggle app қоида-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `set_app_rule_limit()` |  | set app қоида limit-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `count_blocked_threats()` |  | Барои гирифтан ё санҷидани count blocked threats истифода мешавад. |

### `app/crud/crud_user.py`

амалиёти пойгоҳи додаҳо барои бахши `crud_user`.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `get_user_by_email()` |  | Барои гирифтан ё санҷидани get корбар by email истифода мешавад. |
| `get_user_by_id()` |  | Барои гирифтан ё санҷидани get корбар by id истифода мешавад. |
| `create_user()` |  | create корбар-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `update_user_role()` |  | update корбар нақш-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `upsert_google_user()` |  | Ҳисоби Google-ро месозад ё маълумоти онро нав мекунад. |
| `get_registered_users()` |  | Барои гирифтан ё санҷидани get registered корбарон истифода мешавад. |


## Сервер — моделҳои база

### `app/models/__init__.py`

model-и SQLAlchemy барои маълумоти `__init__` ва табдили он ба ҷавоби API.

### `app/models/analytics.py`

model-и SQLAlchemy барои маълумоти `analytics` ва табдили он ба ҷавоби API.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class SiteAnalytics` |  | Сабти `SiteAnalytics`-ро дар model-и SQLAlchemy муаррифӣ мекунад. |
| `SiteAnalytics.to_dict()` |  | Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад. |

### `app/models/app_bundle.py`

model-и SQLAlchemy барои маълумоти `app_bundle` ва табдили он ба ҷавоби API.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class AppBundle` |  | Сабти `AppBundle`-ро дар model-и SQLAlchemy муаррифӣ мекунад. |
| `AppBundle.to_dict()` |  | Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад. |

### `app/models/app_rule.py`

model-и SQLAlchemy барои маълумоти `app_rule` ва табдили он ба ҷавоби API.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class AppRule` |  | Сабти `AppRule`-ро дар model-и SQLAlchemy муаррифӣ мекунад. |
| `AppRule.to_dict()` |  | Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад. |

### `app/models/app_usage.py`

model-и SQLAlchemy барои маълумоти `app_usage` ва табдили он ба ҷавоби API.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class AppUsageDaily` |  | Сабти `AppUsageDaily`-ро дар model-и SQLAlchemy муаррифӣ мекунад. |
| `AppUsageDaily.to_dict()` |  | Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад. |

### `app/models/chat.py`

model-и SQLAlchemy барои маълумоти `chat` ва табдили он ба ҷавоби API.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class ChatMessage` |  | Сабти `ChatMessage`-ро дар model-и SQLAlchemy муаррифӣ мекунад. |
| `ChatMessage.to_dict()` |  | Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад. |

### `app/models/child.py`

model-и SQLAlchemy барои маълумоти `child` ва табдили он ба ҷавоби API.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class Child` |  | Сабти `Child`-ро дар model-и SQLAlchemy муаррифӣ мекунад. |
| `Child.to_dict()` |  | Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад. |

### `app/models/contact.py`

model-и SQLAlchemy барои паёмҳое, ки аз формаи «Тамос бо мо»-и сайт меоянд.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class ContactMessage` |  | Як паёми формаи тамос: кӣ навишт, мавзӯъ, матн ва ҳолати хондан. |
| `ContactMessage.to_dict()` |  | Сабтро ба dict барои панели админ табдил медиҳад. |

### `app/models/email_code.py`

model-и SQLAlchemy барои рамзҳои якдафъаинае, ки ба почта фиристода мешаванд.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class EmailCode` |  | Як рамзи почта: ба кадом почта, барои чӣ, hash-и рамз, мӯҳлат ва кӯшишҳо. |

### `app/models/extension_request.py`

model-и SQLAlchemy барои маълумоти `extension_request` ва табдили он ба ҷавоби API.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class AppExtensionRequest` |  | Сабти `AppExtensionRequest`-ро дар model-и SQLAlchemy муаррифӣ мекунад. |
| `AppExtensionRequest.to_dict()` |  | Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад. |

### `app/models/family_extras.py`

model-и SQLAlchemy барои маълумоти `family_extras` ва табдили он ба ҷавоби API.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class LocationPoint` |  | Сабти `LocationPoint`-ро дар model-и SQLAlchemy муаррифӣ мекунад. |
| `LocationPoint.to_dict()` |  | Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад. |
| `class SafePlace` |  | Доираи номдори бехатарро, мисли хона ё мактаб, нигоҳ медорад. |
| `SafePlace.to_dict()` |  | Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад. |
| `class FamilyEvent` |  | Сабти `FamilyEvent`-ро дар model-и SQLAlchemy муаррифӣ мекунад. |
| `FamilyEvent.to_dict()` |  | Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад. |
| `class CallSession` |  | Сабти `CallSession`-ро дар model-и SQLAlchemy муаррифӣ мекунад. |
| `CallSession.to_dict()` |  | Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад. |
| `class CallSignal` |  | Сабти `CallSignal`-ро дар model-и SQLAlchemy муаррифӣ мекунад. |
| `CallSignal.to_dict()` |  | Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад. |

### `app/models/mobile_session.py`

model-и SQLAlchemy барои маълумоти `mobile_session` ва табдили он ба ҷавоби API.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class MobileSession` |  | Сабти `MobileSession`-ро дар model-и SQLAlchemy муаррифӣ мекунад. |

### `app/models/review.py`

model-и SQLAlchemy барои маълумоти `review` ва табдили он ба ҷавоби API.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class Review` |  | Сабти `Review`-ро дар model-и SQLAlchemy муаррифӣ мекунад. |
| `Review.to_dict()` |  | Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад. |

### `app/models/user.py`

model-и SQLAlchemy барои маълумоти `user` ва табдили он ба ҷавоби API.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class User` |  | Сабти `User`-ро дар model-и SQLAlchemy муаррифӣ мекунад. |
| `User.to_dict()` |  | Сабти model-ро ба dict-и муносиб барои ҷавоби API табдил медиҳад. |

### `app/db/base.py`

пойгоҳи умумии declarative-и SQLAlchemy барои model-ҳои система.

### `app/db/init_db.py`

сохтани ҷадвалҳо, migration ва ҳисоби admin.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `init_db()` |  | Ҷадвалҳоро месозад, migration-ро татбиқ мекунад ва admin-ро омода месозад. |

### `app/db/session.py`

танзими SQLite ва session-и пойгоҳи додаҳо барои ҳар request.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `get_db()` |  | Барои request session-и SQLAlchemy медиҳад ва баъд онро мебандад. |

### `app/schemas/__init__.py`

schema-ҳои Pydantic барои санҷиши payload-ҳои `__init__`.

### `app/schemas/auth.py`

schema-ҳои Pydantic барои санҷиши payload-ҳои `auth`.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class UserRegister` |  | Маълумоти `UserRegister`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class UserLogin` |  | Маълумоти `UserLogin`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class GoogleAuthRequest` |  | Маълумоти `GoogleAuthRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |

### `app/schemas/mobile.py`

schema-ҳои Pydantic барои санҷиши payload-ҳои `mobile`.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class RoleSelectRequest` |  | Маълумоти `RoleSelectRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class ChildCreateRequest` |  | Маълумоти `ChildCreateRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class ChildProfileSetupRequest` |  | Маълумоти `ChildProfileSetupRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class PairScanRequest` |  | Маълумоти `PairScanRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class PairRequest` |  | Маълумоти `PairRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class AppRuleToggleRequest` |  | Маълумоти `AppRuleToggleRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class AppLimitRequest` |  | Маълумоти `AppLimitRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class AppSchedule` |  | Маълумоти `AppSchedule`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `AppSchedule.validate_time()` |  | Барои гирифтан ё санҷидани validate вақт истифода мешавад. |
| `AppSchedule.validate_weekdays()` |  | Барои гирифтан ё санҷидани validate weekdays истифода мешавад. |
| `class AppControlUpdateRequest` |  | Маълумоти `AppControlUpdateRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class UsageReportItem` |  | Маълумоти `UsageReportItem`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class UsageReportRequest` |  | Маълумоти `UsageReportRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class TimeExtensionRequest` |  | Маълумоти `TimeExtensionRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class AppBundleCreateRequest` |  | Маълумоти `AppBundleCreateRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class AdultFilterToggleRequest` |  | Маълумоти `AdultFilterToggleRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class LocationUpdateRequest` |  | Маълумоти `LocationUpdateRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class SendChatMessageRequest` |  | Маълумоти `SendChatMessageRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class InstalledAppReportItem` |  | Маълумоти `InstalledAppReportItem`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class InstalledAppsSyncRequest` |  | Маълумоти `InstalledAppsSyncRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class MobilePairCodeRequest` |  | Маълумоти `MobilePairCodeRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class MobilePairRequest` |  | Маълумоти `MobilePairRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class MobileLinkExistingRequest` |  | Маълумоти `MobileLinkExistingRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class MobileLocationRequest` |  | Маълумоти `MobileLocationRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |
| `class MobileChatRequest` |  | Маълумоти `MobileChatRequest`-ро барои санҷиш ва коркарди request нигоҳ медорад. |


## Сервер — оғоз

### `app/main.py`

ҷамъ кардани FastAPI app, middleware, startup ва ҳамаи router-ҳо.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `_log_page_view()` |  | Як боздиди саҳифаро бо сессияи алоҳидаи база сабт мекунад (дар замина). |
| `_attach_background()` |  | Вазифаи заминаро ба ҷавоб мепайвандад, бе он ки вазифаи мавҷударо гум кунад. |
| `_origin_allowed()` |  | Агар Origin набошад (барнома, curl) ё аз ҳамин сайт бошад, True. |
| `security_and_analytics_middleware()` |  | Маълумоти ёрирасони security and омор middleware-ро омода карда, ба caller бармегардонад. |
| `on_startup()` |  | on startup-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `localized_http_exception()` |  | Маълумоти ёрирасони localized http exception-ро омода карда, ба caller бармегардонад. |


## Скриптҳо

### `scripts/cleanup_demo_data.py`

пешнамоиш ва поксозии бехатари demo data-и кӯҳна.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `_marks()` |  | Маълумоти ёрирасони marks-ро омода карда, ба caller бармегардонад. |
| `main()` |  | main-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |

### `scripts/cleanup_users_once.py`

поксозии яккаратаи ҳисобҳо ва додаҳои вобаста.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `counts()` |  | Маълумоти ёрирасони counts-ро омода карда, ба caller бармегардонад. |
| `main()` |  | Ҷараёни асосии main-ро иҷро карда, хатоҳоро назорат мекунад. |

### `scripts/deploy_production.py`

deploy кардани website, API ва APK-и release ба production.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `load_env_file()` |  | Барои гирифтан ё санҷидани load env file истифода мешавад. |
| `find_apksigner()` |  | Барои гирифтан ё санҷидани find apksigner истифода мешавад. |
| `verify_apk_signature()` |  | Барои гирифтан ё санҷидани verify apk signature истифода мешавад. |
| `check_release_certificate()` |  | Месанҷад, ки APK маҳз бо сертификати релизии NIGOH имзо шудааст. |
| `find_jdk()` |  | Барои гирифтан ё санҷидани find jdk истифода мешавад. |
| `build_release_apk()` |  | Маълумоти ёрирасони build release apk-ро омода карда, ба caller бармегардонад. |
| `prepare_apk()` |  | Маълумоти ёрирасони prepare apk-ро омода карда, ба caller бармегардонад. |
| `askpass_env()` |  | askpass env-ро коркард карда, тағйиротро дар пойгоҳи додаҳо сабт мекунад. |
| `run()` |  | Маълумоти ёрирасони run-ро омода карда, ба caller бармегардонад. |
| `deploy()` |  | Ҷараёни асосии deploy-ро иҷро карда, хатоҳоро назорат мекунад. |

### `scripts/gen_function_docs.py`

docs/FUNCTIONS.md-ро аз худи код месозад — ҳар файл, ҳар функсия ва синф бо шарҳи тоҷикии он.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `_first_line()` |  | Сатри аввали шарҳ, бе фосилаҳои зиёдатӣ ва бе аломати «\|» (барои ҷадвал). |
| `_files()` |  | Ҳамаи файлҳои навъи додашударо дар роҳҳо бо тартиби алифбо бармегардонад. |
| `_router_prefix()` |  | Агар файл `router = APIRouter(prefix="…")` дошта бошад, prefix-ро бармегардонад. |
| `_route()` |  | Барои функсияи FastAPI «GET /path»-ро аз декоратор мегирад (бо prefix-и router). |
| `python_entries()` |  | Шарҳи файл ва рӯйхати (ном, роут, шарҳ)-и функсияҳо ва синфҳои Python. |
| `_doc_block()` |  | Шарҳҳои пай дар пай пеш аз сатри i-ро ҷамъ мекунад (/// ё /** … */). |
| `_source_header()` |  | Сатри «// Файл: …»-ро дар аввали файли Dart ё Kotlin меёбад. |
| `dart_entries()` |  | Функсия ва синфҳои Dart, ки пеш аз онҳо шарҳи /// ҳаст. |
| `kotlin_entries()` |  | Функсия ва синфҳои Kotlin, ки пеш аз онҳо шарҳи KDoc ҳаст. |
| `build()` |  | Матни пурраи docs/FUNCTIONS.md-ро месозад. |
| `main()` |  | Файлро менависад ё бо --check месанҷад, ки он нав аст. |


## Санҷишҳои сервер

### `tests/test_apple_auth.py`

санҷишҳои автоматии `test_apple_auth` ва сенарияҳои ёрирасони он.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `check()` |  | Натиҷаи санҷишро сабт карда, нокомиро барои ҷамъбаст нигоҳ медорад. |
| `class _Key` |  | Муҳити ёрирасони `_Key`-ро барои санҷиш фароҳам мекунад. |
| `class _FakeJwks` |  | Муҳити ёрирасони `_FakeJwks`-ро барои санҷиш фароҳам мекунад. |
| `_FakeJwks.get_signing_key_from_jwt()` |  | Рафтори `get_signing_key_from_jwt`-ро дар муҳити санҷишӣ месанҷад. |
| `apple_token()` |  | Рафтори `apple_token`-ро дар муҳити санҷишӣ месанҷад. |
| `class _Resp` |  | Муҳити ёрирасони `_Resp`-ро барои санҷиш фароҳам мекунад. |
| `_Resp.__init__()` |  | Рафтори `__init__`-ро дар муҳити санҷишӣ месанҷад. |
| `_Resp.json()` |  | Рафтори `json`-ро дар муҳити санҷишӣ месанҷад. |
| `fake_post()` |  | Рафтори `fake_post`-ро дар муҳити санҷишӣ месанҷад. |
| `login_and_get_state()` |  | Рафтори `login_and_get_state`-ро дар муҳити санҷишӣ месанҷад. |
| `main()` |  | Ҳамаи сенарияҳои санҷиширо иҷро карда, додаҳои муваққатиро пок мекунад. |

### `tests/test_bundle_sync.py`

санҷишҳои автоматии `test_bundle_sync` ва сенарияҳои ёрирасони он.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class BundleSyncTests` |  | Муҳити ёрирасони `BundleSyncTests`-ро барои санҷиш фароҳам мекунад. |
| `BundleSyncTests.test_checksum_is_stable_for_key_order()` |  | Рафтори `test_checksum_is_stable_for_key_order`-ро дар муҳити санҷишӣ месанҷад. |
| `BundleSyncTests.test_sync_returns_patch_then_304()` |  | Рафтори `test_sync_returns_patch_then_304`-ро дар муҳити санҷишӣ месанҷад. |

### `tests/test_contact.py`

санҷиши формаи «Тамос бо мо» — се забон, санҷиши майдонҳо, спам ва панели админ.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `check()` |  | Як шартро месанҷад; хато бошад, санҷиш қатъ мешавад. |
| `override_db()` |  | Базаи санҷишӣ дар хотираро ба ҷои базаи воқеӣ медиҳад. |
| `run_checks()` |  | Ҳамаи сенарияҳои формаи тамосро иҷро мекунад. |

### `tests/test_github_auth.py`

санҷишҳои автоматии `test_github_auth` ва сенарияҳои ёрирасони он.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `check()` |  | Натиҷаи санҷишро сабт карда, нокомиро барои ҷамъбаст нигоҳ медорад. |
| `class _Resp` |  | Муҳити ёрирасони `_Resp`-ро барои санҷиш фароҳам мекунад. |
| `_Resp.__init__()` |  | Рафтори `__init__`-ро дар муҳити санҷишӣ месанҷад. |
| `_Resp.json()` |  | Рафтори `json`-ро дар муҳити санҷишӣ месанҷад. |
| `fake_post()` |  | Рафтори `fake_post`-ро дар муҳити санҷишӣ месанҷад. |
| `fake_get()` |  | Рафтори `fake_get`-ро дар муҳити санҷишӣ месанҷад. |
| `set_github()` |  | Рафтори `set_github`-ро дар муҳити санҷишӣ месанҷад. |
| `start_web()` |  | Рафтори `start_web`-ро дар муҳити санҷишӣ месанҷад. |
| `main()` |  | Ҳамаи сенарияҳои санҷиширо иҷро карда, додаҳои муваққатиро пок мекунад. |

### `tests/test_google_oauth.py`

санҷишҳои автоматии `test_google_oauth` ва сенарияҳои ёрирасони он.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class NoRedirect` |  | Муҳити ёрирасони `NoRedirect`-ро барои санҷиш фароҳам мекунад. |
| `NoRedirect.redirect_request()` |  | Рафтори `redirect_request`-ро дар муҳити санҷишӣ месанҷад. |
| `open_without_redirects()` |  | Рафтори `open_without_redirects`-ро дар муҳити санҷишӣ месанҷад. |
| `start_server()` |  | Рафтори `start_server`-ро дар муҳити санҷишӣ месанҷад. |
| `wait_for_server()` |  | Рафтори `wait_for_server`-ро дар муҳити санҷишӣ месанҷад. |
| `run_checks()` |  | Ҳамаи сенарияҳои санҷиширо иҷро карда, додаҳои муваққатиро пок мекунад. |

### `tests/test_hardening.py`

санҷишҳои автоматии `test_hardening` ва сенарияҳои ёрирасони он.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `start_server()` |  | Рафтори `start_server`-ро дар муҳити санҷишӣ месанҷад. |
| `get_json()` |  | Рафтори `get_json`-ро дар муҳити санҷишӣ месанҷад. |
| `run_checks()` |  | Ҳамаи сенарияҳои санҷиширо иҷро карда, додаҳои муваққатиро пок мекунад. |

### `tests/test_mobile_v3.py`

санҷишҳои автоматии `test_mobile_v3` ва сенарияҳои ёрирасони он.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `check()` |  | Натиҷаи санҷишро сабт карда, нокомиро барои ҷамъбаст нигоҳ медорад. |
| `main()` |  | Ҳамаи сенарияҳои санҷиширо иҷро карда, додаҳои муваққатиро пок мекунад. |

### `tests/test_otp.py`

санҷиши ҳимояи дуқабата — TOTP (векторҳои RFC 6238), рамзҳои эҳтиётӣ, қулф, чиптаҳо,

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `_utcnow()` |  | Вақти ҳозираи UTC бе минтақа (мисли SQLite). |
| `check()` |  | Як шартро месанҷад; хато бошад, санҷиш қатъ мешавад. |
| `override_db()` |  | Базаи санҷишӣ дар хотира. |
| `make_user()` |  | Корбари навро бо парол месозад. |
| `code_for()` |  | Рамзи TOTP-и ҳозира (ё қадами ҳамсоя). |
| `unit_checks()` |  | Функсияҳои тозаи TOTP аз рӯи RFC 6238 (SHA1, 6 рақами охир). |
| `api_checks()` |  | Аз фаъол кардан то қулф тавассути API-и сайт ва барнома. |

### `tests/test_pairing.py`

санҷиши ҳимояи рамзи пайвастшавӣ — мӯҳлати 15 дақиқа, навсозии худкор ва маҳдудияти кӯшишҳо.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `check()` |  | Як шартро месанҷад; хато бошад, санҷиш қатъ мешавад. |
| `_utcnow()` |  | Вақти ҳозираи UTC бе минтақа. |
| `override_db()` |  | Базаи санҷишӣ дар хотира. |
| `run_checks()` |  | Сенарияҳои пайвастшавӣ бо мӯҳлат ва маҳдудият. |

### `tests/test_perf_middleware.py`

санҷишҳои суръати middleware — омор дар замина ва кэши файлҳои static.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `check()` |  | Як шартро месанҷад ва натиҷаро чоп мекунад; хато бошад, санҷиш қатъ мешавад. |
| `run_checks()` |  | Ҳамаи сенарияҳоро бе навиштан ба базаи воқеӣ иҷро мекунад. |

### `tests/test_place_rules.py`

санҷиши қоидаҳои барномаҳо аз рӯи ҷой ва огоҳии «расид / баромад».

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `check()` |  | Як шартро месанҷад; хато бошад, санҷиш қатъ мешавад. |
| `north()` |  | Нуқтае, ки ин қадар метр ба шимоли мактаб аст. |
| `unit_checks()` |  | Функсияҳои тоза: тозакунии қоидаҳо, масофа ва фосилаи эҳтиётӣ. |
| `override_db()` |  | Базаи санҷишӣ дар хотира. |
| `api_checks()` |  | Аз сохтани ҷой то огоҳиҳо тавассути API. |

### `tests/test_privacy_retention.py`

санҷиши нигоҳдории маҳдуди таърихи макон ва пок кардани маълумоти фарзанд.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `_utcnow()` |  | Вақти ҳозираи UTC бе минтақа (мисли SQLite). |
| `check()` |  | Як шартро месанҷад; хато бошад, санҷиш қатъ мешавад. |
| `fresh_db()` |  | Базаи нави SQLite дар хотира бо ҳамаи ҷадвалҳо месозад. |
| `seed()` |  | Як фарзанд бо ҳамаи намудҳои маълумот месозад. |
| `count()` |  | Шумораи сатрҳои model-ро барои фарзанд бармегардонад. |
| `run_checks()` |  | Ҳамаи сенарияҳои махфиятро иҷро мекунад. |

### `tests/test_security_headers.py`

санҷиши сарлавҳаҳои амниятӣ — CSP, ҳимоя аз CSRF (Origin), no-store ва сиёсати иҷозатҳо.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `check()` |  | Як шартро месанҷад; хато бошад, санҷиш қатъ мешавад. |
| `run_checks()` |  | Ҳамаи сенарияҳоро бе навиштан ба база иҷро мекунад. |

### `tests/test_site_pages.py`

санҷиши ҳамаи саҳифаҳои сайт бо се забон — ҷавоб, сарлавҳа, hreflang, footer ва sitemap.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `check()` |  | Як шартро месанҷад; хато бошад, санҷиш қатъ мешавад. |
| `url()` |  | Роҳи саҳифаро барои забон месозад. |
| `run_checks()` |  | Ҳар саҳифаро бо ҳар забон месанҷад. |

### `tests/test_web_filter.py`

санҷиши филтри сайтҳо аз рӯи синну сол — доменҳо, танзими волидайн, ҳолати телефон ва огоҳӣ.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `check()` |  | Як шартро месанҷад; хато бошад, санҷиш қатъ мешавад. |
| `unit_checks()` |  | Функсияҳои тоза: доменҳо, рӯйхат, сатҳҳо. |
| `override_db()` |  | Базаи санҷишӣ дар хотира. |
| `api_checks()` |  | Аз сабти ном то огоҳии волидайн тавассути API. |


## Барнома — асос (core)

### `mobile/lib/core/api.dart`

муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳо.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `nigohApiBaseUrl` |  | Қимати nigohApiBaseUrl-ро барои муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳо нигоҳ медорад. |
| `bool` |  | Қимати ҳисобшудаи unauthorized-ро аз ҳолати ҷорӣ бармегардонад. |
| `toString()` |  | Намоиши матнии ApiException-ро барои log бармегардонад. |
| `class AppleSignInConfig` |  | AppleSignInConfig додаҳо ва рафтори API ва session-ро ифода мекунад. |
| `AppleSignInConfig.fromJson()` |  | AppleSignInConfig-ро аз JSON-и сервер месозад. |
| `class GitHubSignInConfig` |  | GitHubSignInConfig додаҳо ва рафтори API ва session-ро ифода мекунад. |
| `GitHubSignInConfig.fromJson()` |  | GitHubSignInConfig-ро аз JSON-и сервер месозад. |
| `class NigohApi` |  | NigohApi додаҳо ва рафтори API ва session-ро ифода мекунад. |
| `Function()` |  | Function мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `_send()` |  | send дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `_detail()` |  | detail мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `register()` |  | register дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `login()` |  | login дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `google()` |  | google экран, dialog ё танзимоти мувофиқро мекушояд. |
| `appleConfig()` |  | appleConfig мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `signInWithApple()` |  | signInWithApple мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `otpConfig()` |  | Кадом навъҳои ҳимояи дуқабата дар сервер фаъоланд (Authenticator, рамз ба почта). |
| `loginOtp()` |  | Қадами дуюми воридшавӣ: чипта аз login ва рамзи 6-рақама ё рамзи эҳтиётӣ. |
| `requestEmailCode()` |  | Рамзи воридшавиро ба почта мефиристад. |
| `verifyEmailCode()` |  | Рамзи почтаро месанҷад: token ё otp_required бармегардонад. |
| `totpStatus()` |  | Ҳолати Authenticator-и ҳисоби ҷорӣ. |
| `totpSetup()` |  | Калиди навро месозад: secret, uri ва QR. |
| `totpConfirm()` |  | Аввалин рамзро месанҷад ва рамзҳои эҳтиётиро бармегардонад. |
| `totpDisable()` |  | Authenticator-ро бо рамз хомӯш мекунад. |
| `totpRecovery()` |  | Рамзҳои эҳтиётии нав. |
| `githubConfig()` |  | githubConfig мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `signInWithGitHub()` |  | signInWithGitHub мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `logout()` |  | logout дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `me()` |  | me мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `updateMe()` |  | updateMe ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `uploadAvatar()` |  | uploadAvatar додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад. |
| `deleteAvatar()` |  | deleteAvatar маълумотро ҳазф карда, ҳолати вобастаро нав мекунад. |
| `fileUrl()` |  | fileUrl мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `snapshot()` |  | snapshot мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `createPairCode()` |  | createPairCode мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `pair()` |  | pair дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `unlinkChild()` |  | unlinkChild маълумотро ҳазф карда, ҳолати вобастаро нав мекунад. |
| `syncApps()` |  | syncApps додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад. |
| `updateRule()` |  | updateRule ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `syncLocation()` |  | syncLocation додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад. |
| `chat()` |  | chat мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `sendChat()` |  | sendChat дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `markChatRead()` |  | markChatRead дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `locationHistory()` |  | locationHistory мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `usageHistory()` |  | usageHistory мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `requestTime()` |  | requestTime иҷозат ё маълумоти лозимро дархост мекунад. |
| `timeRequests()` |  | timeRequests мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `decideTimeRequest()` |  | decideTimeRequest дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `giveBonus()` |  | giveBonus дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `setBedtime()` |  | setBedtime ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `safePlaces()` |  | safePlaces мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `addSafePlace()` |  | addSafePlace мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `updateSafePlace()` |  | Ном, радиус ё қоидаҳои ҷойро иваз мекунад. |
| `deleteSafePlace()` |  | deleteSafePlace маълумотро ҳазф карда, ҳолати вобастаро нав мекунад. |
| `_list()` |  | list мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `setStudyMode()` |  | setStudyMode ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `setWebFilter()` |  | Сатҳи филтри сайтҳо ва рӯйхати сайтҳои манъшударо барои фарзанд нигоҳ медорад. |
| `reportWebFilterState()` |  | Телефони фарзанд хабар медиҳад, ки филтр кор мекунад ё не. |
| `events()` |  | events мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `callConfig()` |  | callConfig мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `startCall()` |  | startCall раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад. |
| `callStatus()` |  | callStatus мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `acceptCall()` |  | acceptCall мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `declineCall()` |  | declineCall раванди фаъолро қатъ карда, захираҳои онро озод мекунад. |
| `endCall()` |  | endCall раванди фаъолро қатъ карда, захираҳои онро озод мекунад. |
| `sendSignal()` |  | sendSignal дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `callSignals()` |  | callSignals мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |
| `version()` |  | version мантиқи зарурии муштарии REST-и NIGOH барои воридшавӣ, оила, қоидаҳо, chat, ҷойгиршавӣ ва зангҳоро иҷро мекунад. |

### `mobile/lib/core/app_categories.dart`

гурӯҳбандии барномаҳо аз рӯи package name.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `enum AppCategory` |  | Ҳолатҳо ё навъҳои имконпазири гурӯҳбандии барномаҳо аз рӯи package name-ро муайян мекунад. |
| `label` |  | Қимати label-ро барои гурӯҳбандии барномаҳо аз рӯи package name нигоҳ медорад. |
| `pluralLower` |  | Қимати pluralLower-ро барои гурӯҳбандии барномаҳо аз рӯи package name нигоҳ медорад. |
| `classifyApp()` |  | classifyApp мантиқи зарурии гурӯҳбандии барномаҳо аз рӯи package name-ро иҷро мекунад. |
| `any()` |  | any мантиқи зарурии гурӯҳбандии барномаҳо аз рӯи package name-ро иҷро мекунад. |
| `categoryOf()` |  | categoryOf мантиқи зарурии гурӯҳбандии барномаҳо аз рӯи package name-ро иҷро мекунад. |
| `studyBlockedCategories` |  | Қимати studyBlockedCategories-ро барои гурӯҳбандии барномаҳо аз рӯи package name нигоҳ медорад. |
| `isEssentialApp()` |  | isEssentialApp иҷро шудани шарти вобастаро муайян мекунад. |

### `mobile/lib/core/bundle_manager.dart`

зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдаст.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class BundleHttpResponse` |  | Додаҳо ва рафтори марбут ба зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро ифода мекунад. |
| `class BundleSyncResult` |  | Додаҳо ва рафтори марбут ба зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро ифода мекунад. |
| `int` |  | Қимати ҳисобшудаи currentBundleVersion-ро аз ҳолати ҷорӣ бармегардонад. |
| `uiOverrides` |  | Қимати ҳисобшудаи uiOverrides-ро аз ҳолати ҷорӣ бармегардонад. |
| `cachedRulesTemplate` |  | Қимати ҳисобшудаи cachedRulesTemplate-ро аз ҳолати ҷорӣ бармегардонад. |
| `text()` |  | text мантиқи зарурии зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро иҷро мекунад. |
| `visible()` |  | visible мантиқи зарурии зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро иҷро мекунад. |
| `ruleInt()` |  | ruleInt мантиқи зарурии зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро иҷро мекунад. |
| `ruleString()` |  | ruleString мантиқи зарурии зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро иҷро мекунад. |
| `int` |  | Қимати ҳисобшудаи defaultDailyLimitMinutes-ро аз ҳолати ҷорӣ бармегардонад. |
| `primaryColor` |  | Қимати ҳисобшудаи primaryColor-ро аз ҳолати ҷорӣ бармегардонад. |
| `secondaryColor` |  | Қимати ҳисобшудаи secondaryColor-ро аз ҳолати ҷорӣ бармегардонад. |
| `backgroundColor` |  | Қимати ҳисобшудаи backgroundColor-ро аз ҳолати ҷорӣ бармегардонад. |
| `surfaceColor` |  | Қимати ҳисобшудаи surfaceColor-ро аз ҳолати ҷорӣ бармегардонад. |
| `accentColor` |  | Қимати ҳисобшудаи accentColor-ро аз ҳолати ҷорӣ бармегардонад. |
| `color()` |  | color қисми мувофиқи интерфейсро месозад. |
| `loadLocal()` |  | loadLocal додаҳоро мехонад ва ҳолати экранро нав мекунад. |
| `sync()` |  | sync додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад. |
| `checksumFor()` |  | checksumFor дурустӣ ва шартҳои зарурии додаҳоро месанҷад. |
| `_persist()` |  | persist тағйиротро барои истифодаи баъдӣ нигоҳ медорад. |
| `_fetch()` |  | fetch додаҳоро мехонад ва ҳолати экранро нав мекунад. |
| `_map()` |  | map мантиқи зарурии зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро иҷро мекунад. |
| `_deepCopy()` |  | deepCopy мантиқи зарурии зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро иҷро мекунад. |
| `_merge()` |  | merge мантиқи зарурии зеркашӣ, санҷиш ва нигоҳдории bundle-и танзимоти дурдастро иҷро мекунад. |
| `_validateState()` |  | validateState дурустӣ ва шартҳои зарурии додаҳоро месанҷад. |
| `_canonicalJson()` |  | canonicalJson иҷро шудани шарти вобастаро муайян мекунад. |
| `normalize()` |  | normalize додаҳоро ба шакли барои истифода мувофиқ табдил медиҳад. |

### `mobile/lib/core/child_profile.dart`

профили маҳаллии фарзанд пеш аз пайвастшавӣ.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class ChildProfile` |  | Додаҳо ва рафтори марбут ба профили маҳаллии фарзанд пеш аз пайвастшавӣро ифода мекунад. |
| `load()` |  | load додаҳои child_profile-ро мехонад ва ҳолати ChildProfile-ро нав мекунад. |
| `save()` |  | getInstance тағйироти child_profile-ро барои истифодаи баъдӣ нигоҳ медорад. |
| `clear()` |  | clear маълумотро ҳазф карда, ҳолати вобастаро нав мекунад. |

### `mobile/lib/core/geo.dart`

ҳисобҳои ҷуғрофӣ — масофа байни нуқтаҳо ва муайян кардани ҷойи бехатаре, ки фарзанд дар он аст.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `placeLeaveMarginMeters` |  | Баромадан аз ҷой танҳо пас аз ин қадар метр берун аз радиус ҳисоб мешавад (мисли сервер), то GPS дар канори ҷой «дохил/берун»-и бепоён надиҳад. |
| `placeMaxAccuracyMeters` |  | Нуқтаҳое, ки дақиқиашон аз ин бадтар аст, ҷойро иваз намекунанд. |
| `distanceMeters()` |  | Масофаи байни ду нуқта бо метр (формулаи haversine). |
| `rad()` |  | Дараҷаро ба радиан табдил медиҳад. |
| `placeContaining()` |  | Наздиктарин ҷойе, ки нуқта дар радиуси он аст; агар нест — null. |
| `placeAt()` |  | Ҷойи ҳозираи фарзанд бо фосилаи эҳтиётӣ: агар ӯ аллакай дар [currentId] бошад, то [placeLeaveMarginMeters] берун аз радиус ҳоло ҳам дар ҳамон ҷой ҳисоб мешавад. |

### `mobile/lib/core/home_target.dart`

интихоби бахши хонагӣ ҳангоми кушодани notification.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class HomeTarget` |  | Додаҳо ва рафтори марбут ба интихоби бахши хонагӣ ҳангоми кушодани notification-ро ифода мекунад. |
| `forEvent()` |  | forEvent мантиқи зарурии интихоби бахши хонагӣ ҳангоми кушодани notification-ро иҷро мекунад. |
| `operator` |  | Ду target-ро аз рӯи навъ ва фарзанди интихобшуда муқоиса мекунад. |
| `int` |  | Қимати ҳисобшудаи hashCode-ро аз ҳолати ҷорӣ бармегардонад. |
| `toString()` |  | Намоиши матнии HomeTarget-ро барои log бармегардонад. |
| `homeTarget` |  | Қимати homeTarget-ро барои интихоби бахши хонагӣ ҳангоми кушодани notification нигоҳ медорад. |

### `mobile/lib/core/models.dart`

model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣ.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class AppSchedule` |  | AppSchedule додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад. |
| `AppSchedule.fromJson()` |  | AppSchedule-ро аз JSON-и сервер месозад. |
| `toJson()` |  | Объектро ба сохтори JSON барои API табдил медиҳад. |
| `class ChildApp` |  | ChildApp додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад. |
| `int` |  | Қимати effectiveLimitMinutes-ро барои model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣ нигоҳ медорад. |
| `bool` |  | Қимати isNew-ро барои model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣ нигоҳ медорад. |
| `ChildApp.fromJson()` |  | ChildApp-ро аз JSON-и сервер месозад. |
| `toNativeRule()` |  | toNativeRule мантиқи зарурии model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣро иҷро мекунад. |
| `class ChildLocation` |  | ChildLocation додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад. |
| `fromJson()` |  | Объектро аз ҷавоби JSON-и API месозад. |
| `bool` |  | Қимати online-ро барои model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣ нигоҳ медорад. |
| `class FamilyChild` |  | FamilyChild додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад. |
| `List` |  | Ҷойҳои бехатар бо қоидаҳо (дар snapshot меоянд; телефон онҳоро бе интернет иҷро мекунад). |
| `int` |  | Қимати ҳисобшудаи newAppsCount-ро аз ҳолати ҷорӣ бармегардонад. |
| `bool` |  | Қимати ҳисобшудаи online-ро аз ҳолати ҷорӣ бармегардонад. |
| `int` |  | Қимати ҳисобшудаи blockedCount-ро аз ҳолати ҷорӣ бармегардонад. |
| `int` |  | Қимати ҳисобшудаи usageMinutesToday-ро аз ҳолати ҷорӣ бармегардонад. |
| `FamilyChild.fromJson()` |  | FamilyChild-ро аз JSON-и сервер месозад. |
| `class ChatMessage` |  | ChatMessage додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад. |
| `ChatMessage.fromJson()` |  | ChatMessage-ро аз JSON-и сервер месозад. |
| `class Bedtime` |  | Bedtime додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад. |
| `Bedtime.fromJson()` |  | Bedtime-ро аз JSON-и сервер месозад. |
| `toJson()` |  | Объектро ба сохтори JSON барои API табдил медиҳад. |
| `activeAt()` |  | activeAt мантиқи зарурии model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣро иҷро мекунад. |
| `class TimeRequest` |  | TimeRequest додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад. |
| `TimeRequest.fromJson()` |  | TimeRequest-ро аз JSON-и сервер месозад. |
| `class PlaceAppRule` |  | Қоидаи як барнома дар як ҷой: баста, бо лимит ё ҳамеша кушода. |
| `fromJson()` |  | Аз JSON-и сервер; навъи номаълум — null. |
| `toJson()` |  | Барои фиристодан ба сервер. |
| `operator` |  | Ду қоида баробаранд, агар навъ ва дақиқаҳо як бошанд. |
| `int` |  | Hash-и мувофиқ бо ==. |
| `class SafePlace` |  | SafePlace додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад. |
| `Map` |  | Қоидаҳои барномаҳо дар ин ҷой: package → қоида. |
| `SafePlace.fromJson()` |  | SafePlace-ро аз JSON-и сервер месозад. |
| `copyWith()` |  | Нусхаи ҷой бо қоидаҳои нав. |
| `class StudyMode` |  | StudyMode додаҳо ва рафтори model-ҳои сервер-ро ифода мекунад. |
| `StudyMode.fromJson()` |  | StudyMode-ро аз JSON-и сервер месозад. |
| `toJson()` |  | Объектро ба сохтори JSON барои API табдил медиҳад. |
| `activeAt()` |  | activeAt мантиқи зарурии model-ҳои додаҳои фарзанд, қоидаҳо, chat ва ҷойгиршавӣро иҷро мекунад. |
| `class WebFilter` |  | Филтри сайтҳо: сатҳ (off, kids — то 12 сола, teen — 13–17 сола), сайтҳое, ки волидайн дастӣ бастанд, ва ҳолате, ки телефони фарзанд охирин бор хабар дод. |
| `stateActive` |  | Ҳолатҳое, ки телефони фарзанд хабар медиҳад. |
| `bool` |  | Филтр аз ҷониби волидайн фаъол карда шудааст. |
| `suggestedLevel()` |  | Сатҳи пешниҳодшуда барои синну сол: то 12 — kids, 13–17 — teen, калонтар — off. |
| `WebFilter.fromJson()` |  | WebFilter-ро аз JSON-и сервер месозад; қимати нодуруст ба «off» табдил меёбад. |
| `toJson()` |  | Танҳо он чизе, ки волидайн мегузоранд (ҳолатро телефон хабар медиҳад). |
| `copyWith()` |  | Нусхаи нав бо сатҳ ё рӯйхати ивазшуда. |
| `normalizeDomain()` |  | Доменро аз суроға ҷудо мекунад: «https://www.YouTube.com/x» → «youtube.com». Агар домен нодуруст бошад, null (ҳамон қоидаҳое, ки сервер дорад). |

### `mobile/lib/core/notify_bridge.dart`

пайванди notification-и Android бо Flutter.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class LaunchAction` |  | Додаҳо ва рафтори марбут ба пайванди notification-и Android бо Flutter-ро ифода мекунад. |
| `fromMap()` |  | fromMap мантиқи зарурии пайванди notification-и Android бо Flutter-ро иҷро мекунад. |
| `toString()` |  | Намоиши матнии LaunchAction-ро барои log бармегардонад. |
| `class NotifyPermissions` |  | Додаҳо ва рафтори марбут ба пайванди notification-и Android бо Flutter-ро ифода мекунад. |
| `bool` |  | Қимати ҳисобшудаи all-ро аз ҳолати ҷорӣ бармегардонад. |
| `class NotifyBridge` |  | Ин қадам ҷавоби server ё хатои API-ро коркард мекунад. |
| `launch` |  | Қимати launch-ро барои пайванди notification-и Android бо Flutter нигоҳ медорад. |
| `lastError` |  | Қимати lastError-ро барои пайванди notification-и Android бо Flutter нигоҳ медорад. |
| `bool` |  | Қимати _supported-ро барои пайванди notification-и Android бо Flutter нигоҳ медорад. |
| `init()` |  | init мантиқи зарурии пайванди notification-и Android бо Flutter-ро иҷро мекунад. |
| `start()` |  | start раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад. |
| `stop()` |  | stop раванди фаъолро қатъ карда, захираҳои онро озод мекунад. |
| `stopRinging()` |  | stopRinging раванди фаъолро қатъ карда, захираҳои онро озод мекунад. |
| `permissionStatus()` |  | permissionStatus мантиқи зарурии пайванди notification-и Android бо Flutter-ро иҷро мекунад. |
| `openFullScreenSettings()` |  | openFullScreenSettings экран, dialog ё танзимоти мувофиқро мекушояд. |
| `ensurePermissions()` |  | ensurePermissions дурустӣ ва шартҳои зарурии додаҳоро месанҷад. |
| `resetForTest()` |  | resetForTest мантиқи зарурии пайванди notification-и Android бо Flutter-ро иҷро мекунад. |

### `mobile/lib/core/session.dart`

session, token, нақш ва ҳолати воридшавӣ.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `googleServerClientId` |  | Қимати googleServerClientId-ро барои session, token, нақш ва ҳолати воридшавӣ нигоҳ медорад. |
| `Function()` |  | Function мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад. |
| `pluginAppleCredential()` |  | pluginAppleCredential мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад. |
| `Function()` |  | Function мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад. |
| `pluginGitHubBrowser()` |  | pluginGitHubBrowser мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад. |
| `toString()` |  | Намоиши матнии GitHubSignInCancelled-ро барои log бармегардонад. |
| `appleRawNonce()` |  | appleRawNonce мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад. |
| `secureRawNonce()` |  | secureRawNonce мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад. |
| `sha256Hex()` |  | sha256Hex мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад. |
| `bool` |  | Қимати ҳисобшудаи signedIn-ро аз ҳолати ҷорӣ бармегардонад. |
| `bool` |  | Қимати ҳисобшудаи isParent-ро аз ҳолати ҷорӣ бармегардонад. |
| `bool` |  | Қимати ҳисобшудаи isChild-ро аз ҳолати ҷорӣ бармегардонад. |
| `displayName` |  | Қимати ҳисобшудаи displayName-ро аз ҳолати ҷорӣ бармегардонад. |
| `email` |  | Қимати ҳисобшудаи email-ро аз ҳолати ҷорӣ бармегардонад. |
| `avatar` |  | Қимати ҳисобшудаи avatar-ро барои session, token, нақш ва ҳолати воридшавӣ бармегардонад. |
| `setAvatar()` |  | setAvatar ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `load()` |  | load додаҳои session-ро мехонад ва ҳолати Session-ро нав мекунад. |
| `unawaitedRefresh()` |  | unawaitedRefresh мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад. |
| `_store()` |  | store тағйиротро барои истифодаи баъдӣ нигоҳ медорад. |
| `_saveName()` |  | saveName тағйиротро барои истифодаи баъдӣ нигоҳ медорад. |
| `register()` |  | register дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `login()` |  | Бо почта ва парол ворид мешавад. false — агар рамзи Authenticator лозим бошад. |
| `_finishFirstStep()` |  | Ҷавоби қадами аввалро коркард мекунад: token-ро нигоҳ медорад ё чиптаро. |
| `verifyOtp()` |  | Қадами дуюм: рамзи 6-рақама ё рамзи эҳтиётӣ. |
| `requestEmailCode()` |  | Рамзи воридшавиро ба почта мефиристад. |
| `verifyEmailCode()` |  | Бо рамзи почта ворид мешавад. false — агар баъд рамзи Authenticator лозим бошад. |
| `signInWithGoogle()` |  | signInWithGoogle мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад. |
| `signInWithApple()` |  | signInWithApple мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад. |
| `signInWithGitHub()` |  | signInWithGitHub мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад. |
| `_githubTicket()` |  | githubTicket мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад. |
| `chooseRole()` |  | chooseRole ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `updateName()` |  | updateName ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `signOut()` |  | signOut мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад. |
| `_expired()` |  | expired мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад. |
| `_clear()` |  | clear маълумотро ҳазф карда, ҳолати вобастаро нав мекунад. |
| `of()` |  | of мантиқи зарурии session, token, нақш ва ҳолати воридшавӣро иҷро мекунад. |
| `read()` |  | read додаҳоро мехонад ва ҳолати экранро нав мекунад. |

### `mobile/lib/core/user_journey_logic.dart`

қоидаҳои гузариш байни марҳилаҳои барнома.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class UserJourneyLogic` |  | Қоидаҳои умумии қадамҳои корбар, рамзи пайвасткунӣ ва интихоби лимитро таъмин мекунад. |
| `pairingCode()` |  | pairingCode дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `shouldOfferUpdate()` |  | shouldOfferUpdate иҷро шудани шарти вобастаро муайян мекунад. |
| `validPin()` |  | validPin мантиқи зарурии қоидаҳои гузариш байни марҳилаҳои барномаро иҷро мекунад. |
| `protectionReady()` |  | protectionReady мантиқи зарурии қоидаҳои гузариш байни марҳилаҳои барномаро иҷро мекунад. |
| `nearestLimitIndex()` |  | nearestLimitIndex мантиқи зарурии қоидаҳои гузариш байни марҳилаҳои барномаро иҷро мекунад. |
| `limitLabel()` |  | limitLabel мантиқи зарурии қоидаҳои гузариш байни марҳилаҳои барномаро иҷро мекунад. |
| `usageProgress()` |  | usageProgress мантиқи зарурии қоидаҳои гузариш байни марҳилаҳои барномаро иҷро мекунад. |
| `appCategory()` |  | appCategory мантиқи зарурии қоидаҳои гузариш байни марҳилаҳои барномаро иҷро мекунад. |
| `appMatches()` |  | appMatches мантиқи зарурии қоидаҳои гузариш байни марҳилаҳои барномаро иҷро мекунад. |
| `scheduleActive()` |  | scheduleActive раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад. |
| `mergeMessages()` |  | mergeMessages мантиқи зарурии қоидаҳои гузариш байни марҳилаҳои барномаро иҷро мекунад. |
| `_timestamp()` |  | timestamp мантиқи зарурии қоидаҳои гузариш байни марҳилаҳои барномаро иҷро мекунад. |
| `encodedAppKey()` |  | encodedAppKey додаҳоро ба шакли барои истифода мувофиқ табдил медиҳад. |

### `mobile/lib/main.dart`

оғози барнома, session, notification ва экрани аввал.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `navigatorKey` |  | Қимати navigatorKey-ро барои оғози барнома, session, notification ва экрани аввал нигоҳ медорад. |
| `main()` |  | main мантиқи зарурии оғози барнома, session, notification ва экрани аввалро иҷро мекунад. |
| `createState()` |  | Ҳолати NigohApp-ро барои оғоз, session ва масири аввали барнома месозад. |
| `initState()` |  | Тағйири забони барномаро мешунавад, то тамоми интерфейс аз нав сохта шавад. |
| `dispose()` |  | Controller ва listener-ҳои NigohApp-ро озод мекунад. |
| `rebuildAll()` |  | rebuildAll мантиқи зарурии оғози барнома, session, notification ва экрани аввалро иҷро мекунад. |
| `mark()` |  | mark дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `session` |  | Қимати ҳисобшудаи session-ро аз ҳолати ҷорӣ бармегардонад. |
| `build()` |  | Барномаро бо session, забон ва мавзӯи интихобшуда месозад. |
| `createState()` |  | Ҳолати RootGate-ро барои оғоз, session ва масири аввали барнома месозад. |
| `initState()` |  | Амали огоҳиномаи оғози Android-ро мешунавад ва дархости интизорро коркард мекунад. |
| `dispose()` |  | Controller ва listener-ҳои RootGate-ро озод мекунад. |
| `syncNotifications()` |  | syncNotifications додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад. |
| `onLaunch()` |  | onLaunch рӯйдодро коркард карда, ҳолати вобастаро нав мекунад. |
| `handleLaunch()` |  | handleLaunch рӯйдодро коркард карда, ҳолати вобастаро нав мекунад. |
| `loadProfile()` |  | loadProfile додаҳоро мехонад ва ҳолати экранро нав мекунад. |
| `loadWizardFlag()` |  | loadWizardFlag додаҳоро мехонад ва ҳолати экранро нав мекунад. |
| `onWizardDone()` |  | onWizardDone рӯйдодро коркард карда, ҳолати вобастаро нав мекунад. |
| `scheduleUpdateCheck()` |  | scheduleUpdateCheck раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад. |
| `build()` |  | Аз рӯи session экрани воридшавӣ, интихоби нақш ё саҳифаи асосиро нишон медиҳад. |
| `build()` |  | Ҳангоми омодасозии session экрани интизории NIGOH-ро нишон медиҳад. |


## Барнома — экранҳои волидайн

### `mobile/lib/features/parent/add_child_screen.dart`

пайваст кардани телефони фарзанд бо QR ё код.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `createState()` |  | Ҳолати AddChildScreen-ро барои илова кардани фарзанд ба оила месозад. |
| `dispose()` |  | Controller ва listener-ҳои AddChildScreen-ро озод мекунад. |
| `extractCode()` |  | extractCode мантиқи зарурии пайваст кардани телефони фарзанд бо QR ё кодро иҷро мекунад. |
| `_submit()` |  | submit дархости add_child_screen-ро ба API мефиристад ва натиҷаро коркард мекунад. |
| `build()` |  | Формаи сохтани профили фарзанд ва рамзи пайвасткуниро нишон медиҳад. |
| `build()` |  | Widget-и Step-ро барои илова кардани фарзанд ба оила месозад. |

### `mobile/lib/features/parent/apps_screen.dart`

рӯйхат, филтр ва қоидаҳои барномаҳои фарзанд.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `createState()` |  | Ҳолати AppsScreen-ро барои барномаҳо, лимит ва ҷадвали фарзанд месозад. |
| `_draftLimit` |  | Қимати _draftLimit-ро барои рӯйхат, филтр ва қоидаҳои барномаҳои фарзанд нигоҳ медорад. |
| `controller` |  | Қимати ҳисобшудаи controller-ро аз ҳолати ҷорӣ бармегардонад. |
| `dispose()` |  | Controller ва listener-ҳои AppsScreen-ро озод мекунад. |
| `_run()` |  | run мантиқи зарурии рӯйхат, филтр ва қоидаҳои барномаҳои фарзандро иҷро мекунад. |
| `_bulk()` |  | bulk мантиқи зарурии рӯйхат, филтр ва қоидаҳои барномаҳои фарзандро иҷро мекунад. |
| `_editSchedule()` |  | editSchedule мантиқи зарурии рӯйхат, филтр ва қоидаҳои барномаҳои фарзандро иҷро мекунад. |
| `_openOptions()` |  | openOptions экран, dialog ё танзимоти мувофиқро мекушояд. |
| `_bonus()` |  | bonus мантиқи зарурии рӯйхат, филтр ва қоидаҳои барномаҳои фарзандро иҷро мекунад. |
| `_openReport()` |  | openReport экран, dialog ё танзимоти мувофиқро мекушояд. |
| `_openBedtime()` |  | openBedtime экран, dialog ё танзимоти мувофиқро мекушояд. |
| `_openWebFilter()` |  | Равзанаи «Филтри сайтҳо»-ро барои фарзанд мекушояд. |
| `_openStudy()` |  | openStudy экран, dialog ё танзимоти мувофиқро мекушояд. |
| `_matchesFilter()` |  | matchesFilter иҷро шудани шарти вобастаро муайян мекунад. |
| `build()` |  | Барномаҳои фарзандро бо ҷустуҷӯ, категорияҳо, лимит ва ҳолати басташавӣ нишон медиҳад. |
| `_buildFor()` |  | buildFor қисми мувофиқи интерфейсро месозад. |
| `_refresh()` |  | refresh додаҳои барномаҳо ва маҳдудиятҳо-ро боз мехонад ва AppsScreen-ро нав мекунад. |
| `_appCard()` |  | appCard мантиқи зарурии рӯйхат, филтр ва қоидаҳои барномаҳои фарзандро иҷро мекунад. |
| `_chip()` |  | chip мантиқи зарурии рӯйхат, филтр ва қоидаҳои барномаҳои фарзандро иҷро мекунад. |
| `build()` |  | Widget-и ToolsRow-ро барои барномаҳо, лимит ва ҷадвали фарзанд месозад. |
| `build()` |  | Widget-и StudyButton-ро барои барномаҳо, лимит ва ҷадвали фарзанд месозад. |
| `build()` |  | Кортро бо нишонаи сипар, сатҳ ва ҳолат месозад. |
| `build()` |  | Widget-и ToolTile-ро барои барномаҳо, лимит ва ҷадвали фарзанд месозад. |
| `build()` |  | Widget-и CategoryActions-ро барои барномаҳо, лимит ва ҷадвали фарзанд месозад. |
| `build()` |  | Widget-и ScreenTimeSummary-ро барои барномаҳо, лимит ва ҷадвали фарзанд месозад. |
| `build()` |  | Widget-и PauseCard-ро барои барномаҳо, лимит ва ҷадвали фарзанд месозад. |
| `ValueChanged` |  | Қимати onBonus-ро барои рӯйхат, филтр ва қоидаҳои барномаҳои фарзанд нигоҳ медорад. |
| `build()` |  | Widget-и AppRuleCard-ро барои барномаҳо, лимит ва ҷадвали фарзанд месозад. |
| `createState()` |  | Ҳолати ScheduleSheet-ро барои барномаҳо, лимит ва ҷадвали фарзанд месозад. |
| `initState()` |  | Ҷадвали барномаро ба вақт ва рӯзҳои таҳриршаванда мегузаронад. |
| `_parse()` |  | parse додаҳоро ба шакли барои истифода мувофиқ табдил медиҳад. |
| `_format()` |  | format додаҳоро ба шакли барои истифода мувофиқ табдил медиҳад. |
| `_pick()` |  | pick мантиқи зарурии рӯйхат, филтр ва қоидаҳои барномаҳои фарзандро иҷро мекунад. |
| `build()` |  | Widget-и ScheduleSheet-ро барои барномаҳо, лимит ва ҷадвали фарзанд месозад. |
| `build()` |  | Widget-и TimeTile-ро барои барномаҳо, лимит ва ҷадвали фарзанд месозад. |

### `mobile/lib/features/parent/family_controller.dart`

боркунӣ ва навсозии ҳолати оила.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `_pending` |  | Қимати _pending-ро барои боркунӣ ва навсозии ҳолати оила нигоҳ медорад. |
| `selected` |  | Қимати ҳисобшудаи selected-ро барои боркунӣ ва навсозии ҳолати оила бармегардонад. |
| `childById()` |  | childById мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад. |
| `select()` |  | select ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `start()` |  | start раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад. |
| `_startTimer()` |  | startTimer раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад. |
| `didChangeAppLifecycleState()` |  | Ба тағйири lifecycle-и FamilyController ҷавоб медиҳад. |
| `refresh()` |  | refresh додаҳои ҳолати оила-ро боз мехонад ва FamilyController-ро нав мекунад. |
| `pair()` |  | pair дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `setBlocked()` |  | setBlocked ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `setLimit()` |  | setLimit ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `setSchedule()` |  | setSchedule ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `setAlwaysAllowed()` |  | setAlwaysAllowed ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `giveBonus()` |  | giveBonus дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `setBedtime()` |  | setBedtime ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `setStudyMode()` |  | setStudyMode ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `setWebFilter()` |  | Филтри сайтҳоро барои фарзанд нигоҳ медорад (бо ҳолати optimistic ва бозгашт ҳангоми хато). |
| `decideRequest()` |  | decideRequest дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `markChatRead()` |  | markChatRead дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `places` |  | Қимати places-ро барои боркунӣ ва навсозии ҳолати оила нигоҳ медорад. |
| `placesFor()` |  | placesFor мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад. |
| `loadPlaces()` |  | loadPlaces додаҳоро мехонад ва ҳолати экранро нав мекунад. |
| `addPlace()` |  | addPlace мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад. |
| `setPlaceRules()` |  | Қоидаҳои барномаҳо ва огоҳии ҷойро нигоҳ медорад (бо бозгашт ҳангоми хато). |
| `deletePlace()` |  | deletePlace маълумотро ҳазф карда, ҳолати вобастаро нав мекунад. |
| `int` |  | Қимати ҳисобшудаи pendingRequestsTotal-ро аз ҳолати ҷорӣ бармегардонад. |
| `int` |  | Қимати ҳисобшудаи unreadTotal-ро аз ҳолати ҷорӣ бармегардонад. |
| `sortedByAttention` |  | Қимати ҳисобшудаи sortedByAttention-ро барои боркунӣ ва навсозии ҳолати оила бармегардонад. |
| `urgentChildren` |  | Қимати urgentChildren-ро барои боркунӣ ва навсозии ҳолати оила нигоҳ медорад. |
| `unlink()` |  | unlink маълумотро ҳазф карда, ҳолати вобастаро нав мекунад. |
| `_updateApp()` |  | updateApp ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `_replaceChild()` |  | replaceChild мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад. |
| `_replaceApp()` |  | replaceApp мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад. |
| `_guard` |  | T мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад. |
| `_copyApp()` |  | copyApp мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад. |
| `_copyChild()` |  | copyChild мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад. |
| `_notify()` |  | notify listener ё корбарро аз тағйирот огоҳ мекунад. |
| `dispose()` |  | Controller ва listener-ҳои FamilyController-ро озод мекунад. |
| `lowBatteryPercent` |  | Қимати lowBatteryPercent-ро барои боркунӣ ва навсозии ҳолати оила нигоҳ медорад. |
| `offlineAfter` |  | Қимати offlineAfter-ро барои боркунӣ ва навсозии ҳолати оила нигоҳ медорад. |
| `isLowBattery()` |  | isLowBattery иҷро шудани шарти вобастаро муайян мекунад. |
| `isOfflineChild()` |  | isOfflineChild иҷро шудани шарти вобастаро муайян мекунад. |
| `attentionRank()` |  | attentionRank мантиқи зарурии боркунӣ ва навсозии ҳолати оиларо иҷро мекунад. |
| `formatMinutes()` |  | formatMinutes додаҳоро ба шакли барои истифода мувофиқ табдил медиҳад. |

### `mobile/lib/features/parent/map_screen.dart`

харита, ҷойгиршавӣ ва таърихи ҳаракати фарзанд.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `createState()` |  | Ҳолати MapScreen-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад. |
| `_showHistory` |  | Қимати _showHistory-ро барои харита, ҷойгиршавӣ ва таърихи ҳаракати фарзанд нигоҳ медорад. |
| `dispose()` |  | Controller ва listener-ҳои MapScreen-ро озод мекунад. |
| `_follow()` |  | follow мантиқи зарурии харита, ҷойгиршавӣ ва таърихи ҳаракати фарзандро иҷро мекунад. |
| `_refresh()` |  | refresh додаҳои харита ва ҷойгиршавӣ-ро боз мехонад ва MapScreen-ро нав мекунад. |
| `_toggleHistory()` |  | toggleHistory ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `_loadHistory()` |  | loadHistory додаҳоро мехонад ва ҳолати экранро нав мекунад. |
| `_openTimeline()` |  | openTimeline экран, dialog ё танзимоти мувофиқро мекушояд. |
| `_addPlace()` |  | addPlace мантиқи зарурии харита, ҷойгиршавӣ ва таърихи ҳаракати фарзандро иҷро мекунад. |
| `_openPlaces()` |  | openPlaces экран, dialog ё танзимоти мувофиқро мекушояд. |
| `build()` |  | Харитаро бо нишонаи фарзанд, ҷойҳои бехатар ва корти ҷойгиршавӣ месозад. |
| `_overlayTextScale` |  | Қимати _overlayTextScale-ро барои харита, ҷойгиршавӣ ва таърихи ҳаракати фарзанд нигоҳ медорад. |
| `_bottomCardShare` |  | Қимати _bottomCardShare-ро барои харита, ҷойгиршавӣ ва таърихи ҳаракати фарзанд нигоҳ медорад. |
| `_bottomCardLimit()` |  | bottomCardLimit мантиқи зарурии харита, ҷойгиршавӣ ва таърихи ҳаракати фарзандро иҷро мекунад. |
| `build()` |  | Widget-и AnimatedBox-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад. |
| `build()` |  | Widget-и MapHint-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад. |
| `build()` |  | Widget-и ChildMarker-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад. |
| `build()` |  | Widget-и LocationCard-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад. |
| `build()` |  | Widget-и StatusLabel-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад. |
| `build()` |  | Widget-и MapChip-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад. |
| `build()` |  | Widget-и PathDot-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад. |
| `build()` |  | Widget-и PlaceLabel-ро барои харита, ҷойгиршавӣ ва ҷойҳои бехатар месозад. |

### `mobile/lib/features/parent/parent_home.dart`

саҳифаи асосии волид ва бахшҳои назорат.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `wideBreakpoint` |  | Қимати wideBreakpoint-ро барои саҳифаи асосии волид ва бахшҳои назорат нигоҳ медорад. |
| `maxContentWidth` |  | Қимати maxContentWidth-ро барои саҳифаи асосии волид ва бахшҳои назорат нигоҳ медорад. |
| `createState()` |  | Ҳолати ParentHome-ро барои панели асосии волид ва ҳолати фарзандон месозад. |
| `controller` |  | Қимати ҳисобшудаи controller-ро аз ҳолати ҷорӣ бармегардонад. |
| `initState()` |  | Ҳадафи огоҳиномаро мешунавад ва фарзанду бахши дархостшударо интихоб мекунад. |
| `_onHomeTarget()` |  | onHomeTarget рӯйдодро коркард карда, ҳолати вобастаро нав мекунад. |
| `_markReadIfNeeded()` |  | markReadIfNeeded дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `_openRequests()` |  | openRequests экран, dialog ё танзимоти мувофиқро мекушояд. |
| `_openReport()` |  | openReport экран, dialog ё танзимоти мувофиқро мекушояд. |
| `_openBedtime()` |  | openBedtime экран, dialog ё танзимоти мувофиқро мекушояд. |
| `_openStudy()` |  | openStudy экран, dialog ё танзимоти мувофиқро мекушояд. |
| `didChangeDependencies()` |  | Пас аз тағйири dependency-ҳо ҳолати вобастаро нав мекунад. |
| `dispose()` |  | Controller ва listener-ҳои ParentHome-ро озод мекунад. |
| `_addChild()` |  | addChild мантиқи зарурии саҳифаи асосии волид ва бахшҳои назоратро иҷро мекунад. |
| `_open()` |  | open экран ё dialog-и лозими панели волид-ро мекушояд. |
| `_requirePin()` |  | requirePin мантиқи зарурии саҳифаи асосии волид ва бахшҳои назоратро иҷро мекунад. |
| `_removeChild()` |  | removeChild маълумотро ҳазф карда, ҳолати вобастаро нав мекунад. |
| `build()` |  | Панели волидро бо ҷадвалбандӣ, фарзанди интихобшуда ва бахши фаъол месозад. |
| `_tabBody()` |  | tabBody мантиқи зарурии саҳифаи асосии волид ва бахшҳои назоратро иҷро мекунад. |
| `class _NavItem` |  | Widget-и NavItem-ро барои саҳифаи асосии волид ва бахшҳои назорат месозад. |
| `build()` |  | Widget-и EmptyFamily-ро барои панели асосии волид ва ҳолати фарзандон месозад. |
| `build()` |  | Widget-и ChildSelector-ро барои панели асосии волид ва ҳолати фарзандон месозад. |
| `build()` |  | Widget-и Overview-ро барои панели асосии волид ва ҳолати фарзандон месозад. |
| `build()` |  | Widget-и ErrorBanner-ро барои панели асосии волид ва ҳолати фарзандон месозад. |
| `build()` |  | Widget-и ChildCard-ро барои панели асосии волид ва ҳолати фарзандон месозад. |
| `build()` |  | Widget-и InternetRow-ро барои панели асосии волид ва ҳолати фарзандон месозад. |
| `build()` |  | Widget-и DeviceAlerts-ро барои панели асосии волид ва ҳолати фарзандон месозад. |
| `build()` |  | Widget-и Stat-ро барои панели асосии волид ва ҳолати фарзандон месозад. |
| `build()` |  | Widget-и QuickAction-ро барои панели асосии волид ва ҳолати фарзандон месозад. |
| `build()` |  | Widget-и LinkRow-ро барои панели асосии волид ва ҳолати фарзандон месозад. |
| `build()` |  | Widget-и RequestsTile-ро барои панели асосии волид ва ҳолати фарзандон месозад. |
| `build()` |  | Widget-и SosBanner-ро барои панели асосии волид ва ҳолати фарзандон месозад. |

### `mobile/lib/features/parent/parent_logic.dart`

ҳисобҳо ва қарорҳои интерфейси волид.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `placeStatus()` |  | placeStatus мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад. |
| `two()` |  | two мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад. |
| `hhmm()` |  | hhmm мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад. |
| `bedtimeLabel()` |  | bedtimeLabel мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад. |
| `class HistoryPoint` |  | Додаҳо ва рафтори марбут ба ҳисобҳо ва қарорҳои интерфейси волидро ифода мекунад. |
| `listFromJson()` |  | listFromJson мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад. |
| `_time()` |  | time мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад. |
| `class UsageDay` |  | Додаҳо ва рафтори марбут ба ҳисобҳо ва қарорҳои интерфейси волидро ифода мекунад. |
| `listFromJson()` |  | listFromJson мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад. |
| `class UsageTopApp` |  | Додаҳо ва рафтори марбут ба ҳисобҳо ва қарорҳои интерфейси волидро ифода мекунад. |
| `limitLabelText()` |  | limitLabelText мантиқи зарурии ҳисобҳо ва қарорҳои интерфейси волидро иҷро мекунад. |

### `mobile/lib/features/parent/parent_sheets.dart`

bottom sheet-ҳои амалҳои волид.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `parseHhmm()` |  | parseHhmm додаҳоро ба шакли барои истифода мувофиқ табдил медиҳад. |
| `formatHhmm()` |  | formatHhmm додаҳоро ба шакли барои истифода мувофиқ табдил медиҳад. |
| `createState()` |  | Ҳолати BedtimeSheet-ро барои реҷаи хоб ва амалҳои барнома месозад. |
| `initState()` |  | Реҷаи хоби фарзандро ба вақтҳои оғозу анҷоми таҳриршаванда мегузаронад. |
| `_pick()` |  | pick мантиқи зарурии bottom sheet-ҳои амалҳои волидро иҷро мекунад. |
| `_save()` |  | save тағйироти танзимоти волид-ро барои истифодаи баъдӣ нигоҳ медорад. |
| `build()` |  | Танзими вақти оғозу анҷоми реҷаи хобро нишон медиҳад. |
| `build()` |  | Widget-и TimeTile-ро барои реҷаи хоб ва амалҳои барнома месозад. |
| `createState()` |  | Ҳолати AppOptionsSheet-ро барои реҷаи хоб ва амалҳои барнома месозад. |
| `_run()` |  | run мантиқи зарурии bottom sheet-ҳои амалҳои волидро иҷро мекунад. |
| `build()` |  | Амалҳои бастан, лимит, ҷадвал ва бонуси барномаи интихобшударо нишон медиҳад. |
| `build()` |  | Widget-и BonusButtons-ро барои реҷаи хоб ва амалҳои барнома месозад. |

### `mobile/lib/features/parent/place_rules_sheet.dart`

равзанаи «Қоидаҳои ин ҷой» — вақте фарзанд дар ҷойи интихобшуда (масалан мактаб) аст,

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `placeLimitChoices` |  | Лимитҳое, ки волидайн дар ҷой интихоб карда метавонанд (дақиқа). |
| `placeQuickBlockCategories` |  | Категорияҳое, ки тугмаи «Мисли мактаб» мебандад. |
| `placeRuleLabel()` |  | Матни кӯтоҳи қоида барои рӯйхат: «Баста», «Лимит 20 дақ», «Ҳамеша кушода». |
| `placeRulesSummary()` |  | Шарҳи кӯтоҳи ҷой барои рӯйхати ҷойҳо: «3 қоида · огоҳӣ». |
| `createState()` |  | Ҳолати PlaceRulesSheet-ро месозад. |
| `_apps` |  | Барномаҳои фарзанд, ки ба ҷустуҷӯ мувофиқанд; барномаҳои бо қоида аввал. |
| `_set()` |  | Қоидаи як барномаро иваз мекунад (null — «мисли ҳамеша»). |
| `_quickSchool()` |  | Бозиҳо, видео ва шабакаҳоро дар ин ҷой мебандад (занг ва SMS дахл намебинанд). |
| `_save()` |  | Қоидаҳоро ба сервер мефиристад ва равзанаро мебандад. |
| `build()` |  | Равзанаро бо огоҳӣ, тугмаи зуд, ҷустуҷӯ ва рӯйхати барномаҳо месозад. |
| `build()` |  | Сатрро бо менюи қоида месозад; барномаҳои занг ва SMS баста намешаванд. |

### `mobile/lib/features/parent/places_sheets.dart`

эҷод ва таҳрири ҷойҳои бехатар.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `createState()` |  | Ҳолати AddPlaceSheet-ро барои ҷойҳои бехатар ва таърихи ҳаракат месозад. |
| `dispose()` |  | Controller ва listener-ҳои AddPlaceSheet-ро озод мекунад. |
| `_position` |  | Қимати ҳисобшудаи position-ро аз ҳолати ҷорӣ бармегардонад. |
| `_save()` |  | save тағйироти ҷойҳои бехатар-ро барои истифодаи баъдӣ нигоҳ медорад. |
| `build()` |  | Формаи ном, радиус ва координатаҳои ҷойи бехатарро нишон медиҳад. |
| `createState()` |  | Ҳолати PlacesSheet-ро барои ҷойҳои бехатар ва таърихи ҳаракат месозад. |
| `_openRules()` |  | Равзанаи «Қоидаҳои ин ҷой»-ро мекушояд. |
| `_delete()` |  | delete маълумотро ҳазф карда, ҳолати вобастаро нав мекунад. |
| `build()` |  | Рӯйхати ҷойҳои бехатарро бо амалҳои таҳрир ва несткунӣ нишон медиҳад. |
| `build()` |  | Widget-и PlaceTile-ро барои ҷойҳои бехатар ва таърихи ҳаракат месозад. |
| `build()` |  | Widget-и HistoryTimelineSheet-ро барои ҷойҳои бехатар ва таърихи ҳаракат месозад. |

### `mobile/lib/features/parent/requests_screen.dart`

баррасии дархостҳои вақти иловагӣ.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class _Entry` |  | Додаҳо ва рафтори марбут ба баррасии дархостҳои вақти иловагӣро ифода мекунад. |
| `createState()` |  | Ҳолати TimeRequestsScreen-ро барои дархостҳои вақти иловагӣ месозад. |
| `controller` |  | Қимати ҳисобшудаи controller-ро аз ҳолати ҷорӣ бармегардонад. |
| `initState()` |  | Дархостҳои вақти интизор ва ҳалшударо аз сервер бор мекунад. |
| `_load()` |  | load додаҳои дархостҳои вақти иловагӣ-ро мехонад ва ҳолати TimeRequestsScreen-ро нав мекунад. |
| `_approve()` |  | approve мантиқи зарурии баррасии дархостҳои вақти иловагӣро иҷро мекунад. |
| `_decide()` |  | decide дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `build()` |  | Дархостҳои интизор ва ҳалшудаи вақти иловагиро нишон медиҳад. |
| `build()` |  | Widget-и RequestCard-ро барои дархостҳои вақти иловагӣ месозад. |
| `build()` |  | Widget-и ApproveSheet-ро барои дархостҳои вақти иловагӣ месозад. |
| `build()` |  | Widget-и DecidedTile-ро барои дархостҳои вақти иловагӣ месозад. |

### `mobile/lib/features/parent/study_sheet.dart`

танзими реҷаи дарс.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `studyWeekdayLabels` |  | Қимати studyWeekdayLabels-ро барои танзими реҷаи дарс нигоҳ медорад. |
| `studyExplanation` |  | Қимати studyExplanation-ро барои танзими реҷаи дарс нигоҳ медорад. |
| `studyLabel()` |  | studyLabel мантиқи зарурии танзими реҷаи дарсро иҷро мекунад. |
| `createState()` |  | Ҳолати StudySheet-ро барои танзими реҷаи дарс месозад. |
| `initState()` |  | Реҷаи дарси фарзандро ба вақт, ҳолати фаъол ва рӯзҳои интихобшуда мегузаронад. |
| `_pick()` |  | pick мантиқи зарурии танзими реҷаи дарсро иҷро мекунад. |
| `_save()` |  | save тағйироти реҷаи дарс-ро барои истифодаи баъдӣ нигоҳ медорад. |
| `build()` |  | Танзими вақти оғоз, анҷом ва рӯзҳои реҷаи дарсро нишон медиҳад. |

### `mobile/lib/features/parent/web_filter_sheet.dart`

равзанаи «Филтри сайтҳо» барои волидайн — сатҳи синну сол, сайтҳои манъшуда ва ҳолати телефон.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `webFilterLevelLabel()` |  | Номи кӯтоҳи сатҳ барои корт ва рӯйхат. |
| `webFilterLevelHint()` |  | Шарҳи он ки ҳар сатҳ чиро мебандад. |
| `webFilterStateLabel()` |  | Матни ҳолати филтр дар телефони фарзанд барои волидайн. |
| `createState()` |  | Ҳолати WebFilterSheet-ро месозад. |
| `initState()` |  | Танзими ҳозираро мегирад; агар филтр ҳанӯз нагузошта бошад, сатҳро аз синну сол пешниҳод мекунад. |
| `dispose()` |  | Майдони матнро озод мекунад. |
| `_addSite()` |  | Сайти навиштаро ба рӯйхат илова мекунад (агар дуруст ва нав бошад). |
| `_save()` |  | Танзимро ба сервер мефиристад ва равзанаро мебандад. |
| `build()` |  | Равзанаро бо се сатҳ, рӯйхати сайтҳо ва ҳолати телефон месозад. |
| `build()` |  | Корти сатҳро бо нишона, ном, шарҳ ва белгии «тавсия» месозад. |
| `build()` |  | Хатро бо ранги мувофиқи ҳолат месозад. |

### `mobile/lib/features/parent/weekly_report.dart`

ҳисоботи ҳафтаинаи истифода ва фаъолият.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `createState()` |  | Ҳолати WeeklyReportScreen-ро барои ҳисоботи ҳафтаинаи истифода месозад. |
| `initState()` |  | Омори истифодаи ҳафт рӯзи фарзандро аз сервер бор мекунад. |
| `_load()` |  | load додаҳои ҳисоботи ҳафтаина-ро мехонад ва ҳолати WeeklyReportScreen-ро нав мекунад. |
| `build()` |  | Ҳисоботи ҳафтаинаро аз сервер бор карда, ҳолати натиҷаро нишон медиҳад. |
| `Map` |  | Қимати icons-ро барои ҳисоботи ҳафтаинаи истифода ва фаъолият нигоҳ медорад. |
| `build()` |  | Ҷамъбасти ҳафта, диаграммаи рӯзҳо ва барномаҳои серистифодаро нишон медиҳад. |
| `_dayLabel()` |  | dayLabel мантиқи зарурии ҳисоботи ҳафтаинаи истифода ва фаъолиятро иҷро мекунад. |
| `build()` |  | Widget-и WeeklyBarChart-ро барои ҳисоботи ҳафтаинаи истифода месозад. |
| `_short()` |  | short мантиқи зарурии ҳисоботи ҳафтаинаи истифода ва фаъолиятро иҷро мекунад. |
| `build()` |  | Widget-и SummaryTile-ро барои ҳисоботи ҳафтаинаи истифода месозад. |
| `build()` |  | Widget-и TopAppRow-ро барои ҳисоботи ҳафтаинаи истифода месозад. |


## Барнома — экранҳои фарзанд

### `mobile/lib/features/child/child_home.dart`

саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳо.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `pairingQrData()` |  | pairingQrData дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `createState()` |  | Ҳолати ChildHome-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад. |
| `sync` |  | Қимати ҳисобшудаи sync-ро аз ҳолати ҷорӣ бармегардонад. |
| `initState()` |  | Ҳадафи аз огоҳинома омадаро мешунавад ва бахши мувофиқи экрани фарзандро мекушояд. |
| `_onHomeTarget()` |  | onHomeTarget рӯйдодро коркард карда, ҳолати вобастаро нав мекунад. |
| `didChangeDependencies()` |  | Пас аз тағйири dependency-ҳо ҳолати вобастаро нав мекунад. |
| `dispose()` |  | Controller ва listener-ҳои ChildHome-ро озод мекунад. |
| `didChangeAppLifecycleState()` |  | Ба тағйири lifecycle-и ChildHome ҷавоб медиҳад. |
| `_onSync()` |  | onSync рӯйдодро коркард карда, ҳолати вобастаро нав мекунад. |
| `_openAccess()` |  | openAccess экран, dialog ё танзимоти мувофиқро мекушояд. |
| `build()` |  | Экрани фарзандро бо Home, қоидаҳо, чат ва танзимот месозад. |
| `build()` |  | Widget-и HomeTab-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад. |
| `createState()` |  | Ҳолати PairingView-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад. |
| `_newCode()` |  | newCode мантиқи зарурии саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳоро иҷро мекунад. |
| `build()` |  | Widget-и PairingView-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад. |
| `build()` |  | Widget-и Step-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад. |
| `_sendSos()` |  | sendSos дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `build()` |  | Widget-и PairedView-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад. |
| `createState()` |  | Ҳолати RetryButton-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад. |
| `_run()` |  | run мантиқи зарурии саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳоро иҷро мекунад. |
| `build()` |  | Widget-и RetryButton-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад. |
| `sendChildSos()` |  | sendChildSos дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `build()` |  | Widget-и StatusCard-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад. |
| `createState()` |  | Ҳолати ErrorCard-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад. |
| `_retry()` |  | retry мантиқи зарурии саҳифаи асосии фарзанд ва ҳолати маҳдудиятҳоро иҷро мекунад. |
| `build()` |  | Widget-и ErrorCard-ро барои саҳифаи асосӣ ва пайвасткунии фарзанд месозад. |
| `build()` |  | Кортро бо номи ҷой ва шумораи қоидаҳо месозад. |

### `mobile/lib/features/child/child_rules.dart`

татбиқи маҳдудиятҳои барнома, хоб ва дарс.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `weekdaysLabel()` |  | weekdaysLabel мантиқи зарурии татбиқи маҳдудиятҳои барнома, хоб ва дарсро иҷро мекунад. |
| `studyClosedApps()` |  | studyClosedApps мантиқи зарурии татбиқи маҳдудиятҳои барнома, хоб ва дарсро иҷро мекунад. |
| `limitUsageLabel()` |  | limitUsageLabel мантиқи зарурии татбиқи маҳдудиятҳои барнома, хоб ва дарсро иҷро мекунад. |
| `minutesLabel()` |  | minutesLabel мантиқи зарурии татбиқи маҳдудиятҳои барнома, хоб ва дарсро иҷро мекунад. |
| `createState()` |  | Ҳолати ChildRulesScreen-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад. |
| `sync` |  | Қимати ҳисобшудаи sync-ро аз ҳолати ҷорӣ бармегардонад. |
| `initState()` |  | Тағйири ҳамоҳангсозиро мешунавад ва дархостҳои вақти фарзандро бор мекунад. |
| `dispose()` |  | Controller ва listener-ҳои ChildRulesScreen-ро озод мекунад. |
| `_onSync()` |  | onSync рӯйдодро коркард карда, ҳолати вобастаро нав мекунад. |
| `_loadRequests()` |  | loadRequests додаҳоро мехонад ва ҳолати экранро нав мекунад. |
| `_refresh()` |  | refresh додаҳои қоидаҳои фарзанд-ро боз мехонад ва ChildRulesScreen-ро нав мекунад. |
| `_askTime()` |  | askTime иҷозат ё маълумоти лозимро дархост мекунад. |
| `build()` |  | Қоидаҳои фаъол, лимитҳои барномаҳо ва дархостҳои вақти фарзандро нишон медиҳад. |
| `build()` |  | Widget-и GroupHeader-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад. |
| `build()` |  | Widget-и RuleCard-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад. |
| `build()` |  | Widget-и AppRule-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад. |
| `class _TimeAsk` |  | TimeAsk додаҳо ва рафтори қоидаҳои фарзанд-ро ифода мекунад. |
| `createState()` |  | Ҳолати TimeRequestSheet-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад. |
| `dispose()` |  | Controller ва listener-ҳои TimeRequestSheet-ро озод мекунад. |
| `build()` |  | Widget-и TimeRequestSheet-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад. |
| `build()` |  | Widget-и RequestsList-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад. |
| `requestStatusPill()` |  | requestStatusPill иҷозат ё маълумоти лозимро дархост мекунад. |
| `build()` |  | Widget-и InlineError-ро барои қоидаҳо ва дархостҳои вақти фарзанд месозад. |

### `mobile/lib/features/child/child_sync.dart`

ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `Function()` |  | Function мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `Function()` |  | Function мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `now()` |  | now мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `locationFixEvery` |  | Қимати locationFixEvery-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад. |
| `clampUsage()` |  | clampUsage мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `loading` |  | Қимати loading-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад. |
| `lastPosition` |  | Қимати lastPosition-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад. |
| `protection` |  | Қимати protection-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад. |
| `protectionKnown` |  | Қимати protectionKnown-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад. |
| `missingPermissions` |  | Қимати missingPermissions-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад. |
| `lastError` |  | Қимати lastError-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад. |
| `_setError()` |  | setError ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `_clearError()` |  | clearError маълумотро ҳазф карда, ҳолати вобастаро нав мекунад. |
| `_notify()` |  | notify listener ё корбарро аз тағйирот огоҳ мекунад. |
| `start()` |  | start раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад. |
| `stop()` |  | stop раванди фаъолро қатъ карда, захираҳои онро озод мекунад. |
| `dispose()` |  | Controller ва listener-ҳои ChildSync-ро озод мекунад. |
| `forceSync()` |  | forceSync мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `ensureChild()` |  | ensureChild дурустӣ ва шартҳои зарурии додаҳоро месанҷад. |
| `_ensureChild()` |  | ensureChild дурустӣ ва шартҳои зарурии додаҳоро месанҷад. |
| `_createCode()` |  | createCode мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `regenerateCode()` |  | regenerateCode мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `_applyChild()` |  | applyChild рӯйдодро коркард карда, ҳолати вобастаро нав мекунад. |
| `applyWebFilter()` |  | Филтри сайтҳоро ба VPN-и Android месупорад ва ҳолатро ба волидайн хабар медиҳад. |
| `requestWebFilterPermission()` |  | Тирезаи розигии VPN-ро нишон медиҳад; пас аз розигӣ филтр фавран кор мекунад. |
| `_reportWebFilterState()` |  | Ҳолати навро танҳо вақте мефиристад, ки аз ҳолати маълуми сервер фарқ дорад. |
| `updateActivePlace()` |  | Ҷойи ҳозираро аз мавқеи охирин нав мекунад; агар иваз шуд, қоидаҳоро аз нав мефиристад. |
| `pushRules()` |  | pushRules мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `_repushIfWindowChanged()` |  | repushIfWindowChanged мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `tick()` |  | tick мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `_tick()` |  | tick мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `refreshProtection()` |  | refreshProtection додаҳоро боз хонда, интерфейсро нав мекунад. |
| `syncApps()` |  | syncApps додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад. |
| `_syncApps()` |  | syncApps додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад. |
| `buildAppsPayload()` |  | buildAppsPayload қисми мувофиқи интерфейсро месозад. |
| `_gpsOffText` |  | Қимати ҳисобшудаи gpsOffText-ро аз ҳолати ҷорӣ бармегардонад. |
| `_noPermissionText` |  | Қимати ҳисобшудаи noPermissionText-ро аз ҳолати ҷорӣ бармегардонад. |
| `_noFixText` |  | Қимати ҳисобшудаи noFixText-ро аз ҳолати ҷорӣ бармегардонад. |
| `startLocation()` |  | startLocation раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад. |
| `bool` |  | Қимати ҳисобшудаи fixDue-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо бармегардонад. |
| `pendingFix` |  | Қимати pendingFix-ро барои ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳо нигоҳ медорад. |
| `_locationAllowed()` |  | locationAllowed мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `_startStream()` |  | startStream раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад. |
| `_fixErrorText()` |  | fixErrorText мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `requestFix()` |  | requestFix иҷозат ё маълумоти лозимро дархост мекунад. |
| `_requestFix()` |  | requestFix иҷозат ё маълумоти лозимро дархост мекунад. |
| `onPosition()` |  | onPosition рӯйдодро коркард карда, ҳолати вобастаро нав мекунад. |
| `_maybePostLocation()` |  | maybePostLocation мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `_post()` |  | post мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `readBattery()` |  | readBattery додаҳоро мехонад ва ҳолати экранро нав мекунад. |
| `_postLocation()` |  | postLocation мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |
| `_text()` |  | text мантиқи зарурии ҳамоҳангсозии заминавии барномаҳо, ҷойгиршавӣ ва event-ҳоро иҷро мекунад. |

### `mobile/lib/features/child/child_widgets.dart`

widget-ҳои муштараки интерфейси фарзанд.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `childReducedMotion()` |  | childReducedMotion мантиқи зарурии widget-ҳои муштараки интерфейси фарзандро иҷро мекунад. |
| `sosMessageText()` |  | sosMessageText мантиқи зарурии widget-ҳои муштараки интерфейси фарзандро иҷро мекунад. |
| `build()` |  | Widget-и ChildProgressBar-ро барои ҳолатҳо ва амалҳои экрани фарзанд месозад. |
| `build()` |  | Widget-и ChildIconTile-ро барои ҳолатҳо ва амалҳои экрани фарзанд месозад. |
| `createState()` |  | Ҳолати SosButton-ро барои ҳолатҳо ва амалҳои экрани фарзанд месозад. |
| `dispose()` |  | Controller ва listener-ҳои SosButton-ро озод мекунад. |
| `_onStatus()` |  | onStatus рӯйдодро коркард карда, ҳолати вобастаро нав мекунад. |
| `_down()` |  | down мантиқи зарурии widget-ҳои муштараки интерфейси фарзандро иҷро мекунад. |
| `_release()` |  | release мантиқи зарурии widget-ҳои муштараки интерфейси фарзандро иҷро мекунад. |
| `build()` |  | Widget-и SosButton-ро барои ҳолатҳо ва амалҳои экрани фарзанд месозад. |
| `build()` |  | Widget-и ChildNotice-ро барои ҳолатҳо ва амалҳои экрани фарзанд месозад. |
| `build()` |  | Widget-и BedtimeNotice-ро барои ҳолатҳо ва амалҳои экрани фарзанд месозад. |
| `build()` |  | Widget-и StudyNotice-ро барои ҳолатҳо ва амалҳои экрани фарзанд месозад. |
| `build()` |  | Widget-и ScreenTimeCard-ро барои ҳолатҳо ва амалҳои экрани фарзанд месозад. |


## Барнома — воридшавӣ ва танзимот

### `mobile/lib/features/auth/auth_screen.dart`

экрани бақайдгирӣ ва воридшавӣ.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `createState()` |  | Ҳолати AuthScreen-ро барои воридшавӣ бо почта ва OAuth месозад. |
| `appleEnabled` |  | Қимати appleEnabled-ро барои экрани бақайдгирӣ ва воридшавӣ нигоҳ медорад. |
| `_appleAttempt` |  | Қимати _appleAttempt-ро барои экрани бақайдгирӣ ва воридшавӣ нигоҳ медорад. |
| `_awaitingAppleCredential` |  | Қимати _awaitingAppleCredential-ро барои экрани бақайдгирӣ ва воридшавӣ нигоҳ медорад. |
| `githubBusy` |  | Қимати githubBusy-ро барои экрани бақайдгирӣ ва воридшавӣ нигоҳ медорад. |
| `githubEnabled` |  | Қимати githubEnabled-ро барои экрани бақайдгирӣ ва воридшавӣ нигоҳ медорад. |
| `emailCodeEnabled` |  | Воридшавӣ бо рамз ба почта дар сервер фаъол аст ё не. |
| `bool` |  | Қимати ҳисобшудаи anyBusy-ро аз ҳолати ҷорӣ бармегардонад. |
| `initState()` |  | Пас аз frame-и аввал танзимоти воридшавии Apple ва GitHub-ро аз сервер мегирад. |
| `_loadOtpConfig()` |  | Аз сервер мепурсад, ки воридшавӣ бо рамз ба почта фаъол аст ё не. |
| `_loadAppleConfig()` |  | loadAppleConfig додаҳоро мехонад ва ҳолати экранро нав мекунад. |
| `_loadGitHubConfig()` |  | loadGitHubConfig додаҳоро мехонад ва ҳолати экранро нав мекунад. |
| `didChangeAppLifecycleState()` |  | Ба тағйири lifecycle-и AuthScreen ҷавоб медиҳад. |
| `dispose()` |  | Controller ва listener-ҳои AuthScreen-ро озод мекунад. |
| `submit()` |  | submit дархости воридшавӣ-ро ба API мефиристад ва натиҷаро коркард мекунад. |
| `google()` |  | google экран, dialog ё танзимоти мувофиқро мекушояд. |
| `github()` |  | github мантиқи зарурии экрани бақайдгирӣ ва воридшавӣро иҷро мекунад. |
| `apple()` |  | apple мантиқи зарурии экрани бақайдгирӣ ва воридшавӣро иҷро мекунад. |
| `build()` |  | Экрани воридшавиро бо формаи почта ва тугмаҳои Google, Apple ва GitHub месозад. |

### `mobile/lib/features/auth/brand_logo.dart`

нишонаи бренди NIGOH.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `build()` |  | Widget-и BrandLogo-ро барои нишони бренди NIGOH месозад. |

### `mobile/lib/features/auth/otp_sheets.dart`

равзанаҳои қадами дуюми воридшавӣ — рамзи Authenticator ва воридшавӣ бо рамз ба почта.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `showOtpSheet()` |  | Равзанаи рамзи Authenticator-ро нишон медиҳад; true — агар корбар ворид шуд. |
| `showEmailCodeSheet()` |  | Равзанаи «рамз ба почта»-ро нишон медиҳад; агар Authenticator лозим бошад, онро мекушояд. |
| `build()` |  | Майдонро бо форматкунии рамз месозад. |
| `createState()` |  | Ҳолати OtpCodeSheet-ро месозад. |
| `dispose()` |  | Майдонро озод мекунад. |
| `_verify()` |  | Рамзро месанҷад; пас аз муваффақият равзанаро мебандад. |
| `build()` |  | Равзанаро бо шарҳ, майдони рамз ва тугма месозад. |
| `createState()` |  | Ҳолати EmailCodeSheet-ро месозад. |
| `dispose()` |  | Майдонҳоро озод мекунад. |
| `_send()` |  | Рамзро ба почта мефиристад. |
| `_verify()` |  | Рамзи почтаро месанҷад; агар Authenticator лозим бошад, true бо Navigator бармегардонад. |
| `build()` |  | Равзанаро бо почта ва, пас аз фиристодан, майдони рамз месозад. |

### `mobile/lib/features/settings/app_update.dart`

санҷиш, зеркашӣ ва насби навсозии Android.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class AppUpdate` |  | Ин қадам ҷавоби server ё хатои API-ро коркард мекунад. |
| `lastError` |  | Қимати lastError-ро барои санҷиш, зеркашӣ ва насби навсозии Android нигоҳ медорад. |
| `installedCode()` |  | installedCode мантиқи зарурии санҷиш, зеркашӣ ва насби навсозии Android-ро иҷро мекунад. |
| `check()` |  | check дурустӣ ва шартҳои зарурии додаҳоро месанҷад. |
| `install()` |  | install мантиқи зарурии санҷиш, зеркашӣ ва насби навсозии Android-ро иҷро мекунад. |
| `class UpdateProgress` |  | Додаҳо ва рафтори марбут ба санҷиш, зеркашӣ ва насби навсозии Android-ро ифода мекунад. |
| `UpdateProgress.fromEvent()` |  | UpdateProgress-ро аз event-и пешрафти Android месозад. |
| `label` |  | Қимати label-ро барои санҷиш, зеркашӣ ва насби навсозии Android нигоҳ медорад. |
| `build()` |  | Widget-и UpdateProgressDialog-ро барои боргирӣ ва насби навсозӣ месозад. |

### `mobile/lib/features/settings/parent_pin.dart`

сохтан ва санҷидани PIN-и волид.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class ParentPin` |  | PIN-и волидайнро тавассути channel-и муҳофизати Android идора мекунад. |
| `isSet()` |  | isSet иҷро шудани шарти вобастаро муайян мекунад. |
| `verify()` |  | verify дурустӣ ва шартҳои зарурии додаҳоро месанҷад. |
| `change()` |  | change ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `setUp()` |  | setUp ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `ask()` |  | ask иҷозат ё маълумоти лозимро дархост мекунад. |
| `createState()` |  | Ҳолати PinDialog-ро барои санҷиш ва гузоштани PIN-и волидайн месозад. |
| `dispose()` |  | Controller ва listener-ҳои PinDialog-ро озод мекунад. |
| `submit()` |  | submit дархости PIN-и волидайн-ро ба API мефиристад ва натиҷаро коркард мекунад. |
| `build()` |  | Widget-и PinDialog-ро барои санҷиш ва гузоштани PIN-и волидайн месозад. |
| `createState()` |  | Ҳолати PinSetupDialog-ро барои санҷиш ва гузоштани PIN-и волидайн месозад. |
| `dispose()` |  | Controller ва listener-ҳои PinSetupDialog-ро озод мекунад. |
| `save()` |  | save тағйироти PIN-и волидайн-ро барои истифодаи баъдӣ нигоҳ медорад. |
| `field()` |  | field мантиқи зарурии сохтан ва санҷидани PIN-и волидро иҷро мекунад. |
| `build()` |  | Widget-и PinSetupDialog-ро барои санҷиш ва гузоштани PIN-и волидайн месозад. |

### `mobile/lib/features/settings/profile_photo.dart`

интихоб ва нигоҳдории акси профил.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `maxAvatarBytes` |  | Қимати maxAvatarBytes-ро барои интихоб ва нигоҳдории акси профил нигоҳ медорад. |
| `_pickWithImagePicker()` |  | pickWithImagePicker мантиқи зарурии интихоб ва нигоҳдории акси профилро иҷро мекунад. |
| `createState()` |  | Ҳолати ProfileAvatarButton-ро барои интихоб ва сабти акси профил месозад. |
| `choose()` |  | choose ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `upload()` |  | upload додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад. |
| `remove()` |  | remove маълумотро ҳазф карда, ҳолати вобастаро нав мекунад. |
| `build()` |  | Widget-и ProfileAvatarButton-ро барои интихоб ва сабти акси профил месозад. |

### `mobile/lib/features/settings/settings_screen.dart`

танзимоти ҳисоб, забон, theme ва амният.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `createState()` |  | Ҳолати SettingsScreen-ро барои танзимоти ҳисоб ва барнома месозад. |
| `initState()` |  | Вазъи огоҳинома, PIN ва версияи насбшударо барои экрани танзимот мехонад. |
| `dispose()` |  | Controller ва listener-ҳои SettingsScreen-ро озод мекунад. |
| `didChangeAppLifecycleState()` |  | Ба тағйири lifecycle-и SettingsScreen ҷавоб медиҳад. |
| `loadNotifyStatus()` |  | loadNotifyStatus додаҳоро мехонад ва ҳолати экранро нав мекунад. |
| `fixNotifications()` |  | fixNotifications мантиқи зарурии танзимоти ҳисоб, забон, theme ва амниятро иҷро мекунад. |
| `loadPin()` |  | loadPin додаҳоро мехонад ва ҳолати экранро нав мекунад. |
| `editName()` |  | editName мантиқи зарурии танзимоти ҳисоб, забон, theme ва амниятро иҷро мекунад. |
| `editPin()` |  | editPin мантиқи зарурии танзимоти ҳисоб, забон, theme ва амниятро иҷро мекунад. |
| `checkUpdate()` |  | checkUpdate дурустӣ ва шартҳои зарурии додаҳоро месанҷад. |
| `signOut()` |  | signOut мантиқи зарурии танзимоти ҳисоб, забон, theme ва амниятро иҷро мекунад. |
| `requestUninstall()` |  | requestUninstall иҷозат ё маълумоти лозимро дархост мекунад. |
| `build()` |  | Экрани танзимотро бо профил, PIN, огоҳиномаҳо, мавзӯъ ва навсозӣ месозад. |
| `build()` |  | Widget-и ProfileCard-ро барои танзимоти ҳисоб ва барнома месозад. |
| `build()` |  | Widget-и Group-ро барои танзимоти ҳисоб ва барнома месозад. |
| `build()` |  | Widget-и Tile-ро барои танзимоти ҳисоб ва барнома месозад. |
| `createState()` |  | Ҳолати NameDialog-ро барои танзимоти ҳисоб ва барнома месозад. |
| `dispose()` |  | Controller ва listener-ҳои NameDialog-ро озод мекунад. |
| `save()` |  | save тағйироти танзимот-ро барои истифодаи баъдӣ нигоҳ медорад. |
| `build()` |  | Widget-и NameDialog-ро барои танзимоти ҳисоб ва барнома месозад. |
| `createState()` |  | Ҳолати UninstallDialog-ро барои танзимоти ҳисоб ва барнома месозад. |
| `dispose()` |  | Controller ва listener-ҳои UninstallDialog-ро озод мекунад. |
| `submit()` |  | submit дархости танзимот-ро ба API мефиристад ва натиҷаро коркард мекунад. |
| `build()` |  | Widget-и UninstallDialog-ро барои танзимоти ҳисоб ва барнома месозад. |

### `mobile/lib/features/settings/theme_mode.dart`

нигоҳдорӣ ва иваз кардани theme.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `load()` |  | load додаҳои мавзӯи рӯзу шаб-ро мехонад ва ҳолати ThemeModeSetting-ро нав мекунад. |
| `set()` |  | set ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |

### `mobile/lib/features/settings/two_step_screen.dart`

экрани «Ҳимояи дуқабата» — фаъол кардани Authenticator бо QR, рамзҳои эҳтиётӣ ва хомӯш кардан.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `createState()` |  | Ҳолати TwoStepScreen-ро месозад. |
| `initState()` |  | Ҳолатро аз сервер мегирад. |
| `dispose()` |  | Майдонро озод мекунад. |
| `_load()` |  | Ҳолати Authenticator-ро аз сервер мехонад. |
| `_run()` |  | Амали серверро бо ҳолати «интизор» ва нишон додани хато иҷро мекунад. |
| `_start()` |  | Калиди навро мегирад ва QR-ро нишон медиҳад. |
| `_confirm()` |  | Аввалин рамзро месанҷад ва рамзҳои эҳтиётиро нишон медиҳад. |
| `_disable()` |  | Бо рамз хомӯш мекунад. |
| `_regenerate()` |  | Рамзҳои эҳтиётии нав месозад. |
| `_codes()` |  | Рӯйхати рамзҳоро аз ҷавоби сервер ҷудо мекунад. |
| `build()` |  | Экранро вобаста ба ҳолат месозад. |
| `build()` |  | Кортро бо ранги ҳолат месозад. |
| `build()` |  | Шарҳ ва тугмаро месозад. |
| `build()` |  | QR-ро дар заминаи сафед (барои скан дар режими торик) нишон медиҳад. |
| `build()` |  | Майдони рамз ва ду тугмаро месозад. |
| `build()` |  | Рӯйхати рамзҳо ва тугмаҳои «Нусха» ва «Тайёр»-ро месозад. |

### `mobile/lib/features/onboarding/child_setup_screen.dart`

сабти профили фарзанд пеш аз пайвасткунӣ.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `createState()` |  | Ҳолати ChildSetupScreen-ро барои насб ва пайвасткунии телефони фарзанд месозад. |
| `didChangeDependencies()` |  | Пас аз тағйири dependency-ҳо ҳолати вобастаро нав мекунад. |
| `dispose()` |  | Controller ва listener-ҳои ChildSetupScreen-ро озод мекунад. |
| `save()` |  | save тағйироти child_setup_screen-ро барои истифодаи баъдӣ нигоҳ медорад. |
| `back()` |  | back мантиқи зарурии сабти профили фарзанд пеш аз пайвасткунӣро иҷро мекунад. |
| `build()` |  | Формаи рамзи пайвасткунӣ ва маълумоти насби телефони фарзандро нишон медиҳад. |

### `mobile/lib/features/onboarding/permission_steps.dart`

қадамҳои иҷозатҳои Android ва санҷиши онҳо.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `enum WizardStepId` |  | Ҳолатҳо ё навъҳои имконпазири қадамҳои иҷозатҳои Android ва санҷиши онҳоро муайян мекунад. |
| `usesRestrictedSettings()` |  | Қадамҳое, ки Android 13+ бо «Controlled by restricted setting» мебандад: Usage access, намоиш болои барномаҳо ва Accessibility. Дар ин қадамҳо корти ёрирасони «App info» нишон дода мешавад. |
| `enum StepStage` |  | Ҳолатҳо ё навъҳои имконпазири қадамҳои иҷозатҳои Android ва санҷиши онҳоро муайян мекунад. |
| `wizardStepsFor()` |  | wizardStepsFor мантиқи зарурии қадамҳои иҷозатҳои Android ва санҷиши онҳоро иҷро мекунад. |
| `class StepStatus` |  | StepStatus додаҳо ва рафтори иҷозатҳои Android-ро ифода мекунад. |
| `class WizardPlatform` |  | WizardPlatform додаҳо ва рафтори иҷозатҳои Android-ро ифода мекунад. |
| `protection()` |  | protection мантиқи зарурии қадамҳои иҷозатҳои Android ва санҷиши онҳоро иҷро мекунад. |
| `status()` |  | status мантиқи зарурии қадамҳои иҷозатҳои Android ва санҷиши онҳоро иҷро мекунад. |
| `request()` |  | request иҷозат ё маълумоти лозимро дархост мекунад. |
| `locationServiceEnabled()` |  | locationServiceEnabled мантиқи зарурии қадамҳои иҷозатҳои Android ва санҷиши онҳоро иҷро мекунад. |
| `openLocationSettings()` |  | openLocationSettings экран, dialog ё танзимоти мувофиқро мекушояд. |
| `openAppSettings()` |  | openAppSettings экран, dialog ё танзимоти мувофиқро мекушояд. |
| `invoke()` |  | invoke мантиқи зарурии қадамҳои иҷозатҳои Android ва санҷиши онҳоро иҷро мекунад. |
| `notifyStatus()` |  | notifyStatus listener ё корбарро аз тағйирот огоҳ мекунад. |
| `openFullScreenSettings()` |  | openFullScreenSettings экран, dialog ё танзимоти мувофиқро мекушояд. |
| `toString()` |  | Намоиши матнии WizardException-ро барои log бармегардонад. |
| `wizardErrorText()` |  | wizardErrorText мантиқи зарурии қадамҳои иҷозатҳои Android ва санҷиши онҳоро иҷро мекунад. |
| `class WizardStep` |  | WizardStep додаҳо ва рафтори иҷозатҳои Android-ро ифода мекунад. |
| `locationAlways` |  | Қимати locationAlways-ро барои қадамҳои иҷозатҳои Android ва санҷиши онҳо нигоҳ медорад. |
| `of()` |  | of мантиқи зарурии қадамҳои иҷозатҳои Android ва санҷиши онҳоро иҷро мекунад. |
| `protectionKeyOf()` |  | protectionKeyOf мантиқи зарурии қадамҳои иҷозатҳои Android ва санҷиши онҳоро иҷро мекунад. |
| `class WizardActions` |  | WizardActions додаҳо ва рафтори иҷозатҳои Android-ро ифода мекунад. |
| `readAll()` |  | readAll додаҳоро мехонад ва ҳолати экранро нав мекунад. |
| `_read()` |  | read додаҳоро мехонад ва ҳолати экранро нав мекунад. |
| `_blocked()` |  | blocked мантиқи зарурии қадамҳои иҷозатҳои Android ва санҷиши онҳоро иҷро мекунад. |
| `openAppInfo()` |  | Саҳифаи маълумоти барномаи NIGOH Family-ро мекушояд (ҳамон сафҳа, ки дар он менюи ⋮ ҳаст). |
| `grant()` |  | grant мантиқи зарурии қадамҳои иҷозатҳои Android ва санҷиши онҳоро иҷро мекунад. |
| `openFallback()` |  | openFallback экран, dialog ё танзимоти мувофиқро мекушояд. |
| `openLocationSettings()` |  | openLocationSettings экран, dialog ё танзимоти мувофиқро мекушояд. |

### `mobile/lib/features/onboarding/permissions_wizard.dart`

роҳнамои пайдарпайи иҷозатҳои барнома.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `shownThisSession` |  | Қимати shownThisSession-ро барои роҳнамои пайдарпайи иҷозатҳои барнома нигоҳ медорад. |
| `doneKey()` |  | doneKey мантиқи зарурии роҳнамои пайдарпайи иҷозатҳои барномаро иҷро мекунад. |
| `isDone()` |  | isDone иҷро шудани шарти вобастаро муайян мекунад. |
| `markDone()` |  | markDone дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `open()` |  | open экран ё dialog-и лозими иҷозатҳои Android-ро мекушояд. |
| `createState()` |  | Ҳолати PermissionsWizard-ро барои қадамҳои додани иҷозатҳои Android месозад. |
| `attempted` |  | Қимати attempted-ро барои роҳнамои пайдарпайи иҷозатҳои барнома нигоҳ медорад. |
| `bool` |  | Қимати ҳисобшудаи onSummary-ро аз ҳолати ҷорӣ бармегардонад. |
| `currentId` |  | Қимати ҳисобшудаи currentId-ро аз ҳолати ҷорӣ бармегардонад. |
| `role` |  | Қимати ҳисобшудаи role-ро аз ҳолати ҷорӣ бармегардонад. |
| `initState()` |  | Wizard-ро барои session қайд карда, вазъи иҷозатҳои Android-ро мехонад. |
| `dispose()` |  | Controller ва listener-ҳои PermissionsWizard-ро озод мекунад. |
| `didChangeAppLifecycleState()` |  | Ба тағйири lifecycle-и PermissionsWizard ҷавоб медиҳад. |
| `refresh()` |  | refresh додаҳои иҷозатҳои Android-ро боз мехонад ва PermissionsWizard-ро нав мекунад. |
| `scheduleAdvance()` |  | scheduleAdvance раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад. |
| `go()` |  | go экран, dialog ё танзимоти мувофиқро мекушояд. |
| `run()` |  | run мантиқи зарурии роҳнамои пайдарпайи иҷозатҳои барномаро иҷро мекунад. |
| `finish()` |  | finish мантиқи зарурии роҳнамои пайдарпайи иҷозатҳои барномаро иҷро мекунад. |
| `attemptKeyOf()` |  | attemptKeyOf мантиқи зарурии роҳнамои пайдарпайи иҷозатҳои барномаро иҷро мекунад. |
| `build()` |  | Қадами ҷории иҷозатҳои Android-ро бо шарҳ ва тугмаи амал нишон медиҳад. |
| `build()` |  | Widget-и ProgressDots-ро барои қадамҳои додани иҷозатҳои Android месозад. |
| `build()` |  | Widget-и IconTile-ро барои қадамҳои додани иҷозатҳои Android месозад. |
| `build()` |  | Widget-и StepPage-ро барои қадамҳои додани иҷозатҳои Android месозад. |
| `build()` |  | Widget-и Notice-ро барои қадамҳои додани иҷозатҳои Android месозад. |
| `build()` |  | Widget-и HelpCard-ро барои қадамҳои додани иҷозатҳои Android месозад. |
| `build()` |  | Widget-и SummaryPage-ро барои қадамҳои додани иҷозатҳои Android месозад. |
| `build()` |  | Widget-и SummaryRow-ро барои қадамҳои додани иҷозатҳои Android месозад. |
| `build()` |  | Widget-и ErrorBanner-ро барои қадамҳои додани иҷозатҳои Android месозад. |
| `build()` |  | Кортро бо сарлавҳа, чор қадами рақамдор, эзоҳ ва тугмаи «App info» месозад. |

### `mobile/lib/features/onboarding/role_screen.dart`

интихоби нақши волид ё фарзанд.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `createState()` |  | Ҳолати RoleScreen-ро барои интихоби нақши волид ё фарзанд месозад. |
| `choose()` |  | choose ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `build()` |  | Интихоби нақши волид ё фарзандро ҳамчун ду корти амал нишон медиҳад. |
| `build()` |  | Widget-и RoleCard-ро барои интихоби нақши волид ё фарзанд месозад. |


## Барнома — чат ва занг

### `mobile/lib/features/chat/chat_screen.dart`

chat-и волид ва фарзанд.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `chatCallText` |  | Қимати chatCallText-ро барои chat-и волид ва фарзанд нигоҳ медорад. |
| `chatQuickReplies` |  | Қимати chatQuickReplies-ро барои chat-и волид ва фарзанд нигоҳ медорад. |
| `createState()` |  | Ҳолати ChatScreen-ро барои чат байни волид ва фарзанд месозад. |
| `class _Pending` |  | Pending додаҳо ва рафтори чати волид ва фарзанд-ро ифода мекунад. |
| `_api` |  | Қимати ҳисобшудаи api-ро аз ҳолати ҷорӣ бармегардонад. |
| `_myRole` |  | Қимати ҳисобшудаи myRole-ро аз ҳолати ҷорӣ бармегардонад. |
| `_myLast()` |  | myLast мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад. |
| `_fetchAfter()` |  | fetchAfter додаҳоро мехонад ва ҳолати экранро нав мекунад. |
| `initState()` |  | Матни воридшавандаро мешунавад, паёмҳоро бор мекунад ва polling-и чатро оғоз менамояд. |
| `_onInput()` |  | onInput рӯйдодро коркард карда, ҳолати вобастаро нав мекунад. |
| `didUpdateWidget()` |  | Пас аз иваз шудани параметрҳои widget ҳолати дохилиро ҳамоҳанг месозад. |
| `didChangeAppLifecycleState()` |  | Ба тағйири lifecycle-и ChatScreen ҷавоб медиҳад. |
| `_startPolling()` |  | startPolling раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад. |
| `dispose()` |  | Controller ва listener-ҳои ChatScreen-ро озод мекунад. |
| `_load()` |  | load додаҳои чати волид ва фарзанд-ро мехонад ва ҳолати ChatScreen-ро нав мекунад. |
| `_markRead()` |  | markRead дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `_merge()` |  | merge мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад. |
| `_scrollToBottom()` |  | scrollToBottom мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад. |
| `_send()` |  | send дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `_sendText()` |  | sendText дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `_retry()` |  | retry мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад. |
| `_deliver()` |  | deliver мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад. |
| `_call()` |  | call мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад. |
| `build()` |  | Экрани чатро бо таърихи паёмҳо, ҷавобҳои зуд ва сатри навиштан месозад. |
| `_body()` |  | body мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад. |
| `createState()` |  | Ҳолати Entry-ро барои чат байни волид ва фарзанд месозад. |
| `initState()` |  | Animation-и пайдо шудани паёми нави чатро оғоз мекунад. |
| `dispose()` |  | Controller ва listener-ҳои Entry-ро озод мекунад. |
| `build()` |  | Widget-и Entry-ро барои чат байни волид ва фарзанд месозад. |
| `_two()` |  | two мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад. |
| `_hhmm()` |  | hhmm мантиқи зарурии chat-и волид ва фарзандро иҷро мекунад. |
| `build()` |  | Widget-и DaySeparator-ро барои чат байни волид ва фарзанд месозад. |
| `build()` |  | Widget-и Bubble-ро барои чат байни волид ва фарзанд месозад. |
| `build()` |  | Widget-и UrgentBubble-ро барои чат байни волид ва фарзанд месозад. |
| `_icons` |  | Қимати _icons-ро барои chat-и волид ва фарзанд нигоҳ медорад. |
| `build()` |  | Widget-и QuickReplies-ро барои чат байни волид ва фарзанд месозад. |
| `build()` |  | Widget-и CallChip-ро барои чат байни волид ва фарзанд месозад. |
| `build()` |  | Widget-и ErrorBanner-ро барои чат байни волид ва фарзанд месозад. |
| `build()` |  | Widget-и InputBar-ро барои чат байни волид ва фарзанд месозад. |

### `mobile/lib/features/call/call_controller.dart`

ҳолат ва signaling-и занги WebRTC.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `enum CallState` |  | Ҳолатҳо ё навъҳои имконпазири ҳолат ва signaling-и занги WebRTC-ро муайян мекунад. |
| `enum CallEndReason` |  | Ҳолатҳо ё навъҳои имконпазири ҳолат ва signaling-и занги WebRTC-ро муайян мекунад. |
| `label` |  | Қимати ҳисобшудаи label-ро аз ҳолати ҷорӣ бармегардонад. |
| `requestMicrophonePermission()` |  | requestMicrophonePermission иҷозат ё маълумоти лозимро дархост мекунад. |
| `Function()` |  | Function мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад. |
| `state` |  | Қимати ҳисобшудаи state-ро аз ҳолати ҷорӣ бармегардонад. |
| `endReason` |  | Қимати ҳисобшудаи endReason-ро аз ҳолати ҷорӣ бармегардонад. |
| `endMessage` |  | Қимати endMessage-ро барои ҳолат ва signaling-и занги WebRTC нигоҳ медорад. |
| `bool` |  | Қимати ҳисобшудаи isCaller-ро аз ҳолати ҷорӣ бармегардонад. |
| `bool` |  | Қимати ҳисобшудаи muted-ро аз ҳолати ҷорӣ бармегардонад. |
| `bool` |  | Қимати ҳисобшудаи speaker-ро аз ҳолати ҷорӣ бармегардонад. |
| `duration` |  | Қимати duration-ро барои ҳолат ва signaling-и занги WebRTC нигоҳ медорад. |
| `bool` |  | Қимати ҳисобшудаи ended-ро аз ҳолати ҷорӣ бармегардонад. |
| `startOutgoing()` |  | startOutgoing раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад. |
| `startIncoming()` |  | startIncoming раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад. |
| `accept()` |  | accept мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад. |
| `decline()` |  | decline раванди фаъолро қатъ карда, захираҳои онро озод мекунад. |
| `hangUp()` |  | hangUp раванди фаъолро қатъ карда, захираҳои онро озод мекунад. |
| `toggleMute()` |  | toggleMute ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `toggleSpeaker()` |  | toggleSpeaker ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `_openEngine()` |  | openEngine экран, dialog ё танзимоти мувофиқро мекушояд. |
| `_onLink()` |  | onLink рӯйдодро коркард карда, ҳолати вобастаро нав мекунад. |
| `_becomeActive()` |  | becomeActive мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад. |
| `_startConnectTimer()` |  | startConnectTimer раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад. |
| `_enterConnecting()` |  | enterConnecting мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад. |
| `_send()` |  | send дархостро ба API мефиристад ва натиҷаро коркард мекунад. |
| `_answer()` |  | answer мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад. |
| `_flushCandidates()` |  | flushCandidates мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад. |
| `_addCandidate()` |  | addCandidate мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад. |
| `_startPolling()` |  | startPolling раванди лозимро оғоз ва захираҳои вобастаро фаъол мекунад. |
| `_pollLoop()` |  | pollLoop мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад. |
| `_handleSignal()` |  | handleSignal рӯйдодро коркард карда, ҳолати вобастаро нав мекунад. |
| `_handleStatus()` |  | handleStatus рӯйдодро коркард карда, ҳолати вобастаро нав мекунад. |
| `_sleep()` |  | sleep мантиқи зарурии ҳолат ва signaling-и занги WebRTC-ро иҷро мекунад. |
| `_end()` |  | end раванди фаъолро қатъ карда, захираҳои онро озод мекунад. |
| `_notifyServerEnd()` |  | notifyServerEnd listener ё корбарро аз тағйирот огоҳ мекунад. |
| `_setState()` |  | setState ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `_notify()` |  | notify listener ё корбарро аз тағйирот огоҳ мекунад. |
| `dispose()` |  | Controller ва listener-ҳои CallController-ро озод мекунад. |

### `mobile/lib/features/call/call_screen.dart`

интерфейси занги овозӣ.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `Function()` |  | Function мантиқи зарурии интерфейси занги овозӣро иҷро мекунад. |
| `Function()` |  | Function мантиқи зарурии интерфейси занги овозӣро иҷро мекунад. |
| `bool` |  | Қимати isOpen-ро барои интерфейси занги овозӣ нигоҳ медорад. |
| `_controller()` |  | controller мантиқи зарурии интерфейси занги овозӣро иҷро мекунад. |
| `openOutgoing()` |  | openOutgoing экран, dialog ё танзимоти мувофиқро мекушояд. |
| `openIncoming()` |  | openIncoming экран, dialog ё танзимоти мувофиқро мекушояд. |
| `_push()` |  | push мантиқи зарурии интерфейси занги овозӣро иҷро мекунад. |
| `createState()` |  | Ҳолати CallScreen-ро барои занг байни волид ва фарзанд месозад. |
| `_c` |  | Қимати ҳисобшудаи c-ро аз ҳолати ҷорӣ бармегардонад. |
| `initState()` |  | Тағйири controller-и зангро мешунавад ва ҳолати ибтидоии зангро ҳамоҳанг месозад. |
| `_onChange()` |  | onChange рӯйдодро коркард карда, ҳолати вобастаро нав мекунад. |
| `_sync()` |  | sync додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад. |
| `dispose()` |  | Controller ва listener-ҳои CallScreen-ро озод мекунад. |
| `_status` |  | Қимати _status-ро барои интерфейси занги овозӣ нигоҳ медорад. |
| `bool` |  | Қимати _endIsProblem-ро барои интерфейси занги овозӣ нигоҳ медорад. |
| `_reduced` |  | Қимати _reduced-ро барои интерфейси занги овозӣ нигоҳ медорад. |
| `build()` |  | Экрани зангро бо ҳолати пайвастшавӣ, avatar ва идораҳои садо месозад. |
| `_content()` |  | content мантиқи зарурии интерфейси занги овозӣро иҷро мекунад. |
| `_dotColor` |  | Қимати _dotColor-ро барои интерфейси занги овозӣ нигоҳ медорад. |
| `_hint` |  | Қимати _hint-ро барои интерфейси занги овозӣ нигоҳ медорад. |
| `_controls()` |  | controls мантиқи зарурии интерфейси занги овозӣро иҷро мекунад. |
| `formatCallDuration()` |  | formatCallDuration додаҳоро ба шакли барои истифода мувофиқ табдил медиҳад. |
| `letterText` |  | Қимати letterText-ро барои интерфейси занги овозӣ нигоҳ медорад. |
| `build()` |  | Widget-и Avatar-ро барои занг байни волид ва фарзанд месозад. |
| `_ring()` |  | ring мантиқи зарурии интерфейси занги овозӣро иҷро мекунад. |
| `build()` |  | Widget-и RoundButton-ро барои занг байни волид ва фарзанд месозад. |
| `build()` |  | Widget-и StatusLine-ро барои занг байни волид ва фарзанд месозад. |
| `createState()` |  | Ҳолати Dot-ро барои занг байни волид ва фарзанд месозад. |
| `initState()` |  | Animation-и набзи нуқтаи ҳолати зангро ҳангоми зарурат оғоз мекунад. |
| `didUpdateWidget()` |  | Пас аз иваз шудани параметрҳои widget ҳолати дохилиро ҳамоҳанг месозад. |
| `dispose()` |  | Controller ва listener-ҳои Dot-ро озод мекунад. |
| `build()` |  | Widget-и Dot-ро барои занг байни волид ва фарзанд месозад. |

### `mobile/lib/features/call/rtc_engine.dart`

пайвасти WebRTC, media stream ва ICE signaling.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `enum RtcLinkState` |  | Ҳолатҳо ё навъҳои имконпазири пайвасти WebRTC, media stream ва ICE signaling-ро муайян мекунад. |
| `class RtcEngine` |  | Додаҳо ва рафтори марбут ба пайвасти WebRTC, media stream ва ICE signaling-ро ифода мекунад. |
| `Function()` |  | ICE candidate-и маҳаллиро барои фиристодан ба ҳамсуҳбат мерасонад. |
| `Function()` |  | Тағйири ҳолати пайвасти WebRTC-ро ба controller хабар медиҳад. |
| `open()` |  | open экран ё dialog-и лозими занг ва signaling-и WebRTC-ро мекушояд. |
| `createOffer()` |  | createOffer мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад. |
| `createAnswer()` |  | createAnswer мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад. |
| `setRemote()` |  | setRemote ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `addCandidate()` |  | addCandidate мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад. |
| `setMuted()` |  | setMuted ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `setSpeaker()` |  | setSpeaker ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `close()` |  | close мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад. |
| `Function()` |  | Callback-и ICE candidate-и тавлидшударо нигоҳ медорад. |
| `Function()` |  | Callback-и ҳолати нави пайвасти peer-ро нигоҳ медорад. |
| `_peer` |  | Қимати ҳисобшудаи peer-ро барои пайвасти WebRTC, media stream ва ICE signaling бармегардонад. |
| `open()` |  | open экран ё dialog-и лозими занг ва signaling-и WebRTC-ро мекушояд. |
| `_desc()` |  | desc мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад. |
| `createOffer()` |  | createOffer мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад. |
| `createAnswer()` |  | createAnswer мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад. |
| `setRemote()` |  | setRemote ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `addCandidate()` |  | addCandidate мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад. |
| `setMuted()` |  | setMuted ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `setSpeaker()` |  | setSpeaker ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `close()` |  | close мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад. |


## Барнома — UI ва тарҷума

### `mobile/lib/ui/avatar.dart`

avatar ва нишондиҳандаи online.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `Wid` |  | Қимати badge-ро барои avatar ва нишондиҳандаи online нигоҳ медорад. |
| `letterOf()` |  | letterOf мантиқи зарурии avatar ва нишондиҳандаи online-ро иҷро мекунад. |
| `build()` |  | Widget-и AvatarView-ро барои аватар ва ҳолати он месозад. |
| `build()` |  | Widget-и AvatarDot-ро барои аватар ва ҳолати он месозад. |

### `mobile/lib/ui/day_night_switch.dart`

калиди аниматсионии theme-и рӯз ва шаб.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `createState()` |  | Ҳолати DayNightSwitch-ро барои иваз кардани мавзӯи рӯзу шаб месозад. |
| `didUpdateWidget()` |  | Пас аз иваз шудани параметрҳои widget ҳолати дохилиро ҳамоҳанг месозад. |
| `dispose()` |  | Controller ва listener-ҳои DayNightSwitch-ро озод мекунад. |
| `build()` |  | Widget-и DayNightSwitch-ро барои иваз кардани мавзӯи рӯзу шаб месозад. |
| `paint()` |  | Унсурҳои графикиро дар canvas мекашад. |
| `_sparkle()` |  | sparkle мантиқи зарурии калиди аниматсионии theme-и рӯз ва шабро иҷро мекунад. |
| `shouldRepaint()` |  | Муайян мекунад, ки CustomPainter бояд аз нав кашида шавад ё не. |

### `mobile/lib/ui/github_mark.dart`

нишонаи GitHub барои OAuth.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `build()` |  | Нишони GitHub-ро бо андоза ва ранги додашуда мекашад. |
| `paint()` |  | Унсурҳои графикиро дар canvas мекашад. |
| `shouldRepaint()` |  | Муайян мекунад, ки CustomPainter бояд аз нав кашида шавад ё не. |

### `mobile/lib/ui/language_picker.dart`

интихоби забон ва тугмаи он.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `languageCode()` |  | languageCode мантиқи зарурии интихоби забон ва тугмаи онро иҷро мекунад. |
| `showLanguageSheet()` |  | showLanguageSheet экран, dialog ё танзимоти мувофиқро мекушояд. |
| `build()` |  | Widget-и LanguageButton-ро барои интихоб ва иваз кардани забон месозад. |

### `mobile/lib/ui/nigoh_design.dart`

рангҳо ва widget-ҳои системаи тарроҳии NIGOH.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class NigohDesign` |  | Қадами дохилии рангҳо ва widget-ҳои системаи тарроҳии NIGOH. |
| `accents` |  | Қимати accents-ро барои рангҳо ва widget-ҳои системаи тарроҳии NIGOH нигоҳ медорад. |
| `accentFor()` |  | accentFor мантиқи зарурии рангҳо ва widget-ҳои системаи тарроҳии NIGOH-ро иҷро мекунад. |
| `build()` |  | Widget-и NigohHeroCard-ро барои ҷузъҳои низоми тарроҳии NIGOH месозад. |
| `build()` |  | Widget-и NigohSectionHeader-ро барои ҷузъҳои низоми тарроҳии NIGOH месозад. |
| `build()` |  | Widget-и NigohActionCard-ро барои ҷузъҳои низоми тарроҳии NIGOH месозад. |
| `build()` |  | Widget-и NigohStatusPill-ро барои ҷузъҳои низоми тарроҳии NIGOH месозад. |
| `decode()` |  | decode додаҳоро ба шакли барои истифода мувофиқ табдил медиҳад. |
| `build()` |  | Widget-и NigohAppIcon-ро барои ҷузъҳои низоми тарроҳии NIGOH месозад. |

### `mobile/lib/ui/stat_meter.dart`

нишондиҳандаҳои аниматсионии омор ва маҳдудият.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `double` |  | Қимати ҳисобшудаи fraction-ро аз ҳолати ҷорӣ бармегардонад. |
| `_number()` |  | number мантиқи зарурии нишондиҳандаҳои аниматсионии омор ва маҳдудиятро иҷро мекунад. |
| `build()` |  | Widget-и StatMeter-ро барои нишондиҳандаҳои омор ва маҳдудият месозад. |
| `build()` |  | Widget-и StatBar-ро барои нишондиҳандаҳои омор ва маҳдудият месозад. |
| `fill()` |  | fill мантиқи зарурии нишондиҳандаҳои аниматсионии омор ва маҳдудиятро иҷро мекунад. |
| `build()` |  | Widget-и StatTile-ро барои нишондиҳандаҳои омор ва маҳдудият месозад. |
| `_numberStyle()` |  | numberStyle мантиқи зарурии нишондиҳандаҳои аниматсионии омор ва маҳдудиятро иҷро мекунад. |

### `mobile/lib/ui/theme.dart`

theme-ҳои равшан ва торики Material 3.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class NigohTheme` |  | Қадами дохилии theme-ҳои равшан ва торики Material 3. |
| `light()` |  | light мантиқи зарурии theme-ҳои равшан ва торики Material 3-ро иҷро мекунад. |
| `dark()` |  | dark мантиқи зарурии theme-ҳои равшан ва торики Material 3-ро иҷро мекунад. |
| `_build()` |  | Widget-и -ро барои мавзӯъ ва рангҳои барнома месозад. |

### `mobile/lib/ui/widgets.dart`

widget, animation ва helper-ҳои муштараки интерфейс.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `reducedMotion()` |  | reducedMotion мантиқи зарурии widget, animation ва helper-ҳои муштараки интерфейсро иҷро мекунад. |
| `showMessage()` |  | showMessage экран, dialog ё танзимоти мувофиқро мекушояд. |
| `build()` |  | Widget-и StateMessage-ро барои ҷузъҳои умумии интерфейс месозад. |
| `build()` |  | Widget-и SectionTitle-ро барои ҷузъҳои умумии интерфейс месозад. |
| `build()` |  | Widget-и ScreenHint-ро барои ҷузъҳои умумии интерфейс месозад. |
| `build()` |  | Widget-и Pill-ро барои ҷузъҳои умумии интерфейс месозад. |
| `build()` |  | Widget-и FadeIn-ро барои ҷузъҳои умумии интерфейс месозад. |
| `createState()` |  | Ҳолати TapScale-ро барои ҷузъҳои умумии интерфейс месозад. |
| `build()` |  | Widget-и TapScale-ро барои ҷузъҳои умумии интерфейс месозад. |
| `timeAgo()` |  | timeAgo мантиқи зарурии widget, animation ва helper-ҳои муштараки интерфейсро иҷро мекунад. |
| `two()` |  | two мантиқи зарурии widget, animation ва helper-ҳои муштараки интерфейсро иҷро мекунад. |
| `parseServerTime()` |  | parseServerTime додаҳоро ба шакли барои истифода мувофиқ табдил медиҳад. |

### `mobile/lib/l10n/l10n.dart`

интихоби забон ва тарҷумаи матнҳо.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `load()` |  | load додаҳои l10n-ро мехонад ва ҳолати AppLanguage-ро нав мекунад. |
| `set()` |  | set ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад. |
| `materialLocale` |  | Қимати materialLocale-ро барои интихоби забон ва тарҷумаи матнҳо нигоҳ медорад. |
| `tr()` |  | tr мантиқи зарурии интихоби забон ва тарҷумаи матнҳоро иҷро мекунад. |
| `untranslatedKeys()` |  | untranslatedKeys мантиқи зарурии интихоби забон ва тарҷумаи матнҳоро иҷро мекунад. |

### `mobile/lib/l10n/strings_child.dart`

луғати тарҷумаҳои бахши фарзанд.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `childStrings` |  | Map-и матни тоҷикӣ ба тарҷумаҳои русӣ ва англисиро нигоҳ медорад. |

### `mobile/lib/l10n/strings_core.dart`

луғати тарҷумаҳои умумӣ, воридшавӣ ва танзимот.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `coreStrings` |  | Map-и матни тоҷикӣ ба тарҷумаҳои русӣ ва англисиро нигоҳ медорад. |

### `mobile/lib/l10n/strings_parent.dart`

луғати тарҷумаҳои бахши волид.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `parentStrings` |  | Map-и матни тоҷикӣ ба тарҷумаҳои русӣ ва англисиро нигоҳ медорад. |

### `mobile/lib/pages/access_center_page.dart`

маркази санҷиш ва кушодани иҷозатҳои Android.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `createState()` |  | Ҳолати AccessCenterPage-ро барои иҷозатҳои муҳофизати Android месозад. |
| `allowed()` |  | allowed иҷро шудани шарти вобастаро муайян мекунад. |
| `initState()` |  | Тағйири lifecycle-ро назорат карда, вазъи иҷозатҳои Android-ро мехонад. |
| `dispose()` |  | Controller ва listener-ҳои AccessCenterPage-ро озод мекунад. |
| `didChangeAppLifecycleState()` |  | Ба тағйири lifecycle-и AccessCenterPage ҷавоб медиҳад. |
| `refresh()` |  | refresh додаҳои маркази иҷозатҳо-ро боз мехонад ва AccessCenterPage-ро нав мекунад. |
| `act()` |  | act мантиқи зарурии маркази санҷиш ва кушодани иҷозатҳои Android-ро иҷро мекунад. |
| `open()` |  | open экран ё dialog-и лозими маркази иҷозатҳо-ро мекушояд. |
| `request()` |  | request иҷозат ё маълумоти лозимро дархост мекунад. |
| `runStep()` |  | runStep мантиқи зарурии маркази санҷиш ва кушодани иҷозатҳои Android-ро иҷро мекунад. |
| `bool` |  | Қимати protectionReady-ро барои маркази санҷиш ва кушодани иҷозатҳои Android нигоҳ медорад. |
| `activeKey` |  | Қимати ҳисобшудаи activeKey-ро барои маркази санҷиш ва кушодани иҷозатҳои Android бармегардонад. |
| `activeImage` |  | Қимати ҳисобшудаи activeImage-ро барои маркази санҷиш ва кушодани иҷозатҳои Android бармегардонад. |
| `steps` |  | Қимати steps-ро барои маркази санҷиш ва кушодани иҷозатҳои Android нигоҳ медорад. |
| `build()` |  | Маркази иҷозатҳоро бо пешрафт ва қадамҳои танзимоти Android нишон медиҳад. |
| `class _PermissionStepData` |  | Додаҳо ва рафтори марбут ба маркази санҷиш ва кушодани иҷозатҳои Android-ро ифода мекунад. |
| `build()` |  | Widget-и PermissionStepCard-ро барои иҷозатҳои муҳофизати Android месозад. |


## Android (Kotlin)

### `mobile/android/app/src/main/kotlin/tj/nigoh/nigoh_family_parent/AppBlockMonitorService.kt`

foreground service барои бастани барномаҳои телефони фарзанд;

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class AppBlockMonitorService` |  | Қоидаҳои волидайнро дар телефони фарзанд татбиқ мекунад: барномаи фаъол ва вақти истифодаашро назорат карда, барои манъ, ҷадвал ё лимит overlay нишон медиҳад. |
| `class ForegroundApp` |  | package ва class-и Activity-и ҳозир фаъолро нигоҳ медорад. |
| `onReceive()` |  | Ба тағйири ҳолати экран ҷавоб дода, monitor ва overlay-ро идора мекунад. |
| `run()` |  | Як даври назоратро иҷро ва даври навбатиро ба навбат мегузорад. |
| `ensureWebFilter()` |  | Агар волидайн филтрро фаъол карда бошанд ва он қатъ шуда бошад, онро аз нав оғоз мекунад. |
| `onCreate()` |  | Хидматҳои система, receiver-и экран ва огоҳиномаи foreground-ро омода карда, назоратро оғоз мекунад. |
| `onStartCommand()` |  | Дархости overlay-и Accessibility-ро коркард карда, хидматро sticky нигоҳ медорад. |
| `handleAccessibilityRequest()` |  | Барои барномаи аз Accessibility омада overlay-и басташавиро нишон медиҳад. |
| `onDestroy()` |  | Назоратро қатъ, истифодаи ҷориро сабт ва overlay-ро хориҷ мекунад. |
| `onBind()` |  | Нишон медиҳад, ки ин хидмат binding-ро дастгирӣ намекунад. |
| `checkForegroundApp()` |  | Барномаи фаъолро ёфта, истифодаашро сабт мекунад ва мувофиқи қоида overlay-ро идора менамояд. |
| `rolloverLocalUsageIfNeeded()` |  | Дар нисфи шаб ҳисобкунакҳои рӯзи навро оғоз мекунад; ақиб бурдани соат лимити рӯзонаро аз нав намекунад. |
| `recordForegroundSession()` |  | Давомнокии кори барномаи фаъолро ҳисоб карда, давра ба давра нигоҳ медорад. |
| `flushActiveUsage()` |  | Сония ва дақиқаҳои ҷамъшудаи барномаи фаъолро ба shared preferences менависад. |
| `finishActiveSession()` |  | session-и дар memory будаи барномаи фаъолро ба охир мерасонад. |
| `ruleFor()` |  | Қоидаи [packageName]-ро аз JSON-и нигоҳдошта меёбад. |
| `todayUsageMillis()` |  | Истифодаи имрӯзаи барномаро аз қимати калонтарини Android ва ҳисобкунаки NIGOH мегирад. |
| `goHome()` |  | Корбарро ба экрани Home-и Android мебарад. |
| `isScheduleActive()` |  | Фаъол будани фосилаи ҷадвалро муайян мекунад; фосилаи шабгузар ба рӯзи оғоз тааллуқ дорад. |
| `enabledOn()` |  | Интихоб шудани рӯзи додашударо дар ҷадвал месанҷад. |
| `parseMinutes()` |  | Вақти «HH:mm»-ро ба дақиқаҳои баъди нисфи шаб табдил медиҳад. |
| `latestForegroundPackage()` |  | Барномаи охирини foreground-ро аз UsageEvents ё аз истифодаи охирин меёбад. |
| `showOverlay()` |  | Барои [blockedPackage] overlay-и пурраро бо [reason] нишон медиҳад; дар ҳолати [tamper] PIN-и волидайнро мепурсад. |
| `dp()` |  | dp-ро барои зичии экран ба pixel табдил медиҳад. |
| `onKeyPreIme()` |  | Тугмаи Back-ро гирифта, корбарро ба Home мебарад. |
| `removeOverlay()` |  | Overlay-и басташавиро, агар намоён бошад, хориҷ мекунад. |
| `verifyParentPin()` |  | PIN-и чоррақамаи волидайнро бо [PinSecurity] месанҷад. |
| `createNotificationChannel()` |  | Channel-и аҳамияташ пастро барои огоҳиномаи муҳофизати фаъол месозад. |
| `isDeviceAdminEnabled()` |  | Фаъол будани NIGOH-ро ҳамчун device admin месанҷад. |
| `hasUsageAccess()` |  | Мавҷуд будани usage access-ро барои дидани барномаи фаъол месанҷад. |
| `isAccessibilityEnabled()` |  | Фаъол будани Accessibility service-и NIGOH-ро месанҷад. |
| `requestOverlayFromAccessibility()` |  | Аз хидмат барои [targetPackage] overlay-и фаврии басташавиро дархост мекунад. |

### `mobile/android/app/src/main/kotlin/tj/nigoh/nigoh_family_parent/AppLang.kt`

маҳаллигардонии қисми Android — забони Flutter-ро мехонад ва

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `object AppLang` |  | Забони интихобшудаи барномаро аз shared_preferences-и Flutter мехонад. Қиматҳои имконпазир 'tg', 'ru', 'en' буда, қимати пешфарз 'tg' аст. |
| `of()` |  | Рамзи забони ҷории барномаро аз танзимоти Flutter мехонад. |
| `pick()` |  | Матни мувофиқи [lang]-ро интихоб мекунад; барои қимати ношинос тоҷикӣ медиҳад. |
| `pick()` |  | Матнро мувофиқи забони ҷории барнома интихоб мекунад. |
| `object UiStrings` |  | Матнҳои маҳаллигардонидашудаи экранҳои native ва навсозиро таъмин мекунад. |
| `t()` |  | Матнро бо забони ҷории барнома интихоб мекунад. |
| `reasonBlocked()` |  | Сабаби бастани мустақими барномаро медиҳад. |
| `reasonSchedule()` |  | Сабаби маҳдудият аз рӯйи ҷадвалро медиҳад. |
| `reasonLimit()` |  | Сабаби ба охир расидани лимити рӯзонаро медиҳад. |
| `overlayManaged()` |  | Шарҳи назорати волидайнро бо номи барнома месозад. |
| `parentPinHint()` |  | Hint-и майдони PIN-и волидайнро медиҳад. |
| `confirmPin()` |  | Матни тугмаи тасдиқи PIN-ро медиҳад. |
| `wrongPinShort()` |  | Хабари кӯтоҳи PIN-и нодурустро медиҳад. |
| `toHome()` |  | Матни гузариш ба экрани асосиро медиҳад. |
| `protectionActive()` |  | Вазъи фаъол будани муҳофизати барномаҳоро медиҳад. |
| `protectionChannel()` |  | Номи channel-и муҳофизати NIGOH-ро медиҳад. |
| `lockTitle()` |  | Сарлавҳаи экрани қулфро медиҳад. |
| `shieldCaption()` |  | Имзои NIGOH SHIELD-ро медиҳад. |
| `restrictedSubtitle()` |  | Шарҳи кӯтоҳи маҳдудияти дастрасиро медиҳад. |
| `categoryEntertainment()` |  | Номи категорияи фароғатро медиҳад. |
| `blockedBadge()` |  | Нишони ҳолати басташударо медиҳад. |
| `dailyLimitLine()` |  | Сатри лимити пуршудаи рӯзонаро медиҳад. |
| `studyLine()` |  | Сатри фаъол будани ҳолати дарсиро медиҳад. |
| `nextUnlock()` |  | Нишони вақти то кушодашавиро медиҳад. |
| `tomorrowAt8()` |  | Вақти намунавии кушодашавиро медиҳад. |
| `backHome()` |  | Матни тугмаи бозгашт ба Home-ро медиҳад. |
| `askExtraTime()` |  | Матни дархости 15 дақиқаи иловагиро медиҳад. |
| `requestGoesToParent()` |  | Ба фарзанд мефаҳмонад, ки дархост ба волидайн меравад. |
| `emergencyCalls()` |  | Дастрас будани зангҳои таъҷилиро нишон медиҳад. |
| `emergencyCallsNote()` |  | Истиснои 112 ва занг ба волидайнро шарҳ медиҳад. |
| `pinTitle()` |  | Сарлавҳаи санҷиши волидайнро медиҳад. |
| `pinRequired()` |  | Зарурати PIN барои нест кардани барномаро шарҳ медиҳад. |
| `pinHint4()` |  | Hint-и PIN-и чоррақамаро медиҳад. |
| `confirm()` |  | Матни умумии тугмаи тасдиқро медиҳад. |
| `pinLocked()` |  | Хабари басташавии PIN-ро бо сонияҳои боқимонда месозад. |
| `pinNotSet()` |  | Набудани PIN-и танзимшударо хабар медиҳад. |
| `pinWrong()` |  | Хабари PIN-и нодурустро медиҳад. |
| `updateNotInstalled()` |  | Насб нашудани навсозиро хабар медиҳад. |
| `updateServerError()` |  | Хатои серверро бо HTTP code месозад. |
| `updateIncomplete()` |  | Нопурра боргирӣ шудани APK-ро хабар медиҳад. |
| `updateBroken()` |  | Вайрон будани файли навсозиро хабар медиҳад. |
| `updateWrongPackage()` |  | Ба package-и NIGOH тааллуқ надоштани APK-ро хабар медиҳад. |
| `updateAlreadyLatest()` |  | Навтар набудани версияи пешниҳодшударо хабар медиҳад. |
| `updateBadSignature()` |  | Мувофиқ набудани имзои APK-ро хабар медиҳад. |
| `updateConfirmPrompt()` |  | Аз корбар тасдиқи насбро дар равзанаи Android мепурсад. |
| `updateCancelled()` |  | Бекор шудани навсозиро хабар медиҳад. |
| `notifyFailed()` |  | Ноком шудани кори огоҳиномаҳоро хабар медиҳад. |

### `mobile/android/app/src/main/kotlin/tj/nigoh/nigoh_family_parent/AppUpdater.kt`

навсозии дохилии барнома — APK-ро боргирӣ ва санҷида,

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `object AppUpdater` |  | Навсозиро бе нест кардани барнома иҷро мекунад: APK-ро бор гирифта, package, имзо ва версияро месанҷад. Маълумот, воридшавӣ ва иҷозатҳо нигоҳ дошта мешаванд. |
| `emit()` |  | Вазъ ва пешрафти навсозиро дар main thread ба Flutter мефиристад. |
| `start()` |  | Боргирӣ, санҷиш ва насбро дар background thread оғоз мекунад. |
| `download()` |  | APK-ро бо пайгирии redirect ба cache бор гирифта, пешрафтро хабар медиҳад. |
| `signatureDigests()` |  | SHA-256-и сертификатҳои имзои [info]-ро бармегардонад. |
| `verify()` |  | APK-и барномаи дигар, имзои бегона ё версияи кӯҳнаро рад мекунад. |
| `install()` |  | APK-ро дар session ба PackageInstaller дода, насбро тасдиқ мекунад. |
| `onStatus()` |  | Натиҷаи PackageInstaller-ро коркард карда, ба Flutter мерасонад. |
| `class UpdateStatusReceiver` |  | Натиҷаи session-и PackageInstaller-ро ба [AppUpdater] месупорад. |
| `onReceive()` |  | Broadcast-и натиҷаи насбро қабул мекунад. |

### `mobile/android/app/src/main/kotlin/tj/nigoh/nigoh_family_parent/BlockedActivity.kt`

экрани пурраи басташавӣ барои барномае, ки волидайн маҳдуд кардааст.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class BlockedActivity` |  | Сабаби басташавиро нишон дода, бозгашт ба Home ё дархости вақти иловагиро пешниҳод мекунад. |
| `onCreate()` |  | Саҳифаи басташавиро барои package-и аз intent гирифташуда месозад. |
| `dp()` |  | dp-ро барои зичии экран ба pixel табдил медиҳад. |
| `rounded()` |  | Заминаи кунҷҳояш гирд ва stroke-и ихтиёрӣ месозад. |
| `text()` |  | TextView-и марказонидашударо бо услуби дархостшуда месозад. |
| `addSpace()` |  | Ба layout фосилаи амудӣ илова мекунад. |

### `mobile/android/app/src/main/kotlin/tj/nigoh/nigoh_family_parent/MainActivity.kt`

Activity-и асосии Flutter ва пули байни Dart ва Android;

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class MainActivity` |  | platform channel-ҳои Flutter-ро сабт мекунад, хидмати бастани барномаҳоро оғоз менамояд ва кушодашавии занг, SOS ва паёмро ба Dart мерасонад. |
| `onActivityResult()` |  | Ҷавоби тирезаи розигии VPN-ро мегирад ва филтрро оғоз мекунад. |
| `onReceive()` |  | Тағйири package-ро гирифта, номи онро ба package_events мерасонад. |
| `configureFlutterEngine()` |  | Channel-ҳои навсозӣ, идораи дастгоҳ, package event ва огоҳиномаро бо handler-ҳояшон сабт мекунад. |
| `onListen()` |  | Listener-и пешрафти навсозиро ба EventChannel мепайвандад. |
| `onCancel()` |  | Ҳангоми қатъи stream listener-и навсозиро хориҷ мекунад. |
| `onListen()` |  | Receiver-и package-ро сабт карда, EventSink-ро барои event-ҳо нигоҳ медорад. |
| `onCancel()` |  | Stream-и package-ро қатъ карда, receiver-ро хориҷ мекунад. |
| `unregisterPackageReceiver()` |  | Агар receiver сабт бошад, шунидани тағйири package-ҳоро қатъ мекунад. |
| `getInstalledAppsAsync()` |  | Барномаҳои launcher-ро берун аз main thread хонда, ба Dart бармегардонад. |
| `installedLauncherApps()` |  | Барномаҳои launcher-ро бо ном, package, нишони system ва icon-и 48 px ҷамъ мекунад. |
| `drawableToBase64()` |  | Icon-и барномаро ба PNG-и 48 px ва Base64 табдил медиҳад. |
| `todayUsageStats()` |  | Дақиқаҳои истифодаи имрӯзаи ҳар барномаро аз Android мегирад. |
| `jsonForRules()` |  | map ва list-и қоидаҳои Dart-ро барои blocker ба JSON табдил медиҳад. |
| `isBlockServiceEnabled()` |  | Дода шудани usage access, overlay ва Accessibility-ро якҷо месанҷад. |
| `openNextProtectionSetting()` |  | Танзими иҷозати навбатии норасоро мекушояд ё баъди пурра будан хидматро оғоз мекунад. |
| `openUsageAccessSettings()` |  | Танзими usage access-и барномаро бо fallback-и экрани умумӣ мекушояд. |
| `protectionStatus()` |  | Вазъи ҳамаи иҷозатҳо ва маълумоти дастгоҳро барои экранҳои Flutter ҷамъ мекунад. |
| `granted()` |  | Дода шудани иҷозати Android-ро месанҷад. |
| `startProtectionService()` |  | Monitor-и бастани барномаҳоро ҳамчун foreground service оғоз мекунад. |
| `onCreate()` |  | Ҳангоми сохтани Activity муҳофизатро оғоз ва intent-и огоҳиномаро сабт мекунад. |
| `onNewIntent()` |  | Intent-и нави огоҳиномаро ҳангоми кори барнома ба Flutter мерасонад. |
| `configureNotifyChannel()` |  | Channel-и tj.nigoh/notify-ро барои хидмат, иҷозат, full-screen ва занг танзим мекунад. |
| `notifyPermissionStatus()` |  | Иҷозати огоҳинома ва full-screen intent-ро месанҷад. |
| `openFullScreenSettings()` |  | Танзими full-screen intent ё экрани наздиктарини огоҳиномаро мекушояд. |
| `handleNotifyIntent()` |  | Extra-ҳои NotifyService-ро хонда, ба Dart мерасонад ё муваққатан нигоҳ медорад. |
| `onResume()` |  | Баъди бозгашт аз Settings муҳофизат ва навсозии мунтазири иҷозати насбро идома медиҳад. |
| `onDestroy()` |  | Кори background-ро қатъ ва package receiver-ро хориҷ мекунад. |
| `versionCode()` |  | version code-и насбшудаи барномаро мегирад. |
| `versionName()` |  | version name-и насбшудаи барномаро мегирад. |
| `checkForUpdate()` |  | Версияи охиринро аз сервер гирифта, бо URL-и мутлақи боргирӣ ба Dart медиҳад. |
| `startUpdate()` |  | Навсозии APK-ро оғоз карда, агар лозим бошад иҷозати unknown apps мепурсад. |
| `uninstallWithParentPin()` |  | Баъди санҷиши PIN ҳифзи device admin-ро гирифта, равзанаи uninstall-ро мекушояд. |
| `jsonObjectToMap()` |  | JSONObject-ро барои Flutter channel ба map табдил медиҳад. |
| `jsonValue()` |  | Қимати JSON-ро ба навъҳои мувофиқи platform channel табдил медиҳад. |

### `mobile/android/app/src/main/kotlin/tj/nigoh/nigoh_family_parent/NIGOHAccessibilityService.kt`

барномаи foreground-ро тавассути Accessibility зуд муайян мекунад

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class NIGOHAccessibilityService` |  | Барномаи фаъоли телефони фарзандро аз рӯйи event-ҳои Accessibility назорат мекунад. |
| `onAccessibilityEvent()` |  | Ҳангоми иваз шудани равзана қоида, ҷадвал ва лимити барномаи фаъолро месанҷад; барои барномаи мамнӯъ overlay дархост мекунад. |
| `onInterrupt()` |  | Қатъи Accessibility-ро қабул мекунад; ҳолати иловагӣ барои тоза кардан надорад. |
| `findRule()` |  | Қоидаи package-и [target]-ро аз JSON-и нигоҳдошта меёбад. |
| `isScheduleActive()` |  | Фаъол будани фосилаи ҷадвалро, аз ҷумла шабгузарро, муайян мекунад. |
| `enabledOn()` |  | Мавҷуд будани рӯзи ҳафтаи додашударо дар ҷадвал месанҷад. |
| `parseMinutes()` |  | Вақти «HH:mm»-ро ба дақиқаҳои баъди нисфи шаб табдил медиҳад. |

### `mobile/android/app/src/main/kotlin/tj/nigoh/nigoh_family_parent/NotifyService.kt`

хидмати огоҳинома бе Firebase — events API-ро бо long-poll мехонад

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class NotifyService` |  | Foreground service-и огоҳиномаҳост: GET /api/mobile/v3/events-ро long-poll карда, event-ҳоро ба паём, SOS, занг ва огоҳии оилавии Android табдил медиҳад. |
| `hasToken()` |  | Аз рӯйи token-и Flutter ворид будани корбарро месанҷад. |
| `start()` |  | Хидматро оғоз ё нав мекунад; [baseUrl]-и null қимати пешинаро нигоҳ медорад. |
| `startIfSignedIn()` |  | Ҳангоми boot ё кушодани барнома танҳо барои корбари воридшуда хидматро оғоз мекунад. |
| `stop()` |  | Хидмат ва садоро қатъ карда, cursor-и event-ҳоро пок мекунад. |
| `createChannels()` |  | Channel-ҳои огоҳиномаро месозад ё номи онҳоро ба забони ҷорӣ мегардонад. |
| `onBind()` |  | Нишон медиҳад, ки хидмат binding-ро дастгирӣ намекунад. |
| `onCreate()` |  | Instance-ро сабт карда, channel-ҳо ва listener-и забонро омода мекунад. |
| `refreshLanguage()` |  | Баъди иваз шудани забон channel ва корти ongoing-ро нав мекунад. |
| `onStartCommand()` |  | Action-ҳои оғоз, хомӯш кардани alarm ва зангро коркард карда, polling thread-ро оғоз мекунад. |
| `onDestroy()` |  | Ҳангоми нест шудани хидмат polling, listener ва садоро қатъ мекунад. |
| `prefs()` |  | Танзимоти хусусии service-ро барои base URL ва cursor медиҳад. |
| `flutterPrefs()` |  | shared preferences-и Flutter-ро барои token, role ва забон медиҳад. |
| `goForeground()` |  | Огоҳиномаи хомӯши ongoing-и фаъол будани NIGOH Family-ро нишон медиҳад. |
| `class HttpStatus` |  | HTTP status-и ғайри 2xx-ро ҳамчун хато нигоҳ медорад. |
| `request()` |  | Дархости authenticated ба сервер фиристода, ҷавоби JSON-ро мехонад. |
| `loop()` |  | Event-ҳои баъди cursor-ро бо long-poll мегирад; ҳангоми хато backoff мекунад ва баъди sign-out ё 401 қатъ мешавад. |
| `sleep()` |  | [ms] интизор мешавад; ҳангоми interrupt ё қатъи хидмат false медиҳад. |
| `stopForegroundCompat()` |  | Огоҳиномаи foreground-ро дар ҳамаи версияҳои Android хориҷ мекунад. |
| `sosId()` |  | ID-и огоҳиномаи SOS-и фарзандро месозад. |
| `callNotifId()` |  | ID-и огоҳиномаи занги воридшавандаро месозад. |
| `messageId()` |  | ID-и огоҳиномаи паёмҳои фарзандро месозад. |
| `launchIntent()` |  | PendingIntent месозад, ки барномаро бо extra-ҳои Dart мекушояд. |
| `serviceIntent()` |  | PendingIntent месозад, ки action-и хомӯш ё радро ба service мефиристад. |
| `post()` |  | Огоҳиномаро мефиристад; набудани POST_NOTIFICATIONS-ро бехатар коркард мекунад. |
| `handleEvent()` |  | Як event-и серверро ба огоҳиномаи мувофиқ табдил медиҳад. |
| `str()` |  | Қимати String-и холинабудаи [key]-ро ё null медиҳад. |
| `localize()` |  | Сарлавҳа ва матни event-и оилавиро аз маълумоти сохторӣ маҳаллӣ мекунад; барои маълумоти нопурраи сервери кӯҳна null медиҳад. |
| `showMessage()` |  | Огоҳиномаи паёмро сохта, аз рӯйи фарзанд гурӯҳбандӣ мекунад. |
| `showFamily()` |  | Огоҳии оилавиро барои вақт, батарея, offline ё барномаи нав нишон медиҳад. |
| `showSos()` |  | SOS-и full-screen-ро нишон дода, то хомӯш кардан alarm менавозад. |
| `showCall()` |  | Занги воридшавандаро бо қабул, рад, ringtone ва timeout нишон медиҳад. |
| `bringToFront()` |  | Ҳангоми истифодаи телефон ва иҷозати overlay экрани занг ё SOS-ро мустақим мекушояд; дар экрани қулф full-screen intent ин корро мекунад. [key] такрорро пешгирӣ менамояд. |
| `watchCall()` |  | Вазъи зангро назорат карда, баъди қабул ё рад садоро қатъ мекунад. |
| `endCallUi()` |  | Садоро қатъ ва огоҳиномаи зангро хориҷ мекунад. |
| `declineCall()` |  | Зангро дар сервер рад карда, огоҳиномаи онро хориҷ мекунад. |
| `startRinging()` |  | Alarm-и SOS ё ringtone-и зангро бо vibration менавозад ва CPU-ро бедор нигоҳ медорад. |
| `stopRinging()` |  | Alarm, ringtone ва vibration-ро аз ҳар thread бехатар қатъ мекунад. |
| `stopAlarm()` |  | Садои SOS-ро хомӯш карда, корти огоҳиномаро нигоҳ медорад. |
| `stopCallRinging()` |  | Ҳангоми кушодани UI-и занг садо ва корти зангро қатъ мекунад. |

### `mobile/android/app/src/main/kotlin/tj/nigoh/nigoh_family_parent/NotifyStrings.kt`

матнҳои маҳаллигардонидашудаи огоҳиномаҳое, ки NotifyService месозад.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class NotifyStrings` |  | Матни огоҳиномаҳоро аз маълумоти event бо забони интихобшудаи [AppLang] месозад. Матни худи корбар, SOS ва сабабҳо тарҷума намешаванд. |
| `t()` |  | Матни мувофиқро барои забони интихобшуда бармегардонад. |
| `sosTitle()` |  | Сарлавҳаи SOS-ро бо номи фарзанд месозад. |
| `sosDefault()` |  | Матни пешфарзи SOS-ро барои фарзанди маълум ё номаълум месозад. |
| `timeRequestTitle()` |  | Сарлавҳаи дархости вақти иловагиро бо барнома ва дақиқаҳо месозад. |
| `approvedBody()` |  | Матни иҷозати вақти иловагиро месозад. |
| `lowBatteryTitle()` |  | Сарлавҳаи огоҳии батареяи пастро бо фоиз месозад. |
| `offlineTitle()` |  | Сарлавҳаи қатъ шудани пайвасти фарзандро месозад. |
| `webFilterOffTitle()` |  | Сарлавҳаи огоҳӣ, вақте филтри сайтҳо дар телефони фарзанд хомӯш шуд. |
| `placeArriveTitle()` |  | Сарлавҳаи огоҳӣ, вақте фарзанд ба ҷойи бехатар расид. |
| `placeLeaveTitle()` |  | Сарлавҳаи огоҳӣ, вақте фарзанд аз ҷойи бехатар баромад. |
| `newAppTitle()` |  | Сарлавҳаи насби барномаи навро месозад. |

### `mobile/android/app/src/main/kotlin/tj/nigoh/nigoh_family_parent/PinSecurity.kt`

нигоҳдорӣ ва санҷиши PIN-и волидайн бо SHA-256 ва Android Keystore;

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `object PinSecurity` |  | PIN-и волидайнро бехатар нигоҳ медорад ва кӯшишҳои воридшавиро назорат мекунад. |
| `class Result` |  | Натиҷаи санҷиши PIN: иҷозат, сабаби рад ва сонияҳои боқимондаи басташавӣ. |
| `hasPin()` |  | Мавҷуд будани PIN-и волидайнро дар формати ҷорӣ ё кӯҳна месанҷад. |
| `savePin()` |  | PIN-и нави чоррақамаро санҷида, рамзгузорӣ ва нигоҳ медорад; сабти кӯҳна ва ҳисобкунаки хаторо пок мекунад. |
| `verify()` |  | [pin]-ро бо сабти нигоҳдошта муқоиса карда, хатогиҳо ва муҳлати бастаро ҳисоб мекунад. |
| `recordFailure()` |  | Хаторо сабт карда, пас аз кӯшиши сеюм PIN-ро 30 сония мебандад. |
| `hashPin()` |  | Хэши PIN-ро бо salt ва SHA-256 сохта, ба Base64 мегузаронад. |
| `constantTimeEquals()` |  | Ду хэшро бо вақти доимӣ, бе ифшои timing, муқоиса мекунад. |
| `key()` |  | Калиди AES-GCM-ро аз Android Keystore мехонад ё месозад. |
| `encrypt()` |  | [value]-ро бо калиди Keystore рамзгузорӣ карда, Base64(iv + ciphertext) медиҳад. |
| `decrypt()` |  | Қимати сохтаи [encrypt]-ро мекушояд; ҳангоми хато null медиҳад. |

### `mobile/android/app/src/main/kotlin/tj/nigoh/nigoh_family_parent/PinVerificationActivity.kt`

экрани санҷиши PIN-и волидайн барои ҳифзи NIGOH аз несткунӣ;

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class PinVerificationActivity` |  | Ҳангоми кӯшиши хомӯш ё нест кардани NIGOH PIN мепурсад; тугмаи Back онро намепӯшад. |
| `onCreate()` |  | Формаи PIN, сатри хато ва тугмаи тасдиқро месозад. |
| `dp()` |  | dp-ро барои зичии экран ба pixel табдил медиҳад. |
| `verify()` |  | PIN-ро месанҷад; ҳангоми муваффақият device admin-ро гирифта, uninstall-ро оғоз мекунад. |
| `launchUninstall()` |  | Равзанаи uninstall-и Android-ро мекушояд ва ин экранро мебандад. |
| `onBackPressed()` |  | Барои пешгирии гузаштан аз муҳофизат амали Back-ро нодида мегирад. |

### `mobile/android/app/src/main/kotlin/tj/nigoh/nigoh_family_parent/ProtectionBootReceiver.kt`

баъди бозоғозии телефон хидмати огоҳинома ва назорати барномаҳоро барқарор мекунад.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class ProtectionBootReceiver` |  | Хидматҳои background-и NIGOH-ро баъди boot, бо дарназардошти иҷозатҳо, оғоз мекунад. |
| `onReceive()` |  | Пас аз boot огоҳиномаҳоро барқарор ва ҳангоми мавҷуд будани иҷозатҳо blocker-ро оғоз мекунад. |

### `mobile/android/app/src/main/kotlin/tj/nigoh/nigoh_family_parent/TamperDeviceAdminReceiver.kt`

NIGOH-ро аз хомӯш ё нест кардан бе PIN-и волидайн муҳофизат мекунад.

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class TamperDeviceAdminReceiver` |  | Ҳангоми кӯшиши бекор кардани ҳуқуқи device admin экрани PIN-ро мекушояд. |
| `onDisableRequested()` |  | Хомӯш кардани device admin-ро боздошта, санҷиши PIN-и волидайнро мекушояд. |

### `mobile/android/app/src/main/kotlin/tj/nigoh/nigoh_family_parent/WebFilterDns.kt`

мантиқи тозаи филтри сайтҳо — хондани пакетҳои DNS, санҷиши доменҳои манъшуда

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `object WebFilterDns` |  | Сатҳҳои филтр, серверҳои DNS-и филтрдор ва амалиёт бо пакетҳои IPv4/UDP/DNS. Филтр DNS-ро иваз мекунад: телефон номи сайтро аз сервери CleanBrowsing мепурсад, ки сайтҳои калонсолонро намекушояд ва дар Google, Bing ва YouTube ҷустуҷӯи бехатарро ҳатмӣ мекунад. Сайтҳое, ки волидайн дастӣ бастанд, дар худи телефон ҷавоби «нест» мегиранд. |
| `upstreams()` |  | Серверҳои CleanBrowsing барои ҳар сатҳ (асосӣ, эҳтиётӣ). kids — Family Filter: калонсолон, прокси/VPN, сайтҳои омехта; SafeSearch ва YouTube-и маҳдуд. teen — Adult Filter: сайтҳои калонсолон; SafeSearch дар Google ва Bing. |
| `class Query` |  | Ҳамаи қисмҳои як пакети DNS, ки аз телефон омад. |
| `isBlocked()` |  | Ном мувофиқи рӯйхат баста аст: худи домен ё ягон зердомени он (m.youtube.com → youtube.com). |
| `effectiveBlocklist()` |  | Рӯйхати пурраи манъшуда: сайтҳои волидайн ва серверҳои DoH (вақте филтр фаъол аст). |
| `parseQuery()` |  | Агар пакет дархости DNS-и IPv4/UDP ба DNS_ADDRESS:53 бошад, онро ҷудо мекунад; вагарна null. |
| `questionName()` |  | Номи аввалин саволро аз паёми DNS мехонад (масалан «www.youtube.com»); хато бошад, null. |
| `questionEnd()` |  | Дарозии қисми «савол» (ном + навъ + синф), то ҷавоби NXDOMAIN-ро аз он созем. |
| `nxDomain()` |  | Ҷавоби «чунин сайт нест» (NXDOMAIN) барои дархост месозад; хато бошад, null. |
| `wrapResponse()` |  | Ҷавоби DNS-ро ба пакети IPv4/UDP мепечонад: аз DNS_ADDRESS:53 ба телефон. Агар ҷавоб аз MTU калон бошад, бурида ва бо байрақи TC қайд мешавад. |
| `ipChecksum()` |  | Checksum-и сарлавҳаи IPv4 (RFC 791). |
| `ipBytes()` |  | «10.215.173.2» → 4 байт. |

### `mobile/android/app/src/main/kotlin/tj/nigoh/nigoh_family_parent/WebFilterVpnService.kt`

филтри сайтҳо дар телефони фарзанд — VpnService-и маҳаллӣ, ки танҳо дархостҳои DNS-ро

| Функсия / синф | Роут | Чӣ кор мекунад |
|---|---|---|
| `class WebFilterVpnService` |  | VPN-и «танҳо DNS»: ба система суроғаи DNS-и дохилӣ (10.215.173.2) медиҳад ва танҳо роҳи ҳамин суроғаро ба VPN мегузаронад. Ҳар дархост ё дар ҷо «нест» мегирад (сайти манъшуда), ё ба CleanBrowsing фиристода мешавад. Ҷавоб ба барномаи пурсанда бармегардад. |
| `configure()` |  | Сатҳ ва рӯйхатро нигоҳ медорад ва филтрро оғоз/қатъ мекунад. Ҳолати навро бармегардонад. |
| `state()` |  | Ҳолати ҳозира барои хабар ба волидайн: active, off ё needs_permission. |
| `startIfEnabled()` |  | Пас аз boot ё вақте хидмати дигар мебинад, ки филтр бояд кор кунад, вале қатъ шудааст. |
| `onStartCommand()` |  | Фармони оғоз ё қатъро иҷро мекунад; танзими навро бе бозоғозии VPN мегирад. |
| `establish()` |  | Интерфейси VPN-ро месозад: як суроға, як DNS ва танҳо як роҳ — ба ҳамон DNS. |
| `readLoop()` |  | Пакетҳоро аз VPN мехонад ва ҳар дархости DNS-ро дар pool коркард мекунад. |
| `answer()` |  | Ба як дархост ҷавоб медиҳад: «нест» барои сайти манъшуда ё ҷавоби сервери филтр. |
| `forward()` |  | Дархостро ба сервери филтр мефиристад; агар сервери асосӣ ҷавоб надиҳад, ба эҳтиётӣ. |
| `shutdown()` |  | VPN-ро мебандад ва thread-ҳоро қатъ мекунад. |
| `onRevoke()` |  | Вақте корбар дар танзимот VPN-ро қатъ мекунад ё VPN-и дигар фаъол мешавад. |

