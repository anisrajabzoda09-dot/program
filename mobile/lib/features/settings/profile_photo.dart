// Файл: интихоб ва нигоҳдории акси профил.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/session.dart';
import '../../ui/avatar.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import '../../l10n/l10n.dart';

/// Шакли callback-и истифодашавандаро барои интихоб ва нигоҳдории акси профил муайян мекунад.
typedef PhotoPicker = Future<Uint8List?> Function(ImageSource source);

/// Қимати maxAvatarBytes-ро барои интихоб ва нигоҳдории акси профил нигоҳ медорад.
const maxAvatarBytes = 260 * 1024;

/// pickWithImagePicker мантиқи зарурии интихоб ва нигоҳдории акси профилро иҷро мекунад.
Future<Uint8List?> _pickWithImagePicker(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 80,
    preferredCameraDevice: CameraDevice.front,
  );
  return file?.readAsBytes();
}

/// Widget-и ProfileAvatarButton-ро барои интихоб ва нигоҳдории акси профил месозад.
class ProfileAvatarButton extends StatefulWidget {
  const ProfileAvatarButton({
    super.key,
    required this.session,
    this.size = 56,
    this.color,
  });

  final Session session;
  final double size;
  final Color? color;

  /// Қимати debugPicker-ро барои интихоб ва нигоҳдории акси профил нигоҳ медорад.
  @visibleForTesting
  static PhotoPicker? debugPicker;

  /// Ҳолати ProfileAvatarButton-ро барои интихоб ва сабти акси профил месозад.
  @override
  State<ProfileAvatarButton> createState() => _ProfileAvatarButtonState();
}

/// Ҳолат ва рафтори ProfileAvatarButtonState-ро барои навсозии интерфейс идора мекунад.
class _ProfileAvatarButtonState extends State<ProfileAvatarButton> {
  bool busy = false;

  /// choose ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<void> choose() async {
    final hasPhoto = widget.session.avatar != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const ValueKey('avatar-gallery'),
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(tr('Аз галерея')),
                onTap: () => Navigator.pop(sheetContext, 'gallery'),
              ),
              ListTile(
                key: const ValueKey('avatar-camera'),
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(tr('Сурат гирифтан')),
                onTap: () => Navigator.pop(sheetContext, 'camera'),
              ),
              if (hasPhoto)
                ListTile(
                  key: const ValueKey('avatar-delete'),
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(sheetContext).colorScheme.error,
                  ),
                  title: Text(
                    tr('Нест кардан'),
                    style: TextStyle(
                      color: Theme.of(sheetContext).colorScheme.error,
                    ),
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'delete'),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'delete') return remove();
    await upload(action == 'camera' ? ImageSource.camera : ImageSource.gallery);
  }

  /// upload додаҳоро бо server ҳамоҳанг мекунад ва метавонад API-ро нависад.
  Future<void> upload(ImageSource source) async {
    final Uint8List? bytes;
    try {
      bytes = await (ProfileAvatarButton.debugPicker ?? _pickWithImagePicker)(
        source,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      final denied = e.code.contains('access_denied');
      showMessage(
        context,
        denied
            ? (source == ImageSource.camera
                  ? tr(
                      'Иҷозат дода нашуд. Дар танзимоти телефон иҷозати камераро диҳед.',
                    )
                  : tr(
                      'Иҷозат дода нашуд. Дар танзимоти телефон иҷозати суратҳоро диҳед.',
                    ))
            : tr('Сурат интихоб нашуд: {error}', {
                'error': e.message ?? e.code,
              }),
        error: true,
      );
      return;
    }
    if (bytes == null || !mounted) return;
    if (bytes.isEmpty) {
      showMessage(
        context,
        tr('Сурат холӣ аст. Дигарашро интихоб кунед.'),
        error: true,
      );
      return;
    }
    if (bytes.length > maxAvatarBytes) {
      showMessage(
        context,
        tr('Сурат хеле калон аст. Сурати хурдтар интихоб кунед.'),
        error: true,
      );
      return;
    }
    setState(() => busy = true);
    try {
      final path = await widget.session.api.uploadAvatar(bytes);
      if (!mounted) return;
      if (path == null || path.isEmpty) {
        // Маълумоти маҳаллӣ нигоҳ дошта ё барқарор карда мешавад.
        widget.session.unawaitedRefresh();
      } else {
        widget.session.setAvatar(path);
      }
      showMessage(context, tr('Сурат нигоҳ дошта шуд.'));
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// remove маълумотро ҳазф карда, ҳолати вобастаро нав мекунад.
  Future<void> remove() async {
    setState(() => busy = true);
    try {
      await widget.session.api.deleteAvatar();
      if (!mounted) return;
      widget.session.setAvatar(null);
      showMessage(context, tr('Сурат нест карда шуд.'));
    } catch (e) {
      if (mounted) showMessage(context, e, error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Widget-и ProfileAvatarButton-ро барои интихоб ва сабти акси профил месозад.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = widget.session;
    final name = session.displayName.isEmpty ? '?' : session.displayName;
    return Semantics(
      button: true,
      label: tr('Сурати профил'),
      child: InkWell(
        key: const ValueKey('profile-avatar'),
        customBorder: const CircleBorder(),
        onTap: busy ? null : choose,
        child: SizedBox(
          width: widget.size + 4,
          height: widget.size + 4,
          child: Stack(
            children: [
              AvatarView(
                name: name,
                url: session.api.fileUrl(session.avatar),
                size: widget.size,
                color: widget.color,
              ),
              if (busy)
                Positioned.fill(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: .7),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(widget.size * .28),
                    child: const CircularProgressIndicator(
                      key: ValueKey('avatar-progress'),
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: widget.color ?? NigohDesign.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
