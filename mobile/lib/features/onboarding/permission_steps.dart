// Permission-wizard model and Android actions: the list of steps per role,
// the copy for each step, reading their status and opening the right system
// dialog or settings screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../core/notify_bridge.dart';
import '../../ui/nigoh_design.dart';
import '../../l10n/l10n.dart';

/// One permission page of the wizard.
enum WizardStepId {
  location,
  notifications,
  usage,
  overlay,
  accessibility,
  deviceAdmin,
  microphone,
  battery,
  fullScreen,

  /// Parent: «display over other apps», so incoming calls and SOS open
  /// full-screen even while the phone is in use.
  callOverlay,
  camera,
}

/// Which part of a step is shown. Only location has two parts: first
/// «while in use», then «always».
enum StepStage { main, always }

/// Steps for each role, in order.
List<WizardStepId> wizardStepsFor({required bool childMode}) => childMode
    ? const [
        WizardStepId.location,
        WizardStepId.notifications,
        WizardStepId.usage,
        WizardStepId.overlay,
        WizardStepId.accessibility,
        WizardStepId.deviceAdmin,
        WizardStepId.microphone,
        WizardStepId.battery,
      ]
    : const [
        WizardStepId.notifications,
        WizardStepId.fullScreen,
        WizardStepId.callOverlay,
        WizardStepId.camera,
        WizardStepId.microphone,
        WizardStepId.battery,
      ];

/// Current state of one step, read from Android.
class StepStatus {
  const StepStatus({
    required this.granted,
    this.blocked = false,
    this.stage = StepStage.main,
    this.gpsOff = false,
    this.missingPrerequisites = false,
  });

  final bool granted;

  /// Android will not show its dialog again (permanently denied /
  /// restricted): only the settings screen can help.
  final bool blocked;
  final StepStage stage;

  /// Location step: the GPS / location service is switched off.
  final bool gpsOff;

  /// Accessibility step: usage access or overlay is still missing, so the
  /// native opener shows those screens first.
  final bool missingPrerequisites;
}

/// Thin wrapper over permission_handler, the native device channel and the
/// notification bridge, so the wizard has a single place that talks to
/// Android (and tests can mock the platform channels underneath).
class WizardPlatform {
  const WizardPlatform();

  static const device = MethodChannel('tj.nigoh/device_control');

  /// Native protection/permission flags from `getProtectionStatus`.
  Future<Map<String, dynamic>> protection() async =>
      await device.invokeMapMethod<String, dynamic>('getProtectionStatus') ??
      const {};

  /// Current status of a runtime permission.
  Future<ph.PermissionStatus> status(ph.Permission permission) =>
      permission.status;

  /// Shows Android's dialog for a runtime permission.
  Future<ph.PermissionStatus> request(ph.Permission permission) =>
      permission.request();

  /// Whether the phone's location service (GPS) is switched on.
  Future<bool> locationServiceEnabled() async =>
      await ph.Permission.location.serviceStatus == ph.ServiceStatus.enabled;

  /// Opens the system location (GPS) settings.
  Future<void> openLocationSettings() async {
    final opened = await Geolocator.openLocationSettings();
    if (!opened) throw WizardException(tr('Танзимоти GPS кушода нашуд.'));
  }

  /// Opens this app's page in Android settings.
  Future<void> openAppSettings() async {
    final opened = await ph.openAppSettings();
    if (!opened) {
      throw WizardException(
        tr(
          'Танзимоти барнома кушода нашуд. Худатон кушоед: '
          'Танзимот → Барномаҳо → NIGOH Family.',
        ),
      );
    }
  }

  /// Calls a no-argument method on the native device channel.
  Future<void> invoke(String method) => device.invokeMethod<Object?>(method);

  /// Notification permissions from the native NotifyService bridge.
  Future<NotifyPermissions> notifyStatus() async {
    final status = await NotifyBridge.permissionStatus();
    if (status == null) {
      throw WizardException(
        NotifyBridge.lastError.value ?? tr('Ҳолати огоҳиномаҳо маълум нашуд.'),
      );
    }
    return status;
  }

  /// Opens Android's full-screen-notification setting for this app.
  Future<void> openFullScreenSettings() async {
    NotifyBridge.lastError.value = null;
    await NotifyBridge.openFullScreenSettings();
    final error = NotifyBridge.lastError.value;
    if (error != null) throw WizardException(error);
  }
}

