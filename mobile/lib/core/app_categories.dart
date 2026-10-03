// Файл: гурӯҳбандии барномаҳо аз рӯи package name.

import 'models.dart';
import '../l10n/l10n.dart';

/// Ҳолатҳо ё навъҳои имконпазири гурӯҳбандии барномаҳо аз рӯи package name-ро муайян мекунад.
enum AppCategory { games, social, education, video, other }

/// Барои гурӯҳбандии барномаҳо аз рӯи package name property ва helper-ҳои иловагӣ медиҳад.
extension AppCategoryLabel on AppCategory {
  /// Қимати label-ро барои гурӯҳбандии барномаҳо аз рӯи package name нигоҳ медорад.
  String get label => switch (this) {
    AppCategory.games => tr('Бозиҳо'),
    AppCategory.social => tr('Шабакаҳо'),
    AppCategory.education => tr('Маориф'),
    AppCategory.video => tr('Видео'),
    AppCategory.other => tr('Дигар'),
  };

  /// Қимати pluralLower-ро барои гурӯҳбандии барномаҳо аз рӯи package name нигоҳ медорад.
  String get pluralLower => switch (this) {
    AppCategory.games => tr('бозиҳо'),
    AppCategory.social => tr('шабакаҳои иҷтимоӣ'),
    AppCategory.education => tr('барномаҳои таълимӣ'),
    AppCategory.video => tr('барномаҳои видео'),
    AppCategory.other => tr('барномаҳои дигар'),
  };
}

/// classifyApp мантиқи зарурии гурӯҳбандии барномаҳо аз рӯи package name-ро иҷро мекунад.
AppCategory classifyApp(String packageName, [String name = '']) {
  final text = '${packageName.toLowerCase()} ${name.toLowerCase()}';
  /// any мантиқи зарурии гурӯҳбандии барномаҳо аз рӯи package name-ро иҷро мекунад.
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

/// categoryOf мантиқи зарурии гурӯҳбандии барномаҳо аз рӯи package name-ро иҷро мекунад.
AppCategory categoryOf(ChildApp app) => classifyApp(app.packageName, app.name);

/// Қимати studyBlockedCategories-ро барои гурӯҳбандии барномаҳо аз рӯи package name нигоҳ медорад.
const studyBlockedCategories = {
  AppCategory.games,
  AppCategory.social,
  AppCategory.video,
};

/// isEssentialApp иҷро шудани шарти вобастаро муайян мекунад.
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
