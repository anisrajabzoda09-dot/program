// Файл: маҳаллигардонии қисми Android — забони Flutter-ро мехонад ва
// матнҳои экранҳои native, overlay, PIN ва навсозиро медиҳад.

package tj.nigoh.nigoh_family_parent

import android.content.Context

/**
 * Забони интихобшудаи барномаро аз shared_preferences-и Flutter мехонад.
 * Қиматҳои имконпазир 'tg', 'ru', 'en' буда, қимати пешфарз 'tg' аст.
 */
object AppLang {
    const val PREFS = "FlutterSharedPreferences"
    const val KEY = "flutter.nigoh.locale"

    /** Рамзи забони ҷории барномаро аз танзимоти Flutter мехонад. */
    fun of(context: Context): String =
        when (runCatching {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
        }.getOrNull()) {
            "ru" -> "ru"
            "en" -> "en"
            else -> "tg"
        }

    /** Матни мувофиқи [lang]-ро интихоб мекунад; барои қимати ношинос тоҷикӣ медиҳад. */
    fun pick(lang: String, tg: String, ru: String, en: String): String = when (lang) {
        "ru" -> ru
        "en" -> en
        else -> tg
    }

    /** Матнро мувофиқи забони ҷории барнома интихоб мекунад. */
    fun pick(context: Context, tg: String, ru: String, en: String): String = pick(of(context), tg, ru, en)
}

/** Матнҳои маҳаллигардонидашудаи экранҳои native ва навсозиро таъмин мекунад. */
object UiStrings {
    /** Матнро бо забони ҷории барнома интихоб мекунад. */
    private fun t(c: Context, tg: String, ru: String, en: String) = AppLang.pick(c, tg, ru, en)

    // Сабабҳои басташавӣ барои overlay ва Accessibility.
    /** Сабаби бастани мустақими барномаро медиҳад. */
    fun reasonBlocked(c: Context) = t(c,
        "Ин барнома аз ҷониби волидайн маҳкам шудааст",
        "Это приложение заблокировано родителем",
        "This app is blocked by your parent")
    /** Сабаби маҳдудият аз рӯйи ҷадвалро медиҳад. */
    fun reasonSchedule(c: Context) = t(c,
        "Ҳоло вақти маҳдудшудаи барнома аст",
        "Сейчас это приложение недоступно по расписанию",
        "This app is restricted at this time")
    /** Сабаби ба охир расидани лимити рӯзонаро медиҳад. */
    fun reasonLimit(c: Context) = t(c,
        "Лимити вақти имрӯз ба охир расид",
        "Лимит времени на сегодня исчерпан",
        "Today's time limit is used up")
    /** Шарҳи назорати волидайнро бо номи барнома месозад. */
    fun overlayManaged(c: Context, label: String) = t(c,
        "Барномаи «$label» аз тарафи волидайн назорат мешавад.",
        "Приложение «$label» под родительским контролем.",
        "“$label” is managed by your parent.")
    /** Hint-и майдони PIN-и волидайнро медиҳад. */
    fun parentPinHint(c: Context) = t(c, "PIN-и волидайн", "PIN родителя", "Parent PIN")
    /** Матни тугмаи тасдиқи PIN-ро медиҳад. */
    fun confirmPin(c: Context) = t(c, "Тасдиқи PIN", "Подтвердить PIN", "Confirm PIN")
    /** Хабари кӯтоҳи PIN-и нодурустро медиҳад. */
    fun wrongPinShort(c: Context) = t(c, "PIN нодуруст аст", "Неверный PIN", "Incorrect PIN")
    /** Матни гузариш ба экрани асосиро медиҳад. */
    fun toHome(c: Context) = t(c, "Ба экрани асосӣ", "На главный экран", "Go to home screen")
    /** Вазъи фаъол будани муҳофизати барномаҳоро медиҳад. */
    fun protectionActive(c: Context) = t(c,
        "Муҳофизати барномаҳо фаъол аст", "Защита приложений включена", "App protection is on")
    /** Номи channel-и муҳофизати NIGOH-ро медиҳад. */
    fun protectionChannel(c: Context) = t(c, "Муҳофизати NIGOH", "Защита NIGOH", "NIGOH protection")

