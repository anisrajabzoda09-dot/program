"""Translations of API error messages for the mobile app.

The app sends `X-NIGOH-Lang: tg | ru | en`. Messages in the code are Tajik;
for ru/en the `detail` of an error response is translated here. Unknown
messages fall back to Tajik.
"""

from typing import Optional

LANGS = ("tg", "ru", "en")

# Tajik source → (Russian, English)
_MESSAGES = {
    "Ба ин дархост аллакай ҷавоб дода шудааст": ("На этот запрос уже ответили", "This request has already been answered"),
    "Барнома ёфт нашуд": ("Приложение не найдено", "App not found"),
    "Барнома ҳоло аз телефони фарзанд синхрон нашудааст": ("Приложение ещё не синхронизировано с телефона ребёнка", "This app has not been synced from the child's phone yet"),
    "Воридшавӣ бо Google тасдиқ нашуд": ("Вход через Google не подтверждён", "Google sign-in could not be verified"),
    "Дархост аллакай фиристода шудааст. Ҷавоби волидайнро интизор шавед": ("Запрос уже отправлен. Дождитесь ответа родителей", "Request already sent. Please wait for your parent's answer"),
    "Дархост ёфт нашуд": ("Запрос не найден", "Request not found"),
    "Занг ёфт нашуд": ("Звонок не найден", "Call not found"),
    "Занг тамом шудааст": ("Звонок завершён", "The call has ended"),
    "Ин барнома барои Google тасдиқ нашудааст": ("Это приложение не подтверждено для Google", "This app is not approved for Google sign-in"),
    "Ин дастгоҳ ба оилаи дигар пайваст аст": ("Это устройство подключено к другой семье", "This device is linked to another family"),
    "Ин занг дигар фаъол нест": ("Этот звонок уже не активен", "This call is no longer active"),
    "Ин почта аллакай сабт шудааст. Ворид шавед": ("Этот email уже зарегистрирован. Войдите", "This email is already registered. Please sign in"),
    "Коди пайвастшавиро танҳо телефони фарзанд месозад": ("Код подключения создаёт только телефон ребёнка", "Only the child's phone can create a pairing code"),
    "Коди фарзанд ёфт нашуд": ("Код ребёнка не найден", "Child code not found"),
    "Лутфан аз нав ворид шавед": ("Пожалуйста, войдите снова", "Please sign in again"),
    "Почта ё рамз нодуруст аст": ("Неверный email или пароль", "Wrong email or password"),
    "Почтаи электронӣ нодуруст аст": ("Неверный email", "Invalid email"),
    "Почтаи Google тасдиқ нашудааст": ("Почта Google не подтверждена", "Google email is not verified"),
    "Профили оила ёфт нашуд": ("Профиль семьи не найден", "Family profile not found"),
    "Сессия ба охир расид. Аз нав ворид шавед": ("Сессия истекла. Войдите снова", "Session expired. Please sign in again"),
    "Сурат вайрон аст": ("Изображение повреждено", "The image is damaged"),
    "Танҳо волидайн ин амалро карда метавонад": ("Это действие доступно только родителям", "Only a parent can do this"),
    "Танҳо волидайн қоида гузошта метавонад": ("Правила может задавать только родитель", "Only a parent can set rules"),
    "Танҳо волидайн метавонад дастгоҳ пайваст кунад": ("Подключить устройство может только родитель", "Only a parent can link a device"),
    "Танҳо волидайн фарзандро хориҷ карда метавонад": ("Удалить ребёнка может только родитель", "Only a parent can remove a child"),
    "Танҳо сурати JPEG ё PNG": ("Только изображения JPEG или PNG", "Only JPEG or PNG images"),
    "Танҳо телефони фарзанд ин амалро карда метавонад": ("Это действие доступно только на телефоне ребёнка", "Only the child's phone can do this"),
    "Танҳо телефони фарзанд метавонад рӯйхати барномаҳоро фиристад": ("Список приложений может отправлять только телефон ребёнка", "Only the child's phone can send the app list"),
    "Танҳо телефони фарзанд метавонад ҷойгиршавиро фиристад": ("Местоположение может отправлять только телефон ребёнка", "Only the child's phone can send its location"),
    "Танҳо ҳисоби фарзанд метавонад пайваст шавад": ("Подключиться может только аккаунт ребёнка", "Only a child account can link"),
    "Фарзанд барои занг ёфт нашуд": ("Ребёнок для звонка не найден", "Child for this call not found"),
    "Фарзанд барои ин ҳисоб ёфт нашуд": ("Ребёнок для этого аккаунта не найден", "No child found for this account"),
    "Ҳадди аксар 10 ҷой": ("Максимум 10 мест", "Up to 10 places"),
    "Ҳисоб барои назорати оила иҷозат надорад": ("У аккаунта нет доступа к семейному контролю", "This account has no access to family controls"),
    "Ҳисоб ёфт нашуд": ("Аккаунт не найден", "Account not found"),
    "Ҳисоби админ барои барнома нест": ("Аккаунт администратора не для приложения", "Admin accounts cannot use the app"),
    "Ҳисоби волидайн ҳоло дар сервер кушода нашудааст": ("Аккаунт родителя ещё не создан на сервере", "The parent account does not exist on the server yet"),
    "Ҳисоб сохта нашуд. Аз нав кӯшиш кунед": ("Не удалось создать аккаунт. Попробуйте снова", "Could not create the account. Please try again"),
    "Ҳозир занги дигар идома дорад": ("Сейчас идёт другой звонок", "Another call is in progress"),
    "Ҷой ёфт нашуд": ("Место не найдено", "Place not found"),
    "Воридшавӣ бо GitHub тасдиқ нашуд": ("Вход через GitHub не подтверждён", "Sign in with GitHub could not be verified"),
    "GitHub ҳоло дастнорас аст. Баъдтар кӯшиш кунед": ("GitHub сейчас недоступен. Попробуйте позже", "GitHub is unavailable right now. Please try later"),
    "GitHub почтаи тасдиқшударо надод": ("GitHub не передал подтверждённую почту", "GitHub did not share a verified email address"),
    "Воридшавӣ бо Apple тасдиқ нашуд": ("Вход через Apple не подтверждён", "Sign in with Apple could not be verified"),
    "Apple ҳоло дастнорас аст. Баъдтар кӯшиш кунед": ("Apple сейчас недоступен. Попробуйте позже", "Apple is unavailable right now. Please try later"),
    "Apple почтаи электрониро надод": ("Apple не передал адрес почты", "Apple did not share an email address"),
    "Sign in with Apple дар сервер танзим нашудааст": ("Вход через Apple не настроен на сервере", "Sign in with Apple is not set up on the server"),
    "Google ҳоло дастнорас аст. Баъдтар кӯшиш кунед": ("Google сейчас недоступен. Попробуйте позже", "Google is unavailable right now. Please try later"),
    "Фарзанд барои ин волидайн ёфт нашуд": ("Ребёнок для этого родителя не найден", "No child found for this parent"),
    "Фарзанд пайдо нашуд": ("Ребёнок не найден", "Child not found"),
    "Профили фарзанд ёфт нашуд": ("Профиль ребёнка не найден", "Child profile not found"),
    "Санҷиши сессия ҳоло дастнорас аст": ("Проверка сессии сейчас недоступна", "Session check is unavailable right now"),
}


def request_lang(headers) -> str:
    """Select a supported response language from the mobile request headers."""

    lang = (headers.get("X-NIGOH-Lang") or "").strip().lower()[:2]
    return lang if lang in LANGS else "tg"


def translate(message: Optional[str], lang: str) -> Optional[str]:
    """Translate a known Tajik API message, preserving unknown messages."""

    if not message or lang == "tg" or not isinstance(message, str):
        return message
    pair = _MESSAGES.get(message)
    if pair is None:
        return message
    return pair[0] if lang == "ru" else pair[1]
