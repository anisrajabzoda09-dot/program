// Файл: пайвасти WebRTC, media stream ва ICE signaling.

import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Ҳолатҳо ё навъҳои имконпазири пайвасти WebRTC, media stream ва ICE signaling-ро муайян мекунад.
enum RtcLinkState { connecting, connected, disconnected, failed }

/// Додаҳо ва рафтори марбут ба пайвасти WebRTC, media stream ва ICE signaling-ро ифода мекунад.
abstract class RtcEngine {
  /// ICE candidate-и маҳаллиро барои фиристодан ба ҳамсуҳбат мерасонад.
  void Function(Map<String, dynamic> candidate)? onIceCandidate;

  /// Тағйири ҳолати пайвасти WebRTC-ро ба controller хабар медиҳад.
  void Function(RtcLinkState state)? onLinkState;

  /// open экран ё dialog-и лозими занг ва signaling-и WebRTC-ро мекушояд.
  Future<void> open(List<Map<String, dynamic>> iceServers);

  /// createOffer мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад.
  Future<Map<String, dynamic>> createOffer();

  /// createAnswer мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад.
  Future<Map<String, dynamic>> createAnswer();

  /// setRemote ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<void> setRemote(Map<String, dynamic> description);

  /// addCandidate мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад.
  Future<void> addCandidate(Map<String, dynamic> candidate);

  /// setMuted ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  void setMuted(bool muted);

  /// setSpeaker ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  Future<void> setSpeaker(bool on);

  /// close мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад.
  Future<void> close();
}

/// Додаҳо ва рафтори марбут ба пайвасти WebRTC, media stream ва ICE signaling-ро ифода мекунад.
class FlutterRtcEngine implements RtcEngine {
  RTCPeerConnection? _pc;
  MediaStream? _local;

  /// Callback-и ICE candidate-и тавлидшударо нигоҳ медорад.
  @override
  void Function(Map<String, dynamic> candidate)? onIceCandidate;

  /// Callback-и ҳолати нави пайвасти peer-ро нигоҳ медорад.
  @override
  void Function(RtcLinkState state)? onLinkState;

  /// Қимати ҳисобшудаи peer-ро барои пайвасти WebRTC, media stream ва ICE signaling бармегардонад.
  RTCPeerConnection get _peer {
    final pc = _pc;
    if (pc == null) throw StateError('Peer connection is not open');
    return pc;
  }

  /// open экран ё dialog-и лозими занг ва signaling-и WebRTC-ро мекушояд.
  @override
  Future<void> open(List<Map<String, dynamic>> iceServers) async {
    _local = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    final pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;
    pc.onIceCandidate = (c) {
      if (c.candidate == null || c.candidate!.isEmpty) return;
      onIceCandidate?.call({
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };
    pc.onConnectionState = (s) {
      final mapped = switch (s) {
        RTCPeerConnectionState.RTCPeerConnectionStateConnected =>
          RtcLinkState.connected,
        RTCPeerConnectionState.RTCPeerConnectionStateFailed =>
          RtcLinkState.failed,
        RTCPeerConnectionState.RTCPeerConnectionStateDisconnected =>
          RtcLinkState.disconnected,
        _ => RtcLinkState.connecting,
      };
      onLinkState?.call(mapped);
    };
    pc.onIceConnectionState = (s) {
      if (s == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          s == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        onLinkState?.call(RtcLinkState.connected);
      } else if (s == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        onLinkState?.call(RtcLinkState.failed);
      }
    };
    final local = _local!;
    for (final track in local.getAudioTracks()) {
      await pc.addTrack(track, local);
    }
    // Қадами дохилии пайвасти WebRTC, media stream ва ICE signaling.
    await Helper.setSpeakerphoneOn(false);
  }

  /// desc мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад.
  Map<String, dynamic> _desc(RTCSessionDescription d) => {
    'sdp': d.sdp,
    'type': d.type,
  };

  /// createOffer мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад.
  @override
  Future<Map<String, dynamic>> createOffer() async {
    final offer = await _peer.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await _peer.setLocalDescription(offer);
    return _desc(offer);
  }

  /// createAnswer мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад.
  @override
  Future<Map<String, dynamic>> createAnswer() async {
    final answer = await _peer.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await _peer.setLocalDescription(answer);
    return _desc(answer);
  }

  /// setRemote ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  @override
  Future<void> setRemote(Map<String, dynamic> description) =>
      _peer.setRemoteDescription(
        RTCSessionDescription(
          description['sdp'] as String?,
          description['type'] as String?,
        ),
      );

  /// addCandidate мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад.
  @override
  Future<void> addCandidate(Map<String, dynamic> candidate) =>
      _peer.addCandidate(
        RTCIceCandidate(
          candidate['candidate'] as String?,
          candidate['sdpMid'] as String?,
          (candidate['sdpMLineIndex'] as num?)?.toInt(),
        ),
      );

  /// setMuted ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  @override
  void setMuted(bool muted) {
    for (final track in _local?.getAudioTracks() ?? const []) {
      track.enabled = !muted;
    }
  }

  /// setSpeaker ҳолатро тағйир дода, интерфейс ё server-ро нав мекунад.
  @override
  Future<void> setSpeaker(bool on) async {
    await Helper.setSpeakerphoneOn(on);
  }

  /// close мантиқи зарурии пайвасти WebRTC, media stream ва ICE signaling-ро иҷро мекунад.
  @override
  Future<void> close() async {
    final local = _local;
    final pc = _pc;
    _local = null;
    _pc = null;
    onIceCandidate = null;
    onLinkState = null;
    try {
      if (local != null) {
        for (final track in local.getTracks()) {
          try {
            await track.stop();
          } catch (_) {
            // Микрофон пас аз анҷоми занг ҳатман хомӯш карда мешавад.
          }
        }
        await local.dispose();
      }
    } finally {
      if (pc != null) {
        try {
          await pc.close();
        } finally {
          await pc.dispose();
        }
      }
    }
  }
}
