import 'models.dart';

/// App categories shared by the parent (filters) and the child (study mode).

enum AppCategory { games, social, education, video, other }

extension AppCategoryLabel on AppCategory {
  /// Chip label.
  String get label => switch (this) {
    AppCategory.games => 'Бозиҳо',
    AppCategory.social => 'Шабакаҳо',
    AppCategory.education => 'Маориф',
    AppCategory.video => 'Видео',
    AppCategory.other => 'Дигар',
  };

  /// Used in «Бастани ҳамаи …».
  String get pluralLower => switch (this) {
    AppCategory.games => 'бозиҳо',
    AppCategory.social => 'шабакаҳои иҷтимоӣ',
    AppCategory.education => 'барномаҳои таълимӣ',
    AppCategory.video => 'барномаҳои видео',
    AppCategory.other => 'барномаҳои дигар',
  };
}

/// Classifies an app by package-name / name keywords. Order matters: video
/// is checked before social so YouTube/TikTok land in «Видео».
AppCategory classifyApp(String packageName, [String name = '']) {
  final text = '${packageName.toLowerCase()} ${name.toLowerCase()}';
  bool any(List<String> keys) => keys.any(text.contains);

  if (any(const [
    'duolingo',
    'school',
    'academy',
    'learn',
    'khan',
    'education',
    '.edu',
    'study',
    'classroom',
    'dictionary',
    'translate',
    'math',
    'photomath',
    'quizlet',
    'brainly',
    'coursera',
    'udemy',
    'wikipedia',
    'books',
    'reader',
    'kundalik',
    'dars',
    'teacher',
    'lingua',
    'english',
  ])) {
    return AppCategory.education;
  }
  if (any(const [
    'youtube',
    'tiktok',
    'musically',
    'zhiliaoapp',
    'likee',
    'netflix',
    'twitch',
    'kinopoisk',
    'ru.ivi.',
    'okko',
    'rutube',
    'vimeo',
    'video',
    'player',
    'mxtech',
    'vlc',
    'disney',
    'primevideo',
    'wink',
    'kino',
  ])) {
    return AppCategory.video;
  }
  if (any(const [
    'game',
    'roblox',
    'minecraft',
    'mojang',
    'pubg',
    'tencent',
    'supercell',
    'freefire',
    'garena',
    'com.king.',
    'candycrush',
    'clash',
    'brawl',
    'miniclip',
    'rovio',
    'gameloft',
    'com.ea.',
    'activision',
    'mihoyo',
    'hoyoverse',
    'standoff',
    'axlebolt',
    'subway',
    'kiloo',
    'unity',
    'playrix',
    'zynga',
    'outfit7',
    'talkingtom',
    'chess',
    'puzzle',
    'arcade',
    'racing',
    'simulator',
    'innersloth',
    'moonactive',
    'voodoo',
    'ketchapp',
  ])) {
    return AppCategory.games;
  }
  if (any(const [
    'telegram',
    'whatsapp',
    'instagram',
    'facebook',
    'snapchat',
    'twitter',
    'com.x.',
    'discord',
    'vkontakte',
    'vk.',
    'odnoklassniki',
    'com.imo.',
    'viber',
    'messenger',
    'threads',
    'pinterest',
    'reddit',
    'wechat',
    'skype',
    'signal',
    'jp.naver.line',
    'kakao',
    'social',
    'chat',
    'tumblr',
    'bereal',
    'clubhouse',
    'tamtam',
    'zoom',
  ])) {
    return AppCategory.social;
  }
  return AppCategory.other;
}

AppCategory categoryOf(ChildApp app) => classifyApp(app.packageName, app.name);

/// Categories closed during «Тамаркузи дарс».
const studyBlockedCategories = {AppCategory.games, AppCategory.social, AppCategory.video};

/// Phone, contacts, SMS, clock, settings and similar system essentials.
/// Study mode and bedtime never block these, so the child can always call.
bool isEssentialApp(String packageName) {
  final p = packageName.toLowerCase();
  const exact = {
    'com.android.dialer',
    'com.google.android.dialer',
    'com.samsung.android.dialer',
    'com.android.contacts',
    'com.samsung.android.app.contacts',
    'com.google.android.contacts',
    'com.android.mms',
    'com.google.android.apps.messaging',
    'com.samsung.android.messaging',
    'com.android.settings',
    'com.sec.android.app.clockpackage',
    'com.google.android.deskclock',
    'com.android.deskclock',
    'com.android.phone',
    'com.samsung.android.incallui',
  };
  return exact.contains(p) || p.contains('dialer') || p.contains('incallui');
}
