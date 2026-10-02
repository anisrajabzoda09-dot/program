package tj.nigoh.nigoh_family_parent

import android.content.Context

/**
 * The in-app language chosen in Flutter (not the system locale).
 * Flutter's shared_preferences stores 'nigoh.locale' as "flutter.nigoh.locale"
 * in the "FlutterSharedPreferences" file: 'tg' | 'ru' | 'en', missing = 'tg'.
 */
object AppLang {
    const val PREFS = "FlutterSharedPreferences"
    const val KEY = "flutter.nigoh.locale"

    fun of(context: Context): String =
        when (runCatching {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
        }.getOrNull()) {
            "ru" -> "ru"
            "en" -> "en"
            else -> "tg"
        }

    fun pick(lang: String, tg: String, ru: String, en: String): String = when (lang) {
        "ru" -> ru
        "en" -> en
        else -> tg
    }

    fun pick(context: Context, tg: String, ru: String, en: String): String = pick(of(context), tg, ru, en)
}

/** Texts of the native screens (BlockedActivity, PIN check, block overlay, updater). */
object UiStrings {
    private fun t(c: Context, tg: String, ru: String, en: String) = AppLang.pick(c, tg, ru, en)

    // Block reasons (overlay + accessibility).
    fun reasonBlocked(c: Context) = t(c,
        "Ин барнома аз ҷониби волидайн маҳкам шудааст",
        "Это приложение заблокировано родителем",
        "This app is blocked by your parent")
    fun reasonSchedule(c: Context) = t(c,
        "Ҳоло вақти маҳдудшудаи барнома аст",
        "Сейчас это приложение недоступно по расписанию",
        "This app is restricted at this time")
    fun reasonLimit(c: Context) = t(c,
        "Лимити вақти имрӯз ба охир расид",
        "Лимит времени на сегодня исчерпан",
        "Today's time limit is used up")
    fun overlayManaged(c: Context, label: String) = t(c,
        "Барномаи «$label» аз тарафи волидайн назорат мешавад.",
        "Приложение «$label» под родительским контролем.",
        "“$label” is managed by your parent.")
    fun parentPinHint(c: Context) = t(c, "PIN-и волидайн", "PIN родителя", "Parent PIN")
    fun confirmPin(c: Context) = t(c, "Тасдиқи PIN", "Подтвердить PIN", "Confirm PIN")
    fun wrongPinShort(c: Context) = t(c, "PIN нодуруст аст", "Неверный PIN", "Incorrect PIN")
    fun toHome(c: Context) = t(c, "Ба экрани асосӣ", "На главный экран", "Go to home screen")
    fun protectionActive(c: Context) = t(c,
        "Муҳофизати барномаҳо фаъол аст", "Защита приложений включена", "App protection is on")
    fun protectionChannel(c: Context) = t(c, "Муҳофизати NIGOH", "Защита NIGOH", "NIGOH protection")

    // BlockedActivity.
    fun lockTitle(c: Context) = t(c, "🛡  Emergency Lock", "🛡  Экстренная блокировка", "🛡  Emergency Lock")
    fun shieldCaption(c: Context) = t(c,
        "NIGOH SHIELD • НАЗОРАТИ ВОЛИДАЙН",
        "NIGOH SHIELD • РОДИТЕЛЬСКИЙ КОНТРОЛЬ",
        "NIGOH SHIELD • PARENTAL CONTROL")
    fun restrictedSubtitle(c: Context) = t(c,
        "This application is restricted by parental controls",
        "Доступ ограничен родительским контролем",
        "Access is restricted by parental controls")
    fun categoryEntertainment(c: Context) = t(c, "Фароғат ва наворҳо", "Развлечения и видео", "Entertainment & video")
    fun blockedBadge(c: Context) = t(c, "МАҲКАМ", "ЗАБЛОКИРОВАНО", "BLOCKED")
    fun dailyLimitLine(c: Context) = t(c,
        "●  Лимити рӯзона пур шуд  |  1 соат 30 дақ / 1 соат 30 дақ",
        "●  Дневной лимит исчерпан  |  1 ч 30 мин / 1 ч 30 мин",
        "●  Daily limit reached  |  1 h 30 min / 1 h 30 min")
    fun studyLine(c: Context) = t(c,
        "●  Ҳолати дарсӣ фаъол аст  |  16:00 — 18:00",
        "●  Учебный режим включён  |  16:00 — 18:00",
        "●  Study mode is on  |  16:00 — 18:00")
    fun nextUnlock(c: Context) = t(c, "Кушодашавии навбатӣ пас аз:", "Разблокировка через:", "Unlocks in:")
    fun tomorrowAt8(c: Context) = t(c, "Пагоҳ соати 08:00", "Завтра в 08:00", "Tomorrow at 08:00")
    fun backHome(c: Context) = t(c,
        "⌂  Бозгашт ба экрани асосӣ", "⌂  На главный экран", "⌂  Back to home screen")
    fun askExtraTime(c: Context) = t(c,
        "Дархости вақти иловагӣ (+15 дақ)",
        "Попросить дополнительное время (+15 мин)",
        "Ask for extra time (+15 min)")
    fun requestGoesToParent(c: Context) = t(c,
        "Пайём барои тасдиқ ба волидайн фиристода мешавад",
        "Запрос будет отправлен родителю на подтверждение",
        "The request will be sent to your parent for approval")
    fun emergencyCalls(c: Context) = t(c,
        "☎  Зангҳои таъҷилӣ ҳамеша дастрасанд (SOS)",
        "☎  Экстренные звонки всегда доступны (SOS)",
        "☎  Emergency calls are always available (SOS)")
    fun emergencyCallsNote(c: Context) = t(c,
        "Хидмати 112 ё занг ба падар ва модар маҳдуд намешавад",
        "Звонки в 112 и родителям не ограничиваются",
        "Calls to 112 and to your parents are never restricted")