/// A user-facing (Tajik) error from the wizard.
class WizardException implements Exception {
  const WizardException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Turns any error into a short Tajik sentence for the UI.
String wizardErrorText(Object error) {
  if (error is WizardException) return error.message;
  if (error is MissingPluginException) {
    return tr('Ин танзимот дар ин дастгоҳ дастрас нест.');
  }
  if (error is PlatformException) {
    return error.message ??
        tr('Android хато дод ({code}).', {'code': error.code});
  }
  return tr('Хато: {error}', {'error': error});
}

/// Static copy and actions of one step.
class WizardStep {
  const WizardStep({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.reason,
    required this.help,
    required this.summaryTitle,
  });

  final WizardStepId id;
  final IconData icon;
  final Color color;
  final String title;
  final String reason;
  final List<String> help;
  final String summaryTitle;

  /// Copy for the «Ҳамеша» part of the location step.
  static WizardStep get locationAlways => WizardStep(
    id: WizardStepId.location,
    icon: Icons.share_location_rounded,
    color: NigohDesign.blue,
    title: tr('Ҷойгиршавӣ — «Ҳамеша»'),
    reason: tr(
      'То волидайн ҷойи шуморо ҳатто ҳангоми баста будани барнома бинанд, '
      'дар саҳифаи навбатӣ «Ҳамеша иҷозат додан»-ро интихоб кунед.',
    ),
    help: [
      tr('«Иҷозат додан»-ро пахш кунед — саҳифаи «Ҷойгиршавӣ» кушода мешавад.'),
      tr(
        '«Ҳамеша иҷозат додан» (Разрешить в любом режиме / Allow all the time)-ро интихоб кунед.',
      ),
      tr('Бо тугмаи «Бозгашт» ба NIGOH баргардед.'),
    ],
    summaryTitle: tr('Ҷойгиршавӣ'),
  );

