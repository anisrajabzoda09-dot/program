# NIGOH Family

Системаи назорати волидайн барои Android: барномаи мобилӣ (Flutter + Kotlin) ва сервери худӣ (FastAPI). Бе Firebase — ҳамаи маълумот дар сервери NIGOH нигоҳ дошта мешавад.

- Сайт: https://nigohfamily.qobus.tj
- Боргирии Android: https://nigohfamily.qobus.tj/get (рамзи QR ҳамеша версияи охиринро медиҳад)
- Боргирии Windows (барои волидайн): https://nigohfamily.qobus.tj/download/windows — GitHub Actions (`.github/workflows/windows.yml`) насбкунандаро ҳангоми ҳар тағйири `mobile/` месозад
- Ҳолати сервер: https://nigohfamily.qobus.tj/health

## Сохтор

| Папка | Чӣ дорад |
|---|---|
| `app/` | Сервер: FastAPI, SQLAlchemy, SQLite (`app/nigoh.db`), саҳифаҳои сайт ва панели админ |
| `app/routers/mobile*.py` | API-и барномаи мобилӣ: воридшавӣ, оила, огоҳиномаҳо, занг |
| `mobile/` | Барномаи Android (Flutter). Нигаред: [mobile/README.md](mobile/README.md) |
| `scripts/` | Deploy ва скриптҳои ёрирасон |
| `deploy/` | Танзимоти nginx ва HTTPS |
| `docs/` | Ҳуҷҷатҳои API |

## Имкониятҳо

**Волидайн:** рӯйхати барномаҳои фарзанд бо вақти истифода; бастан, лимити рӯзона, «Вақти дарс», «Ҳолати танаффус», «Вақти хоб», «Тамаркузи дарс», «Ҳамеша иҷозат», бонуси вақт, бастан аз рӯи категория; харита бо таърихи 24 соат ва ҷойҳои бехатар; ҳисоботи ҳафтаина; дархостҳои вақти иловагӣ; огоҳиномаҳо (SOS бо занги хатар, батареяи кам, офлайн, барномаи нав).

**Фарзанд:** «Қоидаҳои ман», дархости вақт, тугмаи SOS, паёмҳои зуд, вақти экрани худ.

**Ҳарду:** чат бо «Хонда шуд», занги овозӣ (WebRTC), навсозӣ бо як тугма.

**Амният:** PIN-и волидайн ва ҳимоя аз нест кардан (Device Admin); токенҳои сессия дар база танҳо ҳамчун SHA-256; HTTPS; навсозӣ танҳо бо ҳамон калиди имзо насб мешавад.

## Оғози маҳаллӣ

```bash
python3 -m venv venv && venv/bin/pip install -r requirements.txt
cp .env.example .env   # арзишҳоро пур кунед
venv/bin/python run.py # http://localhost:8080
```

Санҷиши API-и мобилӣ (аз аввал то охир, бо базаи маҳаллӣ):

```bash
venv/bin/python test_mobile_v3.py
```

## Deploy

```bash
read -s -p "Рамзи сервер: " NIGOH_DEPLOY_PASSWORD && export NIGOH_DEPLOY_PASSWORD
venv/bin/python scripts/deploy_production.py
```

Скрипт APK-ро аз `mobile/` месозад, имзоро месанҷад, `app/`-ро ба сервер мефиристад (бе `nigoh.db`) ва серверро аз нав оғоз мекунад. APK-ҳо дар `app/static/downloads` нигоҳ дошта мешаванд ва ба git намераванд (маҳдудияти 100 МБ-и GitHub).

Пас аз нашри версияи нав `APP_VERSION` ва `APP_VERSION_CODE`-ро дар `app/core/config.py` нав кунед — барнома ба корбарон навсозиро худаш пешниҳод мекунад.