    // Матнҳои BlockedActivity.
    /** Сарлавҳаи экрани қулфро медиҳад. */
    fun lockTitle(c: Context) = t(c, "🛡  Emergency Lock", "🛡  Экстренная блокировка", "🛡  Emergency Lock")
    /** Имзои NIGOH SHIELD-ро медиҳад. */
    fun shieldCaption(c: Context) = t(c,
        "NIGOH SHIELD • НАЗОРАТИ ВОЛИДАЙН",
        "NIGOH SHIELD • РОДИТЕЛЬСКИЙ КОНТРОЛЬ",
        "NIGOH SHIELD • PARENTAL CONTROL")
    /** Шарҳи кӯтоҳи маҳдудияти дастрасиро медиҳад. */
    fun restrictedSubtitle(c: Context) = t(c,
        "This application is restricted by parental controls",
        "Доступ ограничен родительским контролем",
        "Access is restricted by parental controls")
    /** Номи категорияи фароғатро медиҳад. */
    fun categoryEntertainment(c: Context) = t(c, "Фароғат ва наворҳо", "Развлечения и видео", "Entertainment & video")
    /** Нишони ҳолати басташударо медиҳад. */
    fun blockedBadge(c: Context) = t(c, "МАҲКАМ", "ЗАБЛОКИРОВАНО", "BLOCKED")
    /** Сатри лимити пуршудаи рӯзонаро медиҳад. */
    fun dailyLimitLine(c: Context) = t(c,
        "●  Лимити рӯзона пур шуд  |  1 соат 30 дақ / 1 соат 30 дақ",
        "●  Дневной лимит исчерпан  |  1 ч 30 мин / 1 ч 30 мин",
        "●  Daily limit reached  |  1 h 30 min / 1 h 30 min")
    /** Сатри фаъол будани ҳолати дарсиро медиҳад. */
    fun studyLine(c: Context) = t(c,
        "●  Ҳолати дарсӣ фаъол аст  |  16:00 — 18:00",
        "●  Учебный режим включён  |  16:00 — 18:00",
        "●  Study mode is on  |  16:00 — 18:00")
    /** Нишони вақти то кушодашавиро медиҳад. */
    fun nextUnlock(c: Context) = t(c, "Кушодашавии навбатӣ пас аз:", "Разблокировка через:", "Unlocks in:")
    /** Вақти намунавии кушодашавиро медиҳад. */
    fun tomorrowAt8(c: Context) = t(c, "Пагоҳ соати 08:00", "Завтра в 08:00", "Tomorrow at 08:00")
    /** Матни тугмаи бозгашт ба Home-ро медиҳад. */
    fun backHome(c: Context) = t(c,
        "⌂  Бозгашт ба экрани асосӣ", "⌂  На главный экран", "⌂  Back to home screen")
    /** Матни дархости 15 дақиқаи иловагиро медиҳад. */
    fun askExtraTime(c: Context) = t(c,
        "Дархости вақти иловагӣ (+15 дақ)",
        "Попросить дополнительное время (+15 мин)",
        "Ask for extra time (+15 min)")
    /** Ба фарзанд мефаҳмонад, ки дархост ба волидайн меравад. */
    fun requestGoesToParent(c: Context) = t(c,
        "Пайём барои тасдиқ ба волидайн фиристода мешавад",
        "Запрос будет отправлен родителю на подтверждение",
        "The request will be sent to your parent for approval")
    /** Дастрас будани зангҳои таъҷилиро нишон медиҳад. */
    fun emergencyCalls(c: Context) = t(c,
        "☎  Зангҳои таъҷилӣ ҳамеша дастрасанд (SOS)",
        "☎  Экстренные звонки всегда доступны (SOS)",
        "☎  Emergency calls are always available (SOS)")
    /** Истиснои 112 ва занг ба волидайнро шарҳ медиҳад. */
    fun emergencyCallsNote(c: Context) = t(c,
        "Хидмати 112 ё занг ба падар ва модар маҳдуд намешавад",
        "Звонки в 112 и родителям не ограничиваются",
        "Calls to 112 and to your parents are never restricted")

