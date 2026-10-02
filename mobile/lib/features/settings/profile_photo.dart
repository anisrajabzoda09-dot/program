import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/platform.dart';
import '../../core/session.dart';
import '../../ui/avatar.dart';
import '../../ui/nigoh_design.dart';
import '../../ui/widgets.dart';
import '../../l10n/l10n.dart';

/// Returns the picked image bytes, or null when the user cancelled.
typedef PhotoPicker = Future<Uint8List?> Function(ImageSource source);

/// Server limit is ~350 KB of base64, i.e. ~260 KB of raw bytes.
const maxAvatarBytes = 260 * 1024;

Future<Uint8List?> _pickWithImagePicker(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: isDesktop ? ImageSource.gallery : source,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 80,
    preferredCameraDevice: CameraDevice.front,
  );
  final bytes = await file?.readAsBytes();
  // image_picker cannot resize on Windows: shrink big photos here.
  if (bytes != null && isDesktop && bytes.length > maxAvatarBytes) {
    return shrinkAvatar(bytes);
  }
  return bytes;
}

/// Re-encodes a big photo as a small square-ish PNG that fits
/// [maxAvatarBytes]; returns the original bytes if it cannot be decoded.
Future<Uint8List> shrinkAvatar(Uint8List bytes) async {
  for (final size in const [512, 384, 256, 192]) {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: size);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (data == null) break;
      final png = data.buffer.asUint8List();
      if (png.length <= maxAvatarBytes) return png;
    } catch (_) {
      break; // Not an image Flutter can read: let the size check report it.
    }
  }
  return bytes;
}

/// The profile photo in Settings: tap to pick from the gallery, take a
/// photo or remove it. Shows progress while uploading and every error.
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

  /// Replaced in tests (no platform picker there).
  @visibleForTesting
  static PhotoPicker? debugPicker;

  @override
  State<ProfileAvatarButton> createState() => _ProfileAvatarButtonState();
}

class _ProfileAvatarButtonState extends State<ProfileAvatarButton> {
  bool busy = false;

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
              // Desktop: image_picker only opens a file dialog, no camera.
              if (!isDesktop)
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
        // Saved, but the reply had no path: reload the profile.
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