    // PinVerificationActivity / device admin.
    fun pinTitle(c: Context) = t(c, "Тасдиқи волидайн", "Подтверждение родителя", "Parent confirmation")
    fun pinRequired(c: Context) = t(c,
        "Барои ғайрифаъол ва нест кардани NIGOH Family ворид намудани рамзи PIN-и волидайн ҳатмист.",
        "Чтобы отключить и удалить NIGOH Family, нужно ввести PIN-код родителя.",
        "To disable and remove NIGOH Family, the parent's PIN is required.")
    fun pinHint4(c: Context) = t(c, "PIN-и 4-рақама", "4-значный PIN", "4-digit PIN")
    fun confirm(c: Context) = t(c, "Тасдиқ кардан", "Подтвердить", "Confirm")
    fun pinLocked(c: Context, seconds: Long) = t(c,
        "Кӯшишҳо баста шуданд. Баъд аз $seconds сония дубора кӯшиш кунед.",
        "Слишком много попыток. Повторите через $seconds с.",
        "Too many attempts. Try again in $seconds s.")
    fun pinNotSet(c: Context) = t(c,
        "Аввал PIN-и волидайнро дар барнома гузоред.",
        "Сначала задайте PIN родителя в приложении.",
        "Set the parent PIN in the app first.")
    fun pinWrong(c: Context) = t(c, "Рамзи PIN нодуруст аст", "Неверный PIN-код", "Incorrect PIN")

    // AppUpdater.
    fun updateNotInstalled(c: Context) = t(c,
        "Навсозӣ насб нашуд", "Не удалось установить обновление", "The update was not installed")
    fun updateServerError(c: Context, code: Int) = t(c,
        "Сервер навсозиро надод ($code)",
        "Сервер не отдал обновление ($code)",
        "The server did not provide the update ($code)")
    fun updateIncomplete(c: Context) = t(c,
        "Файли навсозӣ нопурра боргирӣ шуд",
        "Файл обновления загружен не полностью",
        "The update file was not fully downloaded")
    fun updateBroken(c: Context) = t(c,
        "Файли навсозӣ вайрон аст", "Файл обновления повреждён", "The update file is damaged")
    fun updateWrongPackage(c: Context) = t(c,
        "Ин файл навсозии NIGOH Family нест",
        "Этот файл не является обновлением NIGOH Family",
        "This file is not a NIGOH Family update")
    fun updateAlreadyLatest(c: Context) = t(c,
        "Шумо аллакай версияи охиринро доред", "У вас уже последняя версия", "You already have the latest version")
    fun updateBadSignature(c: Context) = t(c,
        "Имзои файл бо барнома мувофиқ нест — насб манъ шуд",
        "Подпись файла не совпадает с приложением — установка запрещена",
        "The file signature does not match the app — installation blocked")
    fun updateConfirmPrompt(c: Context) = t(c,
        "Дар равзанаи Android «Навсозӣ»-ро пахш кунед",
        "Нажмите «Обновить» в окне Android",
        "Tap “Update” in the Android dialog")
    fun updateCancelled(c: Context) = t(c,
        "Навсозӣ бекор карда шуд", "Обновление отменено", "The update was cancelled")

    fun notifyFailed(c: Context) = t(c,
        "Огоҳиномаҳо кор накарданд.", "Уведомления не сработали.", "Notifications failed.")
}