    // Матнҳои PinVerificationActivity ва device admin.
    /** Сарлавҳаи санҷиши волидайнро медиҳад. */
    fun pinTitle(c: Context) = t(c, "Тасдиқи волидайн", "Подтверждение родителя", "Parent confirmation")
    /** Зарурати PIN барои нест кардани барномаро шарҳ медиҳад. */
    fun pinRequired(c: Context) = t(c,
        "Барои ғайрифаъол ва нест кардани NIGOH Family ворид намудани рамзи PIN-и волидайн ҳатмист.",
        "Чтобы отключить и удалить NIGOH Family, нужно ввести PIN-код родителя.",
        "To disable and remove NIGOH Family, the parent's PIN is required.")
    /** Hint-и PIN-и чоррақамаро медиҳад. */
    fun pinHint4(c: Context) = t(c, "PIN-и 4-рақама", "4-значный PIN", "4-digit PIN")
    /** Матни умумии тугмаи тасдиқро медиҳад. */
    fun confirm(c: Context) = t(c, "Тасдиқ кардан", "Подтвердить", "Confirm")
    /** Хабари басташавии PIN-ро бо сонияҳои боқимонда месозад. */
    fun pinLocked(c: Context, seconds: Long) = t(c,
        "Кӯшишҳо баста шуданд. Баъд аз $seconds сония дубора кӯшиш кунед.",
        "Слишком много попыток. Повторите через $seconds с.",
        "Too many attempts. Try again in $seconds s.")
    /** Набудани PIN-и танзимшударо хабар медиҳад. */
    fun pinNotSet(c: Context) = t(c,
        "Аввал PIN-и волидайнро дар барнома гузоред.",
        "Сначала задайте PIN родителя в приложении.",
        "Set the parent PIN in the app first.")
    /** Хабари PIN-и нодурустро медиҳад. */
    fun pinWrong(c: Context) = t(c, "Рамзи PIN нодуруст аст", "Неверный PIN-код", "Incorrect PIN")

    // Матнҳои AppUpdater.
    /** Насб нашудани навсозиро хабар медиҳад. */
    fun updateNotInstalled(c: Context) = t(c,
        "Навсозӣ насб нашуд", "Не удалось установить обновление", "The update was not installed")
    /** Хатои серверро бо HTTP code месозад. */
    fun updateServerError(c: Context, code: Int) = t(c,
        "Сервер навсозиро надод ($code)",
        "Сервер не отдал обновление ($code)",
        "The server did not provide the update ($code)")
    /** Нопурра боргирӣ шудани APK-ро хабар медиҳад. */
    fun updateIncomplete(c: Context) = t(c,
        "Файли навсозӣ нопурра боргирӣ шуд",
        "Файл обновления загружен не полностью",
        "The update file was not fully downloaded")
    /** Вайрон будани файли навсозиро хабар медиҳад. */
    fun updateBroken(c: Context) = t(c,
        "Файли навсозӣ вайрон аст", "Файл обновления повреждён", "The update file is damaged")
    /** Ба package-и NIGOH тааллуқ надоштани APK-ро хабар медиҳад. */
    fun updateWrongPackage(c: Context) = t(c,
        "Ин файл навсозии NIGOH Family нест",
        "Этот файл не является обновлением NIGOH Family",
        "This file is not a NIGOH Family update")
    /** Навтар набудани версияи пешниҳодшударо хабар медиҳад. */
    fun updateAlreadyLatest(c: Context) = t(c,
        "Шумо аллакай версияи охиринро доред", "У вас уже последняя версия", "You already have the latest version")
    /** Мувофиқ набудани имзои APK-ро хабар медиҳад. */
    fun updateBadSignature(c: Context) = t(c,
        "Имзои файл бо барнома мувофиқ нест — насб манъ шуд",
        "Подпись файла не совпадает с приложением — установка запрещена",
        "The file signature does not match the app — installation blocked")
    /** Аз корбар тасдиқи насбро дар равзанаи Android мепурсад. */
    fun updateConfirmPrompt(c: Context) = t(c,
        "Дар равзанаи Android «Навсозӣ»-ро пахш кунед",
        "Нажмите «Обновить» в окне Android",
        "Tap “Update” in the Android dialog")
    /** Бекор шудани навсозиро хабар медиҳад. */
    fun updateCancelled(c: Context) = t(c,
        "Навсозӣ бекор карда шуд", "Обновление отменено", "The update was cancelled")

    /** Ноком шудани кори огоҳиномаҳоро хабар медиҳад. */
    fun notifyFailed(c: Context) = t(c,
        "Огоҳиномаҳо кор накарданд.", "Уведомления не сработали.", "Notifications failed.")
}
