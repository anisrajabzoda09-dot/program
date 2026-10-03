// Файл: луғати тарҷумаҳои умумӣ, воридшавӣ ва танзимот.
/// Map-и матни тоҷикӣ ба тарҷумаҳои русӣ ва англисиро нигоҳ медорад.
const Map<String, List<String>> coreStrings = {
  // Server and network (core/api.dart, core/session.dart)
  'Сервер ҷавоб надод. Интернетро санҷед.': [
    'Сервер не ответил. Проверьте интернет.',
    'The server did not respond. Check your internet connection.',
  ],
  'Интернет нест. Пайвастшавиро санҷед.': [
    'Нет интернета. Проверьте подключение.',
    'No internet. Check your connection.',
  ],
  'Пайвастшавӣ ба сервер нашуд.': [
    'Не удалось подключиться к серверу.',
    'Could not connect to the server.',
  ],
  'Хатогӣ дар сервер ({code}). Баъдтар кӯшиш кунед.': [
    'Ошибка сервера ({code}). Попробуйте позже.',
    'Server error ({code}). Please try again later.',
  ],
  'Рамз бояд ақаллан 8 аломат бошад.': [
    'Пароль должен содержать не меньше 8 символов.',
    'The password must be at least 8 characters.',
  ],
  'Почтаи электронӣ нодуруст аст.': [
    'Неверный адрес электронной почты.',
    'Invalid email address.',
  ],
  'Маълумот нодуруст аст.': ['Неверные данные.', 'Invalid data.'],
  'Сервер токен надод. Аз нав кӯшиш кунед.': [
    'Сервер не выдал токен. Попробуйте ещё раз.',
    'The server did not return a token. Please try again.',
  ],
  'Google токен надод. Аз нав кӯшиш кунед.': [
    'Google не выдал токен. Попробуйте ещё раз.',
    'Google did not return a token. Please try again.',
  ],
  'Apple токен надод. Аз нав кӯшиш кунед.': [
    'Apple не выдал токен. Попробуйте ещё раз.',
    'Apple did not return a token. Please try again.',
  ],
  'Воридшавӣ бо Apple ҳоло дастрас нест.': [
    'Вход через Apple сейчас недоступен.',
    'Sign in with Apple is not available right now.',
  ],
  // Notifications (core/notify_bridge.dart, main.dart)
  'Огоҳиномаҳо кор накарданд.': [
    'Уведомления не работают.',
    'Notifications are not working.',
  ],
  'Хизмати огоҳиномаҳо оғоз нашуд.': [
    'Не удалось запустить службу уведомлений.',
    'Could not start the notification service.',
  ],
  'Хизмати огоҳиномаҳо қатъ нашуд.': [
    'Не удалось остановить службу уведомлений.',
    'Could not stop the notification service.',
  ],
  'Ҳолати огоҳиномаҳо маълум нашуд.': [
    'Не удалось узнать состояние уведомлений.',
    'Could not check the notification status.',
  ],
  'Танзимот кушода нашуд.': [
    'Не удалось открыть настройки.',
    'Could not open settings.',
  ],
  'Иҷозати огоҳиномаҳо дода нашуд.': [
    'Разрешение на уведомления не получено.',
    'Notification permission was not granted.',
  ],
  'Огоҳиномаҳо дар экрани пурра': [
    'Полноэкранные уведомления',
    'Full-screen notifications',
  ],
  'Барои он ки ҳушдори SOS ва зангҳо ҳатто дар экрани қулфшуда намоён шаванд, ба NIGOH иҷозати «огоҳиномаҳои экрани пурра» диҳед.':
      [
        'Чтобы сигналы SOS и звонки было видно даже на заблокированном экране, разрешите NIGOH «полноэкранные уведомления».',
        'To show SOS alerts and calls even on the lock screen, allow NIGOH to use full-screen notifications.',
      ],
  'Баъдтар': ['Позже', 'Later'],
  'Кушодани танзимот': ['Открыть настройки', 'Open settings'],
  'Фарзанд ёрӣ мехоҳад. Ҷойгиршавиро бинед.': [
    'Ребёнку нужна помощь. Посмотрите местоположение.',
    'Your child needs help. Check their location.',
  ],
  '{name} ёрӣ мехоҳад. Ҷойгиршавиро бинед.': [
    '{name} просит о помощи. Посмотрите местоположение.',
    '{name} needs help. Check their location.',
  ],
  'Хомӯш кардан': ['Выключить', 'Turn off'],
  // Shared widgets and helpers (ui/**, core/user_journey_logic.dart)
  '{m}д': ['{m}м', '{m}m'],
  '{h}с': ['{h}ч', '{h}h'],
  '{h}с {m}д': ['{h}ч {m}м', '{h}h {m}m'],
  'ҳозир': ['сейчас', 'now'],
  '{n} дақ пеш': ['{n} мин назад', '{n} min ago'],
  '{n} соат пеш': ['{n} ч назад', '{n} h ago'],
  'Забон: {language}': ['Язык: {language}', 'Language: {language}'],
  // Sign in (features/auth)
  'Воридшавӣ бо Google нашуд. {details}': [
    'Не удалось войти через Google. {details}',
    'Google sign-in failed. {details}',
  ],
  'Оилаи худро ором ва бехатар нигоҳ доред': [
    'Спокойствие и безопасность вашей семьи',
    'Keep your family calm and safe',
  ],
  'Ворид шудан': ['Войти', 'Sign in'],
  'Бақайдгирӣ': ['Регистрация', 'Sign up'],
  'Номро нависед.': ['Введите имя.', 'Enter your name.'],
  'Почтаи электронӣ': ['Электронная почта', 'Email'],
  'Почтаро нависед.': ['Введите почту.', 'Enter your email.'],
  'Рамз': ['Пароль', 'Password'],
  'Нишон додан': ['Показать', 'Show'],
  'Пинҳон кардан': ['Скрыть', 'Hide'],
  'Рамзро нависед.': ['Введите пароль.', 'Enter your password.'],
  'Сохтани аккаунт': ['Создать аккаунт', 'Create account'],
  'ё': ['или', 'or'],
  'Идома бо Google': ['Продолжить с Google', 'Continue with Google'],
  'Идома бо Apple': ['Продолжить с Apple', 'Continue with Apple'],
  'Идома бо GitHub': ['Продолжить с GitHub', 'Continue with GitHub'],
  'Воридшавӣ бо GitHub ҳоло дастрас нест.': [
    'Вход через GitHub сейчас недоступен.',
    'Sign in with GitHub is not available right now.',
  ],
  'Воридшавӣ бо GitHub нашуд. Аз нав кӯшиш кунед.': [
    'Не удалось войти через GitHub. Попробуйте ещё раз.',
    'GitHub sign-in failed. Please try again.',
  ],
  'GitHub почтаи тасдиқшударо надод. Почтаи худро дар GitHub тасдиқ кунед ва аз нав кӯшиш кунед.': [
    'GitHub не передал подтверждённую почту. Подтвердите свою почту на GitHub и попробуйте ещё раз.',
    'GitHub did not share a verified e-mail. Verify your e-mail on GitHub and try again.',
  ],
  'Воридшавӣ бо Apple нашуд. {details}': [
    'Не удалось войти через Apple. {details}',
    'Apple sign-in failed. {details}',
  ],
  'Агар пештар бо почта ворид мешудед, як бор аз нав бақайдгирӣ кунед.': [
    'Если раньше вы входили по почте, зарегистрируйтесь заново один раз.',
    'If you used to sign in with email, please sign up again once.',
  ],
  // Role and child profile (features/onboarding)
  'Хуш омадед': ['Добро пожаловать', 'Welcome'],
  'Салом, {name}': ['Привет, {name}', 'Hi, {name}'],
  'Ин телефонро кӣ истифода мебарад?': [
    'Кто пользуется этим телефоном?',
    'Who uses this phone?',
  ],
  'Барномаҳо, ҷойгиршавӣ ва чати фарзандро бинед.': [
    'Приложения, местоположение и чат с ребёнком.',
    'See your child\'s apps, location and chat.',
  ],
  'Ин телефонро ба волидайн пайваст кунед.': [
    'Подключите этот телефон к родителю.',
    'Connect this phone to a parent.',
  ],
  'Маълумот нигоҳ дошта нашуд: {error}': [
    'Не удалось сохранить данные: {error}',
    'Could not save the data: {error}',
  ],
  'Дар бораи худ': ['О себе', 'About you'],
  'Баромадан': ['Выйти', 'Sign out'],
  'Волидайн инро дар телефони худ мебинанд.': [
    'Родитель увидит это на своём телефоне.',
    'Your parent will see this on their phone.',
  ],
  'Ҷинс': ['Пол', 'Gender'],
  'Писар': ['Мальчик', 'Boy'],
  'Духтар': ['Девочка', 'Girl'],
  'Синну сол': ['Возраст', 'Age'],
  'Идома': ['Продолжить', 'Continue'],
  // Permissions wizard (features/onboarding/permissions_wizard.dart)
  'Нигоҳ доштани ҳолат нашуд: {error}': [
    'Не удалось сохранить состояние: {error}',
    'Could not save progress: {error}',
  ],
  'Ҷамъбаст': ['Итог', 'Summary'],
  'Қадами {step} аз {total}': [
    'Шаг {step} из {total}',
    'Step {step} of {total}',
  ],
  'Ба барнома': ['В приложение', 'Go to app'],
  'Бозгашт': ['Назад', 'Back'],
  'GPS (ҷойгиршавӣ) дар телефон хомӯш аст.': [
    'GPS (местоположение) на телефоне выключен.',
    'GPS (location) is turned off on this phone.',
  ],
  'Фаъол кардан': ['Включить', 'Turn on'],
  'Аввал «Дастрасӣ ба истифода» ва «Намоиш болои барномаҳо» лозим аст — тугма аввал ҳамонҳоро мекушояд.':
      [
        'Сначала нужны «Доступ к истории использования» и «Поверх других приложений» — кнопка сначала откроет их.',
        'Usage access and Display over other apps are needed first — the button opens them first.',
      ],
  'Иҷозат дода шуд': ['Разрешено', 'Allowed'],
  'Иҷозат додан': ['Разрешить', 'Allow'],
  'Агар иҷозат дода нашуд — ин ҷоро пахш кунед': [
    'Если не получилось — нажмите здесь',
    'If it didn\'t work — tap here',
  ],
  'Чӣ бояд кард?': ['Что нужно сделать?', 'What to do?'],
  'Ҳамааш тайёр': ['Всё готово', 'All set'],
  'Ҳамаи иҷозатҳо дода шуданд. NIGOH Family пурра кор мекунад.': [
    'Все разрешения выданы. NIGOH Family работает полностью.',
    'All permissions are granted. NIGOH Family is fully working.',
  ],
  '{count} иҷозат ҳоло дода нашудааст. Барои танзим ба он пахш кунед.': [
    'Не выдано разрешений: {count}. Нажмите, чтобы настроить.',
    'Permissions not granted yet: {count}. Tap one to set it up.',
  ],
  'Дода нашудааст — пахш кунед': ['Не выдано — нажмите', 'Not granted — tap'],
  // Permission steps (features/onboarding/permission_steps.dart). Android setting names are given as Android shows them in that language.
  'Танзимоти GPS кушода нашуд.': [
    'Не удалось открыть настройки GPS.',
    'Could not open GPS settings.',
  ],
  'Танзимоти барнома кушода нашуд. Худатон кушоед: Танзимот → Барномаҳо → NIGOH Family.':
      [
        'Не удалось открыть настройки приложения. Откройте вручную: Настройки → Приложения → NIGOH Family.',
        'Could not open app settings. Open them yourself: Settings → Apps → NIGOH Family.',
      ],
  'Ин танзимот дар ин дастгоҳ дастрас нест.': [
    'Эта настройка недоступна на этом устройстве.',
    'This setting is not available on this device.',
  ],
  'Android хато дод ({code}).': [
    'Ошибка Android ({code}).',
    'Android error ({code}).',
  ],
  'Хато: {error}': ['Ошибка: {error}', 'Error: {error}'],
  'Ҷойгиршавӣ — «Ҳамеша»': [
    'Местоположение — «Всегда»',
    'Location — "All the time"',
  ],
  'То волидайн ҷойи шуморо ҳатто ҳангоми баста будани барнома бинанд, дар саҳифаи навбатӣ «Ҳамеша иҷозат додан»-ро интихоб кунед.':
      [
        'Чтобы родитель видел, где вы, даже когда приложение закрыто, на следующей странице выберите «Разрешить в любом режиме».',
        'So your parent can see where you are even when the app is closed, choose "Allow all the time" on the next screen.',
      ],
  '«Иҷозат додан»-ро пахш кунед — саҳифаи «Ҷойгиршавӣ» кушода мешавад.': [
    'Нажмите «Разрешить» — откроется страница «Местоположение».',
    'Tap "Allow" — the "Location" page opens.',
  ],
  '«Ҳамеша иҷозат додан» (Разрешить в любом режиме / Allow all the time)-ро интихоб кунед.':
      ['Выберите «Разрешить в любом режиме».', 'Choose "Allow all the time".'],
  'Бо тугмаи «Бозгашт» ба NIGOH баргардед.': [
    'Вернитесь в NIGOH кнопкой «Назад».',
    'Go back to NIGOH with the Back button.',
  ],
  'Волидайн дар харита мебинанд, ки шумо дар куҷоед. Ин дар ҳолати SOS хеле муҳим аст.':
      [
        'Родитель видит на карте, где вы. Это очень важно при SOS.',
        'Your parent sees on the map where you are. This is very important for SOS.',
      ],
  '«Иҷозат додан»-ро пахш кунед.': ['Нажмите «Разрешить».', 'Tap "Allow".'],
  'Дар равзана «Ҳангоми истифодаи барнома» (При использовании приложения)-ро интихоб кунед.':
      [
        'В окне выберите «При использовании приложения».',
        'In the dialog, choose "While using the app".',
      ],
  'Агар равзана набарояд: Настройки → Приложения → NIGOH Family → Разрешения → Местоположение.':
      [
        'Если окно не появилось: Настройки → Приложения → NIGOH Family → Разрешения → Местоположение.',
        'If no dialog appears: Settings → Apps → NIGOH Family → Permissions → Location.',
      ],
  'GPS (Местоположение) дар панели болоии телефон бояд фаъол бошад.': [
    'GPS («Местоположение») в верхней панели телефона должен быть включён.',
    'GPS ("Location") must be on in the phone\'s quick settings panel.',
  ],
  'Паёмҳо, зангҳо ва ҳушдорҳои оила фавран меоянд, ҳатто вақте ки барнома баста аст.':
      [
        'Сообщения, звонки и семейные оповещения приходят сразу, даже когда приложение закрыто.',
        'Messages, calls and family alerts arrive instantly, even when the app is closed.',
      ],
  '«Иҷозат додан»-ро пахш кунед ва «Разрешить»-ро интихоб кунед.': [
    'Нажмите «Разрешить», затем в системном окне тоже «Разрешить».',
    'Tap "Allow", then choose "Allow" in the system dialog.',
  ],
  'Агар равзана набарояд: Настройки → Приложения → NIGOH Family → Уведомления.':
      [
        'Если окно не появилось: Настройки → Приложения → NIGOH Family → Уведомления.',
        'If no dialog appears: Settings → Apps → NIGOH Family → Notifications.',
      ],
  '«Показывать уведомления»-ро фаъол кунед.': [
    'Включите «Показывать уведомления».',
    'Turn on "Show notifications".',
  ],
  'Дастрасӣ ба истифода': ['Доступ к истории использования', 'Usage access'],
  'NIGOH вақти истифодаи ҳар барномаро ҳисоб мекунад, то маҳдудиятҳои волидайн кор кунанд.':
      [
        'NIGOH считает время в каждом приложении, чтобы работали ограничения родителя.',
        'NIGOH counts the time spent in each app so your parent\'s limits can work.',
      ],
  '«Иҷозат додан»-ро пахш кунед — рӯйхати «Доступ к истории использования» кушода мешавад.':
      [
        'Нажмите «Разрешить» — откроется список «Доступ к истории использования».',
        'Tap "Allow" — the "Usage access" list opens.',
      ],
  'NIGOH Family-ро ёбед ва пахш кунед.': [
    'Найдите NIGOH Family и нажмите на него.',
    'Find NIGOH Family and tap it.',
  ],
  '«Разрешить доступ к истории использования»-ро фаъол кунед.': [
    'Включите «Разрешить доступ к истории использования».',
    'Turn on "Permit usage access".',
  ],
  'Намоиш болои барномаҳо': [
    'Поверх других приложений',
    'Display over other apps',
  ],
  'Вақте ки барнома маҳкам аст, NIGOH экрани муҳофизатро болои он нишон медиҳад.':
      [
        'Когда приложение заблокировано, NIGOH показывает поверх него экран защиты.',
        'When an app is blocked, NIGOH shows a protection screen over it.',
      ],
  '«Иҷозат додан»-ро пахш кунед — саҳифаи «Поверх других приложений» кушода мешавад.':
      [
        'Нажмите «Разрешить» — откроется страница «Поверх других приложений».',
        'Tap "Allow" — the "Display over other apps" page opens.',
      ],
  'Агар рӯйхат бошад, NIGOH Family-ро интихоб кунед.': [
    'Если открылся список, выберите NIGOH Family.',
    'If you see a list, choose NIGOH Family.',
  ],
  '«Разрешить показ поверх других приложений»-ро фаъол кунед.': [
    'Включите «Разрешить показ поверх других приложений».',
    'Turn on "Allow display over other apps".',
  ],
  'Специальные возможности': ['Специальные возможности', 'Accessibility'],
  'Ин хизмат барномаи маҳкамшударо фавран мебандад. NIGOH матн ва паролҳои шуморо намехонад.':
      [
        'Эта служба сразу закрывает заблокированное приложение. NIGOH не читает ваши тексты и пароли.',
        'This service closes a blocked app instantly. NIGOH does not read your texts or passwords.',
      ],
  '«Иҷозат додан»-ро пахш кунед — «Специальные возможности» кушода мешавад.': [
    'Нажмите «Разрешить» — откроются «Специальные возможности».',
    'Tap "Allow" — "Accessibility" opens.',
  ],
  '«Установленные приложения» (ё «Скачанные приложения») → NIGOH Family-ро кушоед.':
      [
        'Откройте «Установленные приложения» (или «Скачанные приложения») → NIGOH Family.',
        'Open "Installed apps" (or "Downloaded apps") → NIGOH Family.',
      ],
  'Хизматро фаъол кунед ва «Разрешить»-ро пахш кунед.': [
    'Включите службу и нажмите «Разрешить».',
    'Turn the service on and tap "Allow".',
  ],
  'Агар «Ограниченная настройка» ё «Доступ запрещен» барояд (Android 13+): Настройки → Приложения → NIGOH Family → ⋮ (се нуқта дар боло) → «Разрешить ограниченные настройки». Баъд аз қадами 1 такрор кунед.':
      [
        'Если появилось «Ограниченная настройка» или «Доступ запрещен» (Android 13+): Настройки → Приложения → NIGOH Family → ⋮ (три точки вверху) → «Разрешить ограниченные настройки». Затем повторите с шага 1.',
        'If you see "Restricted setting" or "App was denied access" (Android 13+): Settings → Apps → NIGOH Family → ⋮ (three dots at the top) → "Allow restricted settings". Then repeat from step 1.',
      ],
  'Дар баъзе Samsung (One UI) банди ⋮ танҳо баъд аз як бор кӯшиш кардан ва дидани «Доступ запрещен» пайдо мешавад — аввал як бор кӯшиш кунед.':
      [
        'На некоторых Samsung (One UI) пункт ⋮ появляется только после одной попытки и сообщения «Доступ запрещен» — сначала попробуйте один раз.',
        'On some Samsung phones (One UI) the ⋮ option appears only after one attempt shows "App was denied access" — try once first.',
      ],
  'Дар Samsung, агар боз ҳам нашавад: Настройки → Безопасность и конфиденциальность → «Автоблокировка» (Auto Blocker)-ро хомӯш кунед.':
      [
        'На Samsung, если всё равно не получается: Настройки → Безопасность и конфиденциальность → выключите «Автоблокировку».',
        'On Samsung, if it still does not work: Settings → Security and privacy → turn off "Auto Blocker".',
      ],
  'Ҳимоя аз нест кардан': ['Защита от удаления', 'Uninstall protection'],
  'NIGOH-ро бе PIN-и волидайн нест кардан мумкин намешавад. Ин ҳимояи оила аст.':
      [
        'NIGOH нельзя будет удалить без PIN-кода родителя. Это защита семьи.',
        'NIGOH cannot be uninstalled without the parent PIN. This protects your family.',
      ],
  '«Иҷозат додан»-ро пахш кунед — саҳифаи «Администратор устройства» кушода мешавад.':
      [
        'Нажмите «Разрешить» — откроется страница «Администратор устройства».',
        'Tap "Allow" — the "Device admin app" page opens.',
      ],
  'Ба поён ҳаракат диҳед ва «Активировать» (Фаъол кардан)-ро пахш кунед.': [
    'Прокрутите вниз и нажмите «Активировать».',
    'Scroll down and tap "Activate this device admin app".',
  ],
  'Агар саҳифа кушода нашавад: Настройки → Безопасность → Администраторы устройства → NIGOH Family.':
      [
        'Если страница не открылась: Настройки → Безопасность → Администраторы устройства → NIGOH Family.',
        'If the page does not open: Settings → Security → Device admin apps → NIGOH Family.',
      ],
  'Барои зангҳои овозӣ байни волидайн ва фарзанд лозим аст.': [
    'Нужен для голосовых звонков между родителем и ребёнком.',
    'Needed for voice calls between parent and child.',
  ],
  'Агар равзана набарояд: Настройки → Приложения → NIGOH Family → Разрешения → Микрофон → «Разрешить».':
      [
        'Если окно не появилось: Настройки → Приложения → NIGOH Family → Разрешения → Микрофон → «Разрешить».',
        'If no dialog appears: Settings → Apps → NIGOH Family → Permissions → Microphone → "Allow".',
      ],
  'Батарея': ['Батарея', 'Battery'],
  'Android барномаро барои сарфаи батарея қатъ накунад, то ҷойгиршавӣ ва огоҳиномаҳо дар пасзамина кор кунанд.':
      [
        'Чтобы Android не останавливал приложение ради экономии батареи и местоположение и уведомления работали в фоне.',
        'So Android does not stop the app to save battery, and location and notifications keep working in the background.',
      ],
  '«Иҷозат додан»-ро пахш кунед ва дар равзана «Разрешить»-ро интихоб кунед.': [
    'Нажмите «Разрешить» и в окне тоже выберите «Разрешить».',
    'Tap "Allow" and choose "Allow" in the dialog.',
  ],
  'Агар равзана набарояд: Настройки → Приложения → NIGOH Family → Батарея → «Без ограничений» (Не оптимизировать).':
      [
        'Если окно не появилось: Настройки → Приложения → NIGOH Family → Батарея → «Без ограничений» («Не оптимизировать»).',
        'If no dialog appears: Settings → Apps → NIGOH Family → Battery → "Unrestricted" ("Don\'t optimize").',
      ],
  'Дар Samsung: инчунин NIGOH-ро аз «Спящие приложения» хориҷ кунед.': [
    'На Samsung также уберите NIGOH из «Спящих приложений».',
    'On Samsung, also remove NIGOH from "Sleeping apps".',
  ],
  'Экрани пурра': ['Полноэкранный режим', 'Full screen'],
  'Ҳушдори SOS ва зангҳо ҳатто дар экрани қулфшуда дар тамоми экран намоён мешаванд.':
      [
        'Сигналы SOS и звонки показываются на весь экран, даже на заблокированном.',
        'SOS alerts and calls appear full screen, even on the lock screen.',
      ],
  '«Иҷозат додан»-ро пахш кунед — «Полноэкранные уведомления» кушода мешавад.':
      [
        'Нажмите «Разрешить» — откроются «Полноэкранные уведомления».',
        'Tap "Allow" — "Full screen notifications" opens.',
      ],
  'NIGOH Family-ро фаъол кунед.': [
    'Включите NIGOH Family.',
    'Turn on NIGOH Family.',
  ],
  'Занг дар экран': ['Звонок на экране', 'Calls on screen'],
  'Занги воридотӣ ва ҳушдори SOS дарҳол дар тамоми экран кушода мешаванд, ҳатто вақте ки шумо бо телефон кор мекунед.':
      [
        'Входящий звонок и сигнал SOS сразу открываются на весь экран, даже когда вы пользуетесь телефоном.',
        'Incoming calls and SOS alerts open full screen right away, even while you are using the phone.',
      ],
  'Камера': ['Камера', 'Camera'],
  'Барои скан кардани QR-коди телефони фарзанд ҳангоми пайвастшавӣ.': [
    'Чтобы отсканировать QR-код с телефона ребёнка при подключении.',
    'To scan the QR code on your child\'s phone when connecting.',
  ],
  'Агар равзана набарояд: Настройки → Приложения → NIGOH Family → Разрешения → Камера → «Разрешить».':
      [
        'Если окно не появилось: Настройки → Приложения → NIGOH Family → Разрешения → Камера → «Разрешить».',
        'If no dialog appears: Settings → Apps → NIGOH Family → Permissions → Camera → "Allow".',
      ],
  // Access center (pages/access_center_page.dart)
  'Ҳолати иҷозатҳо санҷида нашуд. Дубора кӯшиш кунед.': [
    'Не удалось проверить разрешения. Попробуйте ещё раз.',
    'Could not check permissions. Please try again.',
  ],
  'Танзимот кушода нашуд. Аз Settings → Apps → NIGOH Family кушоед.': [
    'Не удалось открыть настройки. Откройте: Настройки → Приложения → NIGOH Family.',
    'Could not open settings. Open Settings → Apps → NIGOH Family.',
  ],
  'Барои дидани ҷойи фарзанд дар харита.': [
    'Чтобы видеть ребёнка на карте.',
    'To see your child on the map.',
  ],
  'Барои паёмҳои оила ва дархостҳои нав.': [
    'Для семейных сообщений и новых запросов.',
    'For family messages and new requests.',
  ],
  'Барои ҳисоб кардани вақти ҳар барнома.': [
    'Чтобы считать время в каждом приложении.',
    'To count the time spent in each app.',
  ],
  'Барои нишон додани экрани маҳкамкунӣ.': [
    'Чтобы показывать экран блокировки.',
    'To show the block screen.',
  ],
  'Барои маҳкамкунии фаврии барномаи интихобшуда.': [
    'Чтобы сразу блокировать выбранное приложение.',
    'To block the chosen app instantly.',
  ],
  'Камера барои QR': ['Камера для QR', 'Camera for QR'],
  'Ихтиёрӣ: пайвастшавӣ бо QR осонтар мешавад.': [
    'Необязательно: подключение по QR-коду проще.',
    'Optional: makes connecting by QR code easier.',
  ],
  'Ҷойгиршавӣ дар пасзамина': ['Местоположение в фоне', 'Background location'],
  'Ихтиёрӣ: ҷой ҳангоми баста будани экран нав мешавад.': [
    'Необязательно: местоположение обновляется при выключенном экране.',
    'Optional: location updates while the screen is off.',
  ],
  'Муҳофизати несткунӣ': ['Защита от удаления', 'Uninstall protection'],
  'Ихтиёрӣ: огоҳӣ пеш аз ғайрифаъолкунӣ.': [
    'Необязательно: предупреждение перед отключением.',
    'Optional: a warning before it is turned off.',
  ],
  'Омодасозии NIGOH': ['Настройка NIGOH', 'NIGOH setup'],
  'Қадам ба қадам': ['Шаг за шагом', 'Step by step'],
  'Барои кори дурусти NIGOH чанд иҷозати Android лозим аст.': [
    'Для правильной работы NIGOH нужно несколько разрешений Android.',
    'NIGOH needs a few Android permissions to work properly.',
  ],
  '{done} аз {total} омода': [
    'Готово {done} из {total}',
    '{done} of {total} ready',
  ],
  'Кушодани App info': ['Открыть «О приложении»', 'Open App info'],
  'Иҷозатҳои бастани барномаҳо дода шуданд': [
    'Разрешения для блокировки приложений выданы',
    'App blocking permissions are granted',
  ],
  'Акнун волидайн метавонад вақт ва барномаҳоро идора кунад.': [
    'Теперь родитель может управлять временем и приложениями.',
    'Your parent can now manage screen time and apps.',
  ],
  'Бастани барномаҳо ҳоло омода нест': [
    'Блокировка приложений пока не готова',
    'App blocking is not ready yet',
  ],
  'Барои App Control се иҷозати Android лозим аст: Usage access, Accessibility ва Display over other apps.':
      [
        'Для управления приложениями нужны три разрешения Android: «Доступ к истории использования», «Специальные возможности» и «Поверх других приложений».',
        'App control needs three Android permissions: Usage access, Accessibility and Display over other apps.',
      ],
  '«Restricted setting» ё «App was denied access»?': [
    '«Ограниченная настройка» или «Доступ запрещен»?',
    '"Restricted setting" or "App was denied access"?',
  ],
  'Аввал қадамҳои кабуди болоиро иҷро кунед, баъд ҳар иҷозатро аз рӯйхати поён боз кунед.':
      [
        'Сначала выполните синие шаги вверху, затем откройте каждое разрешение из списка ниже.',
        'First complete the blue steps above, then open each permission in the list below.',
      ],
  'Агар Android «Controlled by restricted setting» гӯяд': [
    'Если Android пишет «Ограниченная настройка»',
    'If Android says "Controlled by restricted setting"',
  ],
  '1. «App info»-ро кушоед.\n2. Дар кунҷи боло ⋮ → «Allow restricted settings»-ро интихоб кунед ва бо рамзи телефон тасдиқ намоед.\n3. Ба ин саҳифа баргардед ва Usage access, Display over other apps ва Accessibility-ро як-як фаъол кунед.':
      [
        '1. Откройте «О приложении».\n2. В правом верхнем углу ⋮ → выберите «Разрешить ограниченные настройки» и подтвердите кодом телефона.\n3. Вернитесь на эту страницу и по очереди включите «Доступ к истории использования», «Поверх других приложений» и «Специальные возможности».',
        '1. Open "App info".\n2. In the top corner tap ⋮ → "Allow restricted settings" and confirm with your phone\'s screen lock.\n3. Come back to this page and turn on Usage access, Display over other apps and Accessibility one by one.',
      ],
  'Ин танзимро танҳо соҳиби телефон дар Android дода метавонад; NIGOH онро худкор фаъол карда наметавонад.':
      [
        'Эту настройку может включить только владелец телефона в Android; NIGOH не может включить её сам.',
        'Only the phone\'s owner can allow this in Android; NIGOH cannot turn it on by itself.',
      ],
  'Ҳамаи қадамҳои асосӣ тайёр': [
    'Все основные шаги выполнены',
    'All main steps are done',
  ],
  'Иҷозати навбатӣ': ['Следующее разрешение', 'Next permission'],
  'Аз нав санҷидан': ['Проверить снова', 'Check again'],
  'Агар Android иҷозатро боз ҳам маҳкам кунад, онро аз Settings → Apps → NIGOH Family фаъол кунед. Ин маҳдудияти худи Android аст.':
      [
        'Если Android всё равно блокирует разрешение, включите его в Настройки → Приложения → NIGOH Family. Это ограничение самого Android.',
        'If Android still blocks the permission, turn it on in Settings → Apps → NIGOH Family. This is a limitation of Android itself.',
      ],
  'ихтиёрӣ': ['необязательно', 'optional'],
  // App update (features/settings/app_update.dart)
  'Навсозӣ санҷида нашуд.': [
    'Не удалось проверить обновление.',
    'Could not check for updates.',
  ],
  'Шумо версияи охиринро доред.': [
    'У вас последняя версия.',
    'You have the latest version.',
  ],
  'Версияи нав бо беҳбудиҳо дастрас аст.': [
    'Доступна новая версия с улучшениями.',
    'A new version with improvements is available.',
  ],
  'Пайванди навсозӣ дастрас нест.': [
    'Ссылка на обновление недоступна.',
    'The update link is not available.',
  ],
  'Навсозӣ оғоз нашуд. Интернетро санҷед.': [
    'Не удалось начать обновление. Проверьте интернет.',
    'Could not start the update. Check your internet connection.',
  ],
  'Як бор иҷозат диҳед: «Иҷозати насб аз ин манбаъ»-ро фаъол кунед ва ба NIGOH баргардед — навсозӣ худаш идома меёбад.':
      [
        'Разрешите один раз: включите «Разрешить установку из этого источника» и вернитесь в NIGOH — обновление продолжится само.',
        'Allow it once: turn on "Allow from this source" and return to NIGOH — the update will continue by itself.',
      ],
  'Боргирӣ… {percent}%': ['Загрузка… {percent}%', 'Downloading… {percent}%'],
  'Санҷиши имзо…': ['Проверка подписи…', 'Checking signature…'],
  'Насб…': ['Установка…', 'Installing…'],
  'Навсозӣ насб шуд.': ['Обновление установлено.', 'Update installed.'],
  'Навсозӣ насб нашуд.': [
    'Не удалось установить обновление.',
    'Could not install the update.',
  ],
  'Навсозӣ то {version}': ['Обновление до {version}', 'Update to {version}'],
  'Маълумот, воридшавӣ ва иҷозатҳо нигоҳ дошта мешаванд.': [
    'Данные, вход и разрешения сохранятся.',
    'Your data, sign-in and permissions are kept.',
  ],
  'Хуб': ['ОК', 'OK'],
  // Parent PIN (features/settings/parent_pin.dart)
  'Рамзи ҷорӣ нодуруст аст.': [
    'Неверный текущий код.',
    'The current code is incorrect.',
  ],
  'Рамз нигоҳ дошта нашуд. Дубора кӯшиш кунед.': [
    'Не удалось сохранить код. Попробуйте ещё раз.',
    'Could not save the code. Please try again.',
  ],
  'PIN-и волидайн': ['PIN-код родителя', 'Parent PIN'],
  'PIN нодуруст аст.': ['Неверный PIN-код.', 'Incorrect PIN.'],
  'PIN санҷида нашуд.': [
    'Не удалось проверить PIN-код.',
    'Could not check the PIN.',
  ],
  'PIN (4 рақам)': ['PIN-код (4 цифры)', 'PIN (4 digits)'],
  'Тасдиқ': ['Подтвердить', 'Confirm'],
  'PIN бояд аз 4 рақам иборат бошад.': [
    'PIN-код должен состоять из 4 цифр.',
    'The PIN must be 4 digits.',
  ],
  'Такрори PIN мувофиқ нест.': [
    'PIN-коды не совпадают.',
    'The PINs do not match.',
  ],
  'PIN нигоҳ дошта нашуд.': [
    'Не удалось сохранить PIN-код.',
    'Could not save the PIN.',
  ],
  'Иваз кардани PIN': ['Сменить PIN-код', 'Change PIN'],
  'Гузоштани PIN': ['Установить PIN-код', 'Set PIN'],
  'PIN дар ҳамин телефон нигоҳ дошта мешавад ва барои амалҳои муҳим лозим аст.':
      [
        'PIN-код хранится на этом телефоне и нужен для важных действий.',
        'The PIN is stored on this phone and is needed for important actions.',
      ],
  'PIN-и ҷорӣ': ['Текущий PIN-код', 'Current PIN'],
  'PIN-и нав': ['Новый PIN-код', 'New PIN'],
  'Такрори PIN': ['Повторите PIN-код', 'Repeat PIN'],
  // Profile photo (features/settings/profile_photo.dart)
  'Аз галерея': ['Из галереи', 'From gallery'],
  'Сурат гирифтан': ['Сделать фото', 'Take photo'],
  'Иҷозат дода нашуд. Дар танзимоти телефон иҷозати камераро диҳед.': [
    'Нет разрешения. Разрешите доступ к камере в настройках телефона.',
    'Permission denied. Allow camera access in the phone settings.',
  ],
  'Иҷозат дода нашуд. Дар танзимоти телефон иҷозати суратҳоро диҳед.': [
    'Нет разрешения. Разрешите доступ к фото в настройках телефона.',
    'Permission denied. Allow photo access in the phone settings.',
  ],
  'Сурат интихоб нашуд: {error}': [
    'Не удалось выбрать фото: {error}',
    'Could not pick a photo: {error}',
  ],
  'Сурат холӣ аст. Дигарашро интихоб кунед.': [
    'Фото пустое. Выберите другое.',
    'The photo is empty. Choose another one.',
  ],
  'Сурат хеле калон аст. Сурати хурдтар интихоб кунед.': [
    'Фото слишком большое. Выберите поменьше.',
    'The photo is too large. Choose a smaller one.',
  ],
  'Сурат нигоҳ дошта шуд.': ['Фото сохранено.', 'Photo saved.'],
  'Сурат нест карда шуд.': ['Фото удалено.', 'Photo removed.'],
  'Сурати профил': ['Фото профиля', 'Profile photo'],
  // Settings (features/settings/settings_screen.dart)
  'Ҳолати PIN маълум нашуд.': [
    'Не удалось узнать состояние PIN-кода.',
    'Could not check the PIN status.',
  ],
  'Ном нигоҳ дошта шуд.': ['Имя сохранено.', 'Name saved.'],
  'PIN иваз шуд.': ['PIN-код изменён.', 'PIN changed.'],
  'PIN гузошта шуд.': ['PIN-код установлен.', 'PIN set.'],
  'Барои баромадан аз аккаунт PIN-и волидайн лозим аст.': [
    'Чтобы выйти из аккаунта, нужен PIN-код родителя.',
    'The parent PIN is required to sign out.',
  ],
  'Аз аккаунт бароед?': ['Выйти из аккаунта?', 'Sign out?'],
  'Барои идома боз ворид шудан лозим мешавад.': [
    'Чтобы продолжить, нужно будет войти снова.',
    'You will need to sign in again to continue.',
  ],
  'Тасдиқ шуд. Android экрани несткуниро мекушояд.': [
    'Подтверждено. Android откроет экран удаления.',
    'Confirmed. Android will open the uninstall screen.',
  ],
  'Амният': ['Безопасность', 'Security'],
  'Фаъол аст': ['Включён', 'On'],
  'Гузошта нашудааст': ['Не установлен', 'Not set'],
  'Иваз кардан': ['Изменить', 'Change'],
  'Гузоштан': ['Установить', 'Set'],
  'Иҷозатҳо (устод)': ['Разрешения (мастер)', 'Permissions (wizard)'],
  'Ҷойгиршавӣ, истифода ва бастани барномаҳо': [
    'Местоположение, использование и блокировка приложений',
    'Location, usage and app blocking',
  ],
  'Огоҳиномаҳо, камера, микрофон ва батарея': [
    'Уведомления, камера, микрофон и батарея',
    'Notifications, camera, microphone and battery',
  ],
  'Муҳофизат аз несткунӣ': ['Защита от удаления', 'Uninstall protection'],
  'NIGOH-ро танҳо бо PIN-и волидайн нест кардан мумкин аст.': [
    'NIGOH можно удалить только с PIN-кодом родителя.',
    'NIGOH can only be uninstalled with the parent PIN.',
  ],
  'Намуд': ['Оформление', 'Appearance'],
  'Система': ['Системная', 'System'],
  'Равшан': ['Светлая', 'Light'],
  'Торик': ['Тёмная', 'Dark'],
  'Забон': ['Язык', 'Language'],
  'Версия': ['Версия', 'Version'],
  'Санҷидани навсозӣ': ['Проверить обновления', 'Check for updates'],
  'Ҳолат маълум нашуд': ['Состояние неизвестно', 'Status unknown'],
  'Хомӯш аст — паёмҳо ва SOS намерасанд': [
    'Выключены — сообщения и SOS не приходят',
    'Off — messages and SOS will not arrive',
  ],
  'Барои SOS ва зангҳо иҷозати экрани пурра лозим': [
    'Для SOS и звонков нужны полноэкранные уведомления',
    'SOS and calls need full-screen permission',
  ],
  'Фаъол: паёмҳо, SOS ва зангҳо': [
    'Включены: сообщения, SOS и звонки',
    'On: messages, SOS and calls',
  ],
  'Баромадан аз аккаунт': ['Выйти из аккаунта', 'Sign out'],
  'Истифодабаранда': ['Пользователь', 'User'],
  'Тағйири ном': ['Изменить имя', 'Change name'],
  'Номи шумо': ['Ваше имя', 'Your name'],
  'Кӯшишҳо баста шуданд. Баъд аз {seconds} сония дубора кӯшиш кунед.': [
    'Слишком много попыток. Повторите через {seconds} с.',
    'Too many attempts. Try again in {seconds} s.',
  ],
  'Аввал PIN-и волидайнро гузоред.': [
    'Сначала установите PIN-код родителя.',
    'Set the parent PIN first.',
  ],
  'Амал иҷро нашуд.': ['Не удалось выполнить действие.', 'The action failed.'],
  'Тасдиқи волидайн': ['Подтверждение родителя', 'Parent confirmation'],
  'Барои нест кардани NIGOH PIN-и волидайнро ворид кунед.': [
    'Чтобы удалить NIGOH, введите PIN-код родителя.',
    'Enter the parent PIN to uninstall NIGOH.',
  ],
  // v2.16.0
  'Хомӯш аст': ['Выключены', 'Off'],
  'Дидан': ['Открыть', 'Open'],
  'Режими торик': ['Тёмная тема', 'Dark mode'],

  // v2.17.0 — clearer shared surfaces, visible uninstall action.
  'Нест кардани барнома': ['Удалить приложение', 'Uninstall the app'],
  'NIGOH пинҳон нест. Барномаро нест кардан мумкин аст, вале PIN-и волидайн лозим аст.':
      [
        'NIGOH не скрыт. Приложение можно удалить, но нужен PIN родителя.',
        'NIGOH is not hidden. The app can be removed, but the parent PIN is required.',
      ],
  'PIN-и волидайнро мепурсад, баъд Android экрани несткуниро мекушояд.': [
    'Спросит PIN родителя, затем откроется экран удаления Android.',
    'Asks for the parent PIN, then Android opens its uninstall screen.',
  ],
  'Аввал волидайн PIN гузорад.': [
    'Сначала родитель должен задать PIN.',
    'A parent has to set the PIN first.',
  ],
  'PIN-и волидайн гузошта нашудааст': [
    'PIN родителя не задан',
    'No parent PIN yet',
  ],
  'Нест кардани NIGOH танҳо бо PIN-и волидайн мумкин аст. Аввал волидайн PIN гузорад.':
      [
        'Удалить NIGOH можно только с PIN родителя. Сначала родитель должен задать PIN.',
        'NIGOH can only be removed with the parent PIN. A parent has to set it first.',
      ],
  'Нест кардани NIGOH танҳо бо PIN-и волидайн мумкин аст. PIN-ро ворид кунед — баъд Android экрани несткуниро мекушояд.':
      [
        'Удалить NIGOH можно только с PIN родителя. Введите PIN — затем откроется экран удаления Android.',
        'NIGOH can only be removed with the parent PIN. Enter it and Android will open its uninstall screen.',
      ],
  'PIN нодуруст аст. Барнома нест карда нашуд.': [
    'Неверный PIN. Приложение не удалено.',
    'Wrong PIN. The app was not removed.',
  ],
  'PIN-и волидайн ва иҷозатҳои Android.': [
    'PIN родителя и разрешения Android.',
    'Parent PIN and Android permissions.',
  ],
  'Фаъол аст — амалҳои муҳим PIN мепурсанд': [
    'Включён — важные действия спрашивают PIN',
    'On — important actions ask for the PIN',
  ],
  'Гузошта нашудааст — ҳоло ҳимоя нест': [
    'Не задан — защиты пока нет',
    'Not set — no protection yet',
  ],
  'Иҷозатҳои Android': ['Разрешения Android', 'Android permissions'],
  'Санҷидан': ['Проверить', 'Check'],
  'Ранг ва забони барнома.': [
    'Цвет и язык приложения.',
    'App colour and language.',
  ],
  'Шабона ба чашм осонтар.': [
    'Ночью глазам легче.',
    'Easier on the eyes at night.',
  ],
  'Забони барнома': ['Язык приложения', 'App language'],
  'Ҳоло: {language}': ['Сейчас: {language}', 'Now: {language}'],
  'Версия, навсозӣ ва огоҳиномаҳо.': [
    'Версия, обновления и уведомления.',
    'Version, updates and notifications.',
  ],
  'Дар ин ҷо PIN-и волидайн, иҷозатҳо, забон ва намуди барномаро танзим кунед.':
      [
        'Здесь настраиваются PIN родителя, разрешения, язык и внешний вид приложения.',
        'Here you set the parent PIN, permissions, language and the look of the app.',
      ],
  'Ин телефон бо волидайн пайваст аст. Дар ин ҷо PIN, забон ва намуди барномаро тағйир диҳед.':
      [
        'Этот телефон связан с родителем. Здесь можно изменить PIN, язык и внешний вид.',
        'This phone is linked to a parent. Here you can change the PIN, language and look.',
      ],

  // Auth / role / child setup.
  'Бо почта ва рамзи аккаунти худ ворид шавед.': [
    'Войдите по своей почте и паролю.',
    'Sign in with your email and password.',
  ],
  'Аккаунти нави оила месозед. Баъд интихоб мекунед: волидайн ё фарзанд.': [
    'Создаёте новый семейный аккаунт. Потом выберете: родитель или ребёнок.',
    'You are creating a new family account. Next you choose: parent or child.',
  ],
  'Як бор интихоб мекунед. Баъд NIGOH иҷозатҳои лозимиро қадам ба қадам мепурсад.':
      [
        'Выбор делается один раз. Затем NIGOH пошагово запросит нужные разрешения.',
        'You choose once. NIGOH then asks for the permissions it needs, step by step.',
      ],
  'Телефони ман': ['Мой телефон', 'My phone'],
  'Телефони фарзанд': ['Телефон ребёнка', "The child's phone"],
  'Маълумоти шумо': ['Ваши данные', 'About you'],
  'Танҳо ном, ҷинс ва синну сол — дигар чизе пурсида намешавад.': [
    'Только имя, пол и возраст — больше ничего не спрашиваем.',
    'Just a name, gender and age — nothing else is asked.',
  ],
  'Нигоҳ доштан ва идома': ['Сохранить и продолжить', 'Save and continue'],
  'Қадами навбатӣ: иҷозатҳои Android.': [
    'Следующий шаг: разрешения Android.',
    'Next step: Android permissions.',
  ],

  // Permissions wizard.
  'Иҷозатҳоро як бор медиҳед — баъд NIGOH дар пасзамина кор мекунад. Ҳар қадамро гузаронидан мумкин аст.':
      [
        'Разрешения даются один раз — дальше NIGOH работает в фоне. Любой шаг можно пропустить.',
        'You grant the permissions once — NIGOH then works in the background. Any step can be skipped.',
      ],
  'Иҷозат дода нашуд? Танзимоти Android-ро кушоед': [
    'Разрешение не получено? Откройте настройки Android',
    'Not granted? Open the Android settings',
  ],
  'Дастури қадам ба қадам': ['Пошаговая инструкция', 'Step-by-step guide'],
  'Якчанд иҷозат мондааст': [
    'Осталось несколько разрешений',
    'A few permissions are left',
  ],

  // Shared stat widgets (lib/ui/stat_meter.dart).
  '{value} {unit} аз {max}': [
    '{value} {unit} из {max}',
    '{value} {unit} of {max}',
  ],
  '{value} аз {max}': ['{value} из {max}', '{value} of {max}'],
  'Агар Android иҷозатро бо маҳдудият баста бошад': ['Если Android ограничил это разрешение', 'If Android has restricted this permission'],
  'Тугмаи «App info»-ро пахш кунед — саҳифаи маълумоти NIGOH Family кушода мешавад.': ['Нажмите «О приложении» — откроется страница NIGOH Family.', 'Tap "App info" — the NIGOH Family page opens.'],
  'Дар кунҷи рости боло ⋮ (се нуқта)-ро пахш кунед.': ['Нажмите ⋮ (три точки) в правом верхнем углу.', 'Tap the three dots in the top-right corner.'],
  '«Разрешить ограниченные настройки»-ро интихоб кунед ва бо рамзи телефон тасдиқ намоед.': ['Выберите «Разрешить ограниченные настройки» и подтвердите кодом телефона.', 'Choose "Allow restricted settings" and confirm with your phone lock.'],
  'Ба NIGOH баргардед ва «Иҷозат додан»-ро аз нав пахш кунед.': ['Вернитесь в NIGOH и снова нажмите «Разрешить».', 'Come back to NIGOH and tap "Allow" again.'],
  'Агар дар менюи ⋮ ин банд набошад, аввал як бор «Иҷозат додан»-ро пахш кунед, баъд ин ҷо баргардед.': ['Если в меню нет этого пункта, сначала один раз нажмите «Разрешить», потом вернитесь сюда.', 'If the menu lacks this item, tap "Allow" once first, then come back here.'],
};