  /// Copy (icon, title, reason, tips) for the step [id].
  static WizardStep of(WizardStepId id) => switch (id) {
    WizardStepId.location => WizardStep(
      id: WizardStepId.location,
      icon: Icons.location_on_rounded,
      color: NigohDesign.blue,
      title: tr('Ҷойгиршавӣ'),
      reason: tr(
        'Волидайн дар харита мебинанд, ки шумо дар куҷоед. '
        'Ин дар ҳолати SOS хеле муҳим аст.',
      ),
      help: [
        tr('«Иҷозат додан»-ро пахш кунед.'),
        tr(
          'Дар равзана «Ҳангоми истифодаи барнома» (При использовании приложения)-ро интихоб кунед.',
        ),
        tr(
          'Агар равзана набарояд: Настройки → Приложения → NIGOH Family → Разрешения → Местоположение.',
        ),
        tr('GPS (Местоположение) дар панели болоии телефон бояд фаъол бошад.'),
      ],
      summaryTitle: tr('Ҷойгиршавӣ'),
    ),
    WizardStepId.notifications => WizardStep(
      id: WizardStepId.notifications,
      icon: Icons.notifications_active_rounded,
      color: NigohDesign.mint,
      title: tr('Огоҳиномаҳо'),
      reason: tr(
        'Паёмҳо, зангҳо ва ҳушдорҳои оила фавран меоянд, '
        'ҳатто вақте ки барнома баста аст.',
      ),
      help: [
        tr('«Иҷозат додан»-ро пахш кунед ва «Разрешить»-ро интихоб кунед.'),
        tr(
          'Агар равзана набарояд: Настройки → Приложения → NIGOH Family → Уведомления.',
        ),
        tr('«Показывать уведомления»-ро фаъол кунед.'),
      ],
      summaryTitle: tr('Огоҳиномаҳо'),
    ),
    WizardStepId.usage => WizardStep(
      id: WizardStepId.usage,
      icon: Icons.bar_chart_rounded,
      color: NigohDesign.violet,
      title: tr('Дастрасӣ ба истифода'),
      reason: tr(
        'NIGOH вақти истифодаи ҳар барномаро ҳисоб мекунад, '
        'то маҳдудиятҳои волидайн кор кунанд.',
      ),
      help: [
        tr(
          '«Иҷозат додан»-ро пахш кунед — рӯйхати «Доступ к истории использования» кушода мешавад.',
        ),
        tr('NIGOH Family-ро ёбед ва пахш кунед.'),
        tr('«Разрешить доступ к истории использования»-ро фаъол кунед.'),
        tr('Бо тугмаи «Бозгашт» ба NIGOH баргардед.'),
      ],
      summaryTitle: tr('Дастрасӣ ба истифода'),
    ),
    WizardStepId.overlay => WizardStep(
      id: WizardStepId.overlay,
      icon: Icons.layers_rounded,
      color: NigohDesign.amber,
      title: tr('Намоиш болои барномаҳо'),
      reason: tr(
        'Вақте ки барнома маҳкам аст, NIGOH экрани муҳофизатро '
        'болои он нишон медиҳад.',
      ),
      help: [
        tr(
          '«Иҷозат додан»-ро пахш кунед — саҳифаи «Поверх других приложений» кушода мешавад.',
        ),
        tr('Агар рӯйхат бошад, NIGOH Family-ро интихоб кунед.'),
        tr('«Разрешить показ поверх других приложений»-ро фаъол кунед.'),
        tr('Бо тугмаи «Бозгашт» ба NIGOH баргардед.'),
      ],
      summaryTitle: tr('Намоиш болои барномаҳо'),
    ),
    WizardStepId.accessibility => WizardStep(
      id: WizardStepId.accessibility,
      icon: Icons.accessibility_new_rounded,
      color: NigohDesign.pink,
      title: tr('Специальные возможности'),
      reason: tr(
        'Ин хизмат барномаи маҳкамшударо фавран мебандад. '
        'NIGOH матн ва паролҳои шуморо намехонад.',
      ),
      help: [
        tr(
          '«Иҷозат додан»-ро пахш кунед — «Специальные возможности» кушода мешавад.',
        ),
        tr(
          '«Установленные приложения» (ё «Скачанные приложения») → NIGOH Family-ро кушоед.',
        ),
        tr('Хизматро фаъол кунед ва «Разрешить»-ро пахш кунед.'),
        tr(
          'Агар «Ограниченная настройка» ё «Доступ запрещен» барояд (Android 13+): '
          'Настройки → Приложения → NIGOH Family → ⋮ (се нуқта дар боло) → '
          '«Разрешить ограниченные настройки». Баъд аз қадами 1 такрор кунед.',
        ),
        tr(
          'Дар баъзе Samsung (One UI) банди ⋮ танҳо баъд аз як бор кӯшиш кардан '
          'ва дидани «Доступ запрещен» пайдо мешавад — аввал як бор кӯшиш кунед.',
        ),
        tr(
          'Дар Samsung, агар боз ҳам нашавад: Настройки → Безопасность и '
          'конфиденциальность → «Автоблокировка» (Auto Blocker)-ро хомӯш кунед.',
        ),
      ],
      summaryTitle: tr('Специальные возможности'),
    ),
    WizardStepId.deviceAdmin => WizardStep(
      id: WizardStepId.deviceAdmin,
      icon: Icons.admin_panel_settings_rounded,
      color: NigohDesign.coral,
      title: tr('Ҳимоя аз нест кардан'),
      reason: tr(
        'NIGOH-ро бе PIN-и волидайн нест кардан мумкин намешавад. '
        'Ин ҳимояи оила аст.',
      ),
      help: [
        tr(
          '«Иҷозат додан»-ро пахш кунед — саҳифаи «Администратор устройства» кушода мешавад.',
        ),
        tr(
          'Ба поён ҳаракат диҳед ва «Активировать» (Фаъол кардан)-ро пахш кунед.',
        ),
        tr(
          'Агар саҳифа кушода нашавад: Настройки → Безопасность → '
          'Администраторы устройства → NIGOH Family.',
        ),
      ],
      summaryTitle: tr('Ҳимоя аз нест кардан'),
    ),
    WizardStepId.microphone => WizardStep(
      id: WizardStepId.microphone,
      icon: Icons.mic_rounded,
      color: NigohDesign.sky,
      title: tr('Микрофон'),
      reason: tr('Барои зангҳои овозӣ байни волидайн ва фарзанд лозим аст.'),
      help: [
        tr('«Иҷозат додан»-ро пахш кунед ва «Разрешить»-ро интихоб кунед.'),
        tr(
          'Агар равзана набарояд: Настройки → Приложения → NIGOH Family → '
          'Разрешения → Микрофон → «Разрешить».',
        ),
      ],
      summaryTitle: tr('Микрофон'),
    ),
    WizardStepId.battery => WizardStep(
      id: WizardStepId.battery,
      icon: Icons.battery_charging_full_rounded,
      color: NigohDesign.mint,
      title: tr('Батарея'),
      reason: tr(
        'Android барномаро барои сарфаи батарея қатъ накунад, '
        'то ҷойгиршавӣ ва огоҳиномаҳо дар пасзамина кор кунанд.',
      ),
      help: [
        tr(
          '«Иҷозат додан»-ро пахш кунед ва дар равзана «Разрешить»-ро интихоб кунед.',
        ),
        tr(
          'Агар равзана набарояд: Настройки → Приложения → NIGOH Family → '
          'Батарея → «Без ограничений» (Не оптимизировать).',
        ),
        tr('Дар Samsung: инчунин NIGOH-ро аз «Спящие приложения» хориҷ кунед.'),
      ],
      summaryTitle: tr('Батарея'),
    ),
    WizardStepId.fullScreen => WizardStep(
      id: WizardStepId.fullScreen,
      icon: Icons.fullscreen_rounded,
      color: NigohDesign.violet,
      title: tr('Экрани пурра'),
      reason: tr(
        'Ҳушдори SOS ва зангҳо ҳатто дар экрани қулфшуда '
        'дар тамоми экран намоён мешаванд.',
      ),
      help: [
        tr(
          '«Иҷозат додан»-ро пахш кунед — «Полноэкранные уведомления» кушода мешавад.',
        ),
        tr('NIGOH Family-ро фаъол кунед.'),
        tr('Бо тугмаи «Бозгашт» ба NIGOH баргардед.'),
      ],
      summaryTitle: tr('Экрани пурра'),
    ),
    WizardStepId.callOverlay => WizardStep(
      id: WizardStepId.callOverlay,
      icon: Icons.phone_in_talk_rounded,
      color: NigohDesign.coral,
      title: tr('Занг дар экран'),
      reason: tr(
        'Занги воридотӣ ва ҳушдори SOS дарҳол дар тамоми экран '
        'кушода мешаванд, ҳатто вақте ки шумо бо телефон кор мекунед.',
      ),
      help: [
        tr(
          '«Иҷозат додан»-ро пахш кунед — саҳифаи «Поверх других приложений» кушода мешавад.',
        ),
        tr('Агар рӯйхат бошад, NIGOH Family-ро интихоб кунед.'),
        tr('«Разрешить показ поверх других приложений»-ро фаъол кунед.'),
        tr('Бо тугмаи «Бозгашт» ба NIGOH баргардед.'),
      ],
      summaryTitle: tr('Занг дар экран'),
    ),
    WizardStepId.camera => WizardStep(
      id: WizardStepId.camera,
      icon: Icons.qr_code_scanner_rounded,
      color: NigohDesign.amber,
      title: tr('Камера'),
      reason: tr(
        'Барои скан кардани QR-коди телефони фарзанд ҳангоми пайвастшавӣ.',
      ),
      help: [
        tr('«Иҷозат додан»-ро пахш кунед ва «Разрешить»-ро интихоб кунед.'),
        tr(
          'Агар равзана набарояд: Настройки → Приложения → NIGOH Family → '
          'Разрешения → Камера → «Разрешить».',
        ),
      ],
      summaryTitle: tr('Камера'),
    ),
  };
}

/// Runtime permission behind a step (null for special permissions).
ph.Permission? runtimePermissionOf(WizardStepId id, StepStage stage) =>
    switch (id) {
      WizardStepId.location =>
        stage == StepStage.always
            ? ph.Permission.locationAlways
            : ph.Permission.locationWhenInUse,
      WizardStepId.notifications => ph.Permission.notification,
      WizardStepId.microphone => ph.Permission.microphone,
      WizardStepId.camera => ph.Permission.camera,
      WizardStepId.battery => ph.Permission.ignoreBatteryOptimizations,
      _ => null,
    };

/// Native key in `getProtectionStatus` for special permissions.
String? protectionKeyOf(WizardStepId id) => switch (id) {
  WizardStepId.usage => 'usage',
  WizardStepId.overlay || WizardStepId.callOverlay => 'overlay',
  WizardStepId.accessibility => 'accessibility',
  WizardStepId.deviceAdmin => 'deviceAdmin',
  _ => null,
};

/// Reads, requests and opens settings for the wizard's steps.
class WizardActions {
  const WizardActions([this.platform = const WizardPlatform()]);
  final WizardPlatform platform;

