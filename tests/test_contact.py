"""Файл: санҷиши формаи «Тамос бо мо» — се забон, санҷиши майдонҳо, спам ва панели админ."""

# Run from anywhere: make the project root importable and the working directory.
import os as _os, sys as _sys
_ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
_sys.path.insert(0, _ROOT)
_os.chdir(_ROOT)

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401
import app.routers.contact as contact
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models.contact import ContactMessage

PASSED = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    """Як шартро месанҷад; хато бошад, санҷиш қатъ мешавад."""
    global PASSED
    if not ok:
        raise AssertionError(f"FAIL {name} {detail}")
    PASSED += 1
    print(f"ok  {name}")


engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
Base.metadata.create_all(engine)
Session = sessionmaker(bind=engine)


def override_db():
    """Базаи санҷишӣ дар хотираро ба ҷои базаи воқеӣ медиҳад."""
    db = Session()
    try:
        yield db
    finally:
        db.close()


GOOD = {"name": "Мунис", "email": "parent@example.com", "topic": "problem",
        "message": "Барнома дар Redmi Note 12 харитаро нишон намедиҳад.", "website": ""}


def run_checks() -> None:
    """Ҳамаи сенарияҳои формаи тамосро иҷро мекунад."""
    app.dependency_overrides[get_db] = override_db
    client = TestClient(app)
    db = Session()
    try:
        # 1. Саҳифа бо се забон.
        for path, label in (("/contact", "Тамос бо мо"), ("/ru/contact", "Связаться с нами"), ("/en/contact", "Contact us")):
            r = client.get(path)
            check(f"GET {path} -> 200", r.status_code == 200, str(r.status_code))
            check(f"{path} has heading", label in r.text)
            check(f"{path} has form posting to itself", f'action="{path}"' in r.text)
            check(f"{path} has honeypot", 'name="website"' in r.text)
            check(f"{path} no unrendered template", "{{" not in r.text and "{%" not in r.text)
            check(f"HEAD {path} -> 200", client.head(path).status_code == 200)

        # 2. Паёми дуруст нигоҳ дошта мешавад ва PRG ба ?sent=1.
        r = client.post("/contact", data=GOOD, follow_redirects=False,
                        headers={"X-Forwarded-For": "10.0.0.1"})
        check("valid post redirects 303", r.status_code == 303, str(r.status_code))
        check("redirect to sent page", r.headers["location"] == "/contact?sent=1#form", r.headers.get("location"))
        row = db.query(ContactMessage).one()
        check("message stored", row.message == GOOD["message"] and row.email == GOOD["email"])
        check("topic stored", row.topic == "problem")
        check("lang stored", row.lang == "tg")
        check("ip stored from proxy header", row.ip == "10.0.0.1")
        check("stored unread", row.is_read == 0)
        r = client.get("/contact?sent=1")
        check("sent page shows thanks", "Паём фиристода шуд" in r.text and 'name="message"' not in r.text)

        # 3. Хатоҳо: майдонҳо ва забонҳо.
        bad = dict(GOOD, email="not-an-email", message="кӯтоҳ")
        r = client.post("/ru/contact", data=bad, headers={"X-Forwarded-For": "10.0.0.2"})
        check("invalid post -> 400", r.status_code == 400, str(r.status_code))
        check("russian email error", "Укажите правильный email" in r.text)
        check("russian message error", "Сообщение должно быть" in r.text)
        check("fields kept after error", 'value="Мунис"' in r.text)
        check("invalid fields marked", r.text.count('aria-invalid="true"') == 2, str(r.text.count('aria-invalid="true"')))
        r = client.post("/en/contact", data=dict(GOOD, name="  "), headers={"X-Forwarded-For": "10.0.0.2"})
        check("english name error", r.status_code == 400 and "Please enter your name." in r.text)
        check("invalid posts not stored", db.query(ContactMessage).count() == 1)
        r = client.post("/contact", data=dict(GOOD, message="x" * 2001), headers={"X-Forwarded-For": "10.0.0.2"})
        check("too long message rejected", r.status_code == 400)
        r = client.post("/contact", data=dict(GOOD, topic="hack"), follow_redirects=False,
                        headers={"X-Forwarded-For": "10.0.0.3"})
        check("unknown topic stored as other", r.status_code == 303 and
              db.query(ContactMessage).order_by(ContactMessage.id.desc()).first().topic == "other")

        # 4. Спам: майдони пинҳон.
        before = db.query(ContactMessage).count()
        r = client.post("/en/contact", data=dict(GOOD, website="http://spam.example"), follow_redirects=False,
                        headers={"X-Forwarded-For": "10.0.0.4"})
        check("honeypot looks successful", r.status_code == 303 and r.headers["location"] == "/en/contact?sent=1#form")
        check("honeypot not stored", db.query(ContactMessage).count() == before)

        # 5. Маҳдудияти суръат: 5 паём дар як соат аз як IP.
        contact._recent.clear()
        codes = [client.post("/contact", data=GOOD, follow_redirects=False,
                             headers={"X-Forwarded-For": "10.9.9.9"}).status_code for _ in range(6)]
        check("first five accepted", codes[:5] == [303] * 5, str(codes))
        check("sixth rate limited 429", codes[5] == 429, str(codes))
        check("other IP still allowed", client.post("/contact", data=GOOD, follow_redirects=False,
              headers={"X-Forwarded-For": "10.9.9.10"}).status_code == 303)
        check("rate window expires", contact._rate_limited("10.9.9.9", now=contact._recent["10.9.9.9"][-1] + 3601) is False)

        # 6. Валидатсия алоҳида.
        check("validate ok", contact.validate_contact("A", "a@b.tj", "question", "салом дӯстон!") == [])
        check("validate email without dot", "email" in contact.validate_contact("A", "a@b", "question", "салом дӯстон!"))
        check("validate long name", "name" in contact.validate_contact("A" * 81, "a@b.tj", "question", "салом дӯстон!"))

        # 7. Панели админ паёмҳоро нишон медиҳад ва хондашуда қайд мекунад.
        import app.routers.admin as admin_router
        original = admin_router.get_current_user
        admin_router.get_current_user = lambda request: {"role": "admin", "email": "admin"}
        try:
            unread_before = db.query(ContactMessage).filter(ContactMessage.is_read == 0).count()
            r = client.get("/admin")
            check("admin page 200", r.status_code == 200, str(r.status_code))
            check("admin lists messages", 'id="messages"' in r.text and GOOD["message"] in r.text)
            check("admin shows unread count", f"нахонда {unread_before}" in r.text)
            db.expire_all()
            check("messages marked read", db.query(ContactMessage).filter(ContactMessage.is_read == 0).count() == 0)
            r = client.get("/admin")
            check("second visit shows zero unread", "нахонда 0" in r.text)
        finally:
            admin_router.get_current_user = original
    finally:
        db.close()
        app.dependency_overrides.clear()
    print(f"\nALL {PASSED} CHECKS PASSED")


if __name__ == "__main__":
    run_checks()
