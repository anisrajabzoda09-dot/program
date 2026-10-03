# Sign in with Apple — танзим

Код дар сайт ва сервер тайёр аст. Тугмаи **«Идома бо Apple»** худ ба худ пайдо мешавад, вақте ки 4 арзиши поён дар сервер гузошта шаванд. То он вақт тугма пинҳон аст ва ҳеҷ чиз вайрон намешавад.

## Чӣ лозим аст
- Ҳисоби **Apple Developer Program** (пулакӣ, 99 доллар дар як сол). Бе он Apple калид намедиҳад.

## Қадамҳо дар developer.apple.com → Certificates, Identifiers & Profiles
1. **Identifiers → «+» → App IDs → App**
   - Bundle ID, масалан: `tj.nigoh.nigohfamily`
   - Дар Capabilities **Sign In with Apple**-ро фаъол кунед → Save.
2. **Identifiers → «+» → Services IDs**
   - Identifier, масалан: `tj.nigoh.nigohfamily.web` — ин **APPLE_CLIENT_ID** аст.
   - Онро кушоед, **Sign In with Apple** → **Configure**:
     - Primary App ID: ҳамон App ID-и қадами 1
     - Domains: `nigohfamily.qobus.tj`
     - Return URLs (ҳардуро илова кунед):
       - `https://nigohfamily.qobus.tj/auth/apple/callback` (сайт)
       - `https://nigohfamily.qobus.tj/auth/apple/android` (барномаи Android)
   - Save.
3. **Keys → «+»**
   - Ном диҳед, **Sign In with Apple**-ро интихоб кунед → Configure → ҳамон App ID → Save → Register.
   - Файли **`AuthKey_XXXXXXXXXX.p8`**-ро боргирӣ кунед. ⚠️ Apple онро **танҳо як бор** медиҳад — нигоҳ доред.
   - **Key ID** (10 аломат) — ин **APPLE_KEY_ID** аст.
4. **Team ID** — дар кунҷи рости боло ё дар Membership (10 аломат) — ин **APPLE_TEAM_ID** аст.

## Дар сервер
Файли `.p8`-ро ба сервер бор кунед (масалан `/home/dev/munis/apple_key.p8`, `chmod 600`) ва ба `~/munis/.env` илова кунед:

```
APPLE_CLIENT_ID=tj.nigoh.nigohfamily.web
APPLE_TEAM_ID=XXXXXXXXXX
APPLE_KEY_ID=XXXXXXXXXX
APPLE_PRIVATE_KEY_PATH=/home/dev/munis/apple_key.p8
```

Баъд серверро аз нав оғоз кунед. Тугма дар `/auth` (3 забон) пайдо мешавад ва барнома онро тавассути `/api/mobile/v3/auth/apple/config` мебинад.

Ин 4 арзишро ба ман фиристед (ё худи файлро ба папкаи лоиҳа гузоред) — ман худам ба сервер мегузорам ва месанҷам.

## Донистан хуб аст
- Корбар метавонад **«Почтаи маро пинҳон кун»**-ро интихоб кунад. Он гоҳ Apple суроғаи `...@privaterelay.appleid.com` медиҳад; ҳисоб аз рӯи ID-и доимии Apple пайваст мешавад, на аз рӯи почта.
- Apple номи корбарро **танҳо бори аввал** мефиристад; сервер онро ҳамон вақт нигоҳ медорад.
- Агар Apple дар саҳифаи Services ID тасдиқи доменро талаб кунад, файли тасдиқро ба ман диҳед — ман онро ба `/.well-known/` мегузорам.