  /// Reads the state of every step. Throws when Android could not be asked.
  Future<Map<WizardStepId, StepStatus>> readAll(List<WizardStepId> ids) async {
    Map<String, dynamic>? protection;
    if (ids.any((id) => protectionKeyOf(id) != null)) {
      protection = await platform.protection();
    }
    final result = <WizardStepId, StepStatus>{};
    for (final id in ids) {
      result[id] = await _read(id, protection);
    }
    return result;
  }

  /// Reads the status of one step from native flags or permission_handler.
  Future<StepStatus> _read(
    WizardStepId id,
    Map<String, dynamic>? protection,
  ) async {
    final key = protectionKeyOf(id);
    if (key != null) {
      final granted = protection?[key] == true;
      return StepStatus(
        granted: granted,
        missingPrerequisites:
            id == WizardStepId.accessibility &&
            !granted &&
            (protection?['usage'] != true || protection?['overlay'] != true),
      );
    }
    switch (id) {
      case WizardStepId.location:
        final gpsOn = await platform.locationServiceEnabled();
        final whenInUse = await platform.status(
          ph.Permission.locationWhenInUse,
        );
        if (!whenInUse.isGranted) {
          return StepStatus(
            granted: false,
            blocked: _blocked(whenInUse),
            gpsOff: !gpsOn,
          );
        }
        final always = await platform.status(ph.Permission.locationAlways);
        return StepStatus(
          granted: always.isGranted,
          blocked: _blocked(always),
          stage: StepStage.always,
          gpsOff: !gpsOn,
        );
      case WizardStepId.fullScreen:
        final notify = await platform.notifyStatus();
        return StepStatus(granted: notify.fullScreen);
      default:
        final status = await platform.status(
          runtimePermissionOf(id, StepStage.main)!,
        );
        return StepStatus(granted: status.isGranted, blocked: _blocked(status));
    }
  }

