// Файл: матнҳои маҳаллигардонидашудаи огоҳиномаҳое, ки NotifyService месозад.

package tj.nigoh.nigoh_family_parent

/**
 * Матни огоҳиномаҳоро аз маълумоти event бо забони интихобшудаи [AppLang] месозад.
 * Матни худи корбар, SOS ва сабабҳо тарҷума намешаванд.
 */
class NotifyStrings(val lang: String) {
    /** Матни мувофиқро барои забони интихобшуда бармегардонад. */
    private fun t(tg: String, ru: String, en: String) = AppLang.pick(lang, tg, ru, en)

    // Матнҳои foreground service.
    val serviceTitle get() = t("NIGOH Family фаъол аст", "NIGOH Family работает", "NIGOH Family is active")
    val serviceText get() = t(
        "Паёмҳо, SOS ва зангҳо фавран мерасанд",
        "Сообщения, SOS и звонки приходят сразу",
        "Messages, SOS and calls arrive instantly")

    // Ном ва тавсифи channel-ҳо.
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

    // Матни action-ҳои огоҳинома.
    val accept get() = t("Қабул", "Принять", "Accept")
    val decline get() = t("Рад", "Отклонить", "Decline")
    val silence get() = t("Хомӯш кардан", "Выключить", "Turn off")

    // Матни event-ҳои оилавӣ.
    val voiceCall get() = t("Занги овозӣ", "Голосовой звонок", "Voice call")
    val parent get() = t("Волидайн", "Родитель", "Parent")
    val missedCall get() = t("Занги ҷавобнадода", "Пропущенный звонок", "Missed call")

    /** Сарлавҳаи SOS-ро бо номи фарзанд месозад. */
    fun sosTitle(child: String) = "SOS — $child"
    /** Матни пешфарзи SOS-ро барои фарзанди маълум ё номаълум месозад. */
    fun sosDefault(child: String?) = if (child == null) t(
        "Фарзанд ёрӣ мехоҳад. Ҷойгиршавиро бинед.",
        "Ребёнку нужна помощь. Посмотрите, где он.",
        "Your child needs help. Check their location.")
    else t(
        "$child ёрӣ мехоҳад. Ҷойгиршавиро бинед.",
        "$child нужна помощь. Посмотрите местоположение.",
        "$child needs help. Check their location.")

    /** Сарлавҳаи дархости вақти иловагиро бо барнома ва дақиқаҳо месозад. */
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
    /** Матни иҷозати вақти иловагиро месозад. */
    fun approvedBody(app: String, minutes: Int) = t("$app: +$minutes дақ", "$app: +$minutes мин", "$app: +$minutes min")

    /** Сарлавҳаи огоҳии батареяи пастро бо фоиз месозад. */
    fun lowBatteryTitle(child: String, battery: Int) = t(
        "$child: батарея $battery%", "$child: батарея $battery%", "$child: battery $battery%")
    val lowBatteryBody get() = t(
        "Телефони фарзанд ба зудӣ хомӯш мешавад.",
        "Телефон ребёнка скоро выключится.",
        "Your child's phone will turn off soon.")

    /** Сарлавҳаи қатъ шудани пайвасти фарзандро месозад. */
    fun offlineTitle(child: String) = t("$child офлайн аст", "$child не в сети", "$child is offline")
    val offlineBody get() = t(
        "Телефони фарзанд 20 дақиқа боз ба интернет пайваст нашудааст.",
        "Телефон ребёнка уже 20 минут не подключён к интернету.",
        "Your child's phone has been offline for 20 minutes.")

    /** Сарлавҳаи огоҳӣ, вақте филтри сайтҳо дар телефони фарзанд хомӯш шуд. */
    fun webFilterOffTitle(child: String) = t(
        "$child: филтри сайтҳо хомӯш шуд",
        "$child: фильтр сайтов выключен",
        "$child: site filter turned off")
    val webFilterOffBody get() = t(
        "Дар телефони фарзанд VPN-и филтр қатъ шуд. Барномаро дар он кушоед.",
        "На телефоне ребёнка остановлен VPN фильтра. Откройте на нём приложение.",
        "The filter VPN was stopped on your child's phone. Open the app there.")

    /** Сарлавҳаи огоҳӣ, вақте фарзанд ба ҷойи бехатар расид. */
    fun placeArriveTitle(child: String, place: String) = t(
        "$child ба «$place» расид",
        "$child: прибыл(а) в «$place»",
        "$child arrived at «$place»")

    /** Сарлавҳаи огоҳӣ, вақте фарзанд аз ҷойи бехатар баромад. */
    fun placeLeaveTitle(child: String, place: String) = t(
        "$child аз «$place» баромад",
        "$child: покинул(а) «$place»",
        "$child left «$place»")

    /** Сарлавҳаи насби барномаи навро месозад. */
    fun newAppTitle(child: String) = t(
        "$child барномаи нав насб кард",
        "$child: установлено новое приложение",
        "$child installed a new app")
}
