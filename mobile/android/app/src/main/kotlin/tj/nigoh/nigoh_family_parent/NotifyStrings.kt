// Localized notification texts built natively by NotifyService.

package tj.nigoh.nigoh_family_parent

/**
 * Notification texts in the in-app language ([AppLang]). Built from the
 * structured event data, so the phone's language decides, not the server's
 * Tajik title/body. User content (chat text, SOS text, reasons) is never translated.
 */
class NotifyStrings(val lang: String) {
    /** Picks the text for this object's language. */
    private fun t(tg: String, ru: String, en: String) = AppLang.pick(lang, tg, ru, en)

    // Foreground service.
    val serviceTitle get() = t("NIGOH Family фаъол аст", "NIGOH Family работает", "NIGOH Family is active")
    val serviceText get() = t(
        "Паёмҳо, SOS ва зангҳо фавран мерасанд",
        "Сообщения, SOS и звонки приходят сразу",
        "Messages, SOS and calls arrive instantly")

    // Channels.
    val chService get() = t("Хизмати огоҳиномаҳо", "Служба уведомлений", "Notification service")
    val chMessages get() = t("Паёмҳо", "Сообщения", "Messages")
    val chFamily get() = t("Оила", "Семья", "Family")
    val chFamilyDesc get() = t(
        "Дархостҳои вақт, батарея, барномаҳои нав, зангҳои ҷавобнадода",
        "Запросы времени, батарея, новые приложения, пропущенные звонки",
        "Time requests, battery, new apps, missed calls")
    val chSosDesc get() = t("Ҳушдори SOS аз фарзанд", "Сигнал SOS от ребёнка", "SOS alert from your child")
    val chCalls get() = t("Зангҳо", "Звонки", "Calls")
    val chCallsDesc get() = t("Зангҳои воридшаванда", "Входящие звонки", "Incoming calls")

    // Actions.
    val accept get() = t("Қабул", "Принять", "Accept")
    val decline get() = t("Рад", "Отклонить", "Decline")
    val silence get() = t("Хомӯш кардан", "Выключить", "Turn off")

    // Events.
    val voiceCall get() = t("Занги овозӣ", "Голосовой звонок", "Voice call")
    val parent get() = t("Волидайн", "Родитель", "Parent")
    val missedCall get() = t("Занги ҷавобнадода", "Пропущенный звонок", "Missed call")

    fun sosTitle(child: String) = "SOS — $child"
    fun sosDefault(child: String?) = if (child == null) t(
        "Фарзанд ёрӣ мехоҳад. Ҷойгиршавиро бинед.",
        "Ребёнку нужна помощь. Посмотрите, где он.",
        "Your child needs help. Check their location.")
    else t(
        "$child ёрӣ мехоҳад. Ҷойгиршавиро бинед.",
        "$child нужна помощь. Посмотрите местоположение.",
        "$child needs help. Check their location.")

    fun timeRequestTitle(child: String, minutes: Int, app: String) = t(
        "$child: +$minutes дақ барои $app",
        "$child: +$minutes мин для $app",
        "$child: +$minutes min for $app")
    val timeRequestDefault get() = t(
        "Фарзанд вақти иловагӣ мепурсад.",
        "Ребёнок просит дополнительное время.",
        "Your child is asking for extra time.")

    val approved get() = t("Иҷозат дода шуд", "Разрешено", "Request approved")
    val denied get() = t("Дархост рад шуд", "Запрос отклонён", "Request declined")
    fun approvedBody(app: String, minutes: Int) = t("$app: +$minutes дақ", "$app: +$minutes мин", "$app: +$minutes min")

    fun lowBatteryTitle(child: String, battery: Int) = t(
        "$child: батарея $battery%", "$child: батарея $battery%", "$child: battery $battery%")
    val lowBatteryBody get() = t(
        "Телефони фарзанд ба зудӣ хомӯш мешавад.",
        "Телефон ребёнка скоро выключится.",
        "Your child's phone will turn off soon.")

    fun offlineTitle(child: String) = t("$child офлайн аст", "$child не в сети", "$child is offline")
    val offlineBody get() = t(
        "Телефони фарзанд 20 дақиқа боз ба интернет пайваст нашудааст.",
        "Телефон ребёнка уже 20 минут не подключён к интернету.",
        "Your child's phone has been offline for 20 minutes.")

    fun newAppTitle(child: String) = t(
        "$child барномаи нав насб кард",
        "$child: установлено новое приложение",
        "$child installed a new app")
}