  /// Whether Android will no longer show the permission dialog.
  static bool _blocked(ph.PermissionStatus status) =>
      status.isPermanentlyDenied || status.isRestricted;

  /// «Иҷозат додан»: system dialog for runtime permissions, the exact
  /// settings screen for special ones.
  Future<void> grant(WizardStepId id, StepStatus status) async {
    final permission = runtimePermissionOf(id, status.stage);
    if (permission != null) {
      if (status.blocked) {
        await platform.openAppSettings();
      } else {
        await platform.request(permission);
      }
      return;
    }
    switch (id) {
      case WizardStepId.usage:
        await platform.invoke('openUsageSettings');
      case WizardStepId.overlay || WizardStepId.callOverlay:
        await platform.invoke('openOverlaySettings');
      case WizardStepId.accessibility:
        await platform.invoke('openAccessibilitySettingsDirect');
      case WizardStepId.deviceAdmin:
        await platform.invoke('openDeviceAdminSettings');
      case WizardStepId.fullScreen:
        await platform.openFullScreenSettings();
      default:
        await platform.openAppSettings();
    }
  }

  /// «Агар иҷозат дода нашуд»: the settings screen where it is switched on.
  Future<void> openFallback(WizardStepId id) async {
    switch (id) {
      case WizardStepId.usage:
        await platform.invoke('openUsageSettings');
      case WizardStepId.overlay || WizardStepId.callOverlay:
        await platform.invoke('openOverlaySettings');
      case WizardStepId.deviceAdmin:
        await platform.invoke('openDeviceAdminSettings');
      case WizardStepId.fullScreen:
        await platform.openFullScreenSettings();
      // App details: runtime permissions, battery and — for Accessibility —
      // the ⋮ «Разрешить ограниченные настройки» menu (Android 13+).
      default:
        await platform.openAppSettings();
    }
  }

  /// Opens the GPS settings (location step when GPS is off).
  Future<void> openLocationSettings() => platform.openLocationSettings();
}
