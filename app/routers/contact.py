"""Файл: саҳифаи «Тамос бо мо» — форма бо се забон, ҳифз аз спам ва нигоҳдории паём."""

import re
import time
from collections import defaultdict, deque
from typing import Deque, Dict

from fastapi import APIRouter, Depends, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.contact import ContactMessage
from app.routers.public import SITE_LANGS, _site_page

router = APIRouter(tags=["Contact"])

CONTACT_TOPICS = ("question", "problem", "privacy", "delete_account", "other")
MESSAGE_MIN, MESSAGE_MAX = 10, 2000
NAME_MAX, EMAIL_MAX = 80, 120
# Аз як IP дар як соат ҳамин қадар паём қабул мешавад.
RATE_LIMIT, RATE_WINDOW = 5, 3600

_EMAIL_RE = re.compile(r"^[^@\s]{1,64}@[^@\s]+\.[^@\s]{2,}$")
_recent: Dict[str, Deque[float]] = defaultdict(deque)

# Матни хатоҳо бо се забон; калид дар шаблон ҳам истифода мешавад.
ERRORS = {
    "tg": {
        "name": "Номи худро нависед.",
        "email": "Почтаи дурустро нависед, то ба шумо ҷавоб диҳем.",
        "message": f"Паём бояд аз {MESSAGE_MIN} то {MESSAGE_MAX} ҳарф бошад.",
        "rate": "Шумо имрӯз паёмҳои зиёд фиристодед. Лутфан баъдтар кӯшиш кунед.",
    },
    "ru": {
        "name": "Укажите ваше имя.",
        "email": "Укажите правильный email, чтобы мы могли ответить.",
        "message": f"Сообщение должно быть от {MESSAGE_MIN} до {MESSAGE_MAX} символов.",
        "rate": "Вы отправили слишком много сообщений. Попробуйте позже.",
    },
    "en": {
        "name": "Please enter your name.",
        "email": "Please enter a valid email so we can reply.",
        "message": f"The message must be {MESSAGE_MIN}–{MESSAGE_MAX} characters.",
        "rate": "You have sent too many messages. Please try again later.",
    },
}


def _client_ip(request: Request) -> str:
    """IP-и корбарро бо назардошти nginx (X-Forwarded-For) муайян мекунад."""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _rate_limited(ip: str, now: float | None = None) -> bool:
    """Агар аз ин IP дар як соат аллакай RATE_LIMIT паём омада бошад, True бармегардонад."""
    now = time.time() if now is None else now
    bucket = _recent[ip]
    while bucket and now - bucket[0] > RATE_WINDOW:
        bucket.popleft()
    return len(bucket) >= RATE_LIMIT


def validate_contact(name: str, email: str, topic: str, message: str) -> list[str]:
    """Майдонҳои формаро месанҷад ва рӯйхати калидҳои хатоҳоро бармегардонад."""
    errors = []
    if not name.strip() or len(name.strip()) > NAME_MAX:
        errors.append("name")
    if len(email.strip()) > EMAIL_MAX or not _EMAIL_RE.match(email.strip()):
        errors.append("email")
    if not MESSAGE_MIN <= len(message.strip()) <= MESSAGE_MAX:
        errors.append("message")
    return errors


def _prefix(lang: str) -> str:
    """Пешванди URL-и забонро бармегардонад ("" барои тоҷикӣ)."""
    return "" if lang == "tg" else f"/{lang}"


def _register(lang: str) -> None:
    """Роутҳои GET ва POST-и саҳифаи тамосро барои як забон сабт мекунад."""
    path = f"{_prefix(lang)}/contact"

    def show(request: Request):
        """Формаи тамосро нишон медиҳад; пас аз фиристодан паёми муваффақиятро."""
        sent = request.query_params.get("sent") == "1"
        return _site_page(request, "contact", "contact", lang=lang, sent=sent, errors=[],
                          form={}, topics=CONTACT_TOPICS, error_text=ERRORS[lang])

    def submit(
        request: Request,
        db: Session = Depends(get_db),
        name: str = Form(""),
        email: str = Form(""),
        topic: str = Form("question"),
        message: str = Form(""),
        website: str = Form(""),
    ):
        """Паёми формаро месанҷад, нигоҳ медорад ва ба саҳифаи «фиристода шуд» мебарад."""
        # Майдони пинҳон: одам онро намебинад, ботҳо пур мекунанд. Ҷавоби «муваффақ»
        # медиҳем, то бот нафаҳмад, ки паём қабул нашуд.
        if website.strip():
            return RedirectResponse(f"{path}?sent=1#form", status_code=303)
        ip = _client_ip(request)
        errors = validate_contact(name, email, topic, message)
        if not errors and _rate_limited(ip):
            errors = ["rate"]
        if errors:
            form = {"name": name[:NAME_MAX], "email": email[:EMAIL_MAX], "topic": topic,
                    "message": message[:MESSAGE_MAX]}
            response = _site_page(request, "contact", "contact", lang=lang, sent=False, errors=errors,
                                  form=form, topics=CONTACT_TOPICS, error_text=ERRORS[lang])
            response.status_code = 429 if errors == ["rate"] else 400
            return response
        db.add(ContactMessage(
            name=name.strip()[:NAME_MAX],
            email=email.strip()[:EMAIL_MAX],
            topic=topic if topic in CONTACT_TOPICS else "other",
            message=message.strip()[:MESSAGE_MAX],
            lang=lang,
            ip=ip[:64],
        ))
        db.commit()
        _recent[ip].append(time.time())
        return RedirectResponse(f"{path}?sent=1#form", status_code=303)

    router.add_api_route(path, show, methods=["GET", "HEAD"], response_class=HTMLResponse, include_in_schema=False)
    router.add_api_route(path, submit, methods=["POST"], response_class=HTMLResponse, include_in_schema=False)


for _lang in SITE_LANGS:
    _register(_lang)
