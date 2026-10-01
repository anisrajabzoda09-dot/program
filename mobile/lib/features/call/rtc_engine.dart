import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Connection state of the media link, reduced to what the call UI needs.
enum RtcLinkState { connecting, connected, disconnected, failed }

/// Thin wrapper around one audio-only WebRTC peer connection. The call
/// controller only talks to this interface, so tests can use a fake.
abstract class RtcEngine {
  /// Called for every local ICE candidate ({candidate, sdpMid, sdpMLineIndex}).
  void Function(Map<String, dynamic> candidate)? onIceCandidate;

  /// Called when the peer connection changes state.
  void Function(RtcLinkState state)? onLinkState;

  /// Opens the microphone and creates the peer connection.
  Future<void> open(List<Map<String, dynamic>> iceServers);

  /// Creates an offer, sets it as local description, returns {sdp, type}.
  Future<Map<String, dynamic>> createOffer();

  /// Creates an answer, sets it as local description, returns {sdp, type}.
  Future<Map<String, dynamic>> createAnswer();

  Future<void> setRemote(Map<String, dynamic> description);
  Future<void> addCandidate(Map<String, dynamic> candidate);
  void setMuted(bool muted);
  Future<void> setSpeaker(bool on);

  /// Stops the microphone and closes the connection. Safe to call twice.
  Future<void> close();
}

/// Real implementation backed by flutter_webrtc.
class FlutterRtcEngine implements RtcEngine {
  RTCPeerConnection? _pc;
  MediaStream? _local;

  @override
  void Function(Map<String, dynamic> candidate)? onIceCandidate;

  @override
  void Function(RtcLinkState state)? onLinkState;

  RTCPeerConnection get _peer {
    final pc = _pc;
    if (pc == null) throw StateError('Peer connection is not open');
    return pc;
  }

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
    // Earpiece by default, like a normal phone call.
    await Helper.setSpeakerphoneOn(false);
  }

  Map<String, dynamic> _desc(RTCSessionDescription d) => {
    'sdp': d.sdp,
    'type': d.type,
  };

  @override
  Future<Map<String, dynamic>> createOffer() async {
    final offer = await _peer.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await _peer.setLocalDescription(offer);
    return _desc(offer);
  }

  @override
  Future<Map<String, dynamic>> createAnswer() async {
    final answer = await _peer.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await _peer.setLocalDescription(answer);
    return _desc(answer);
  }

  @override
  Future<void> setRemote(Map<String, dynamic> description) =>
      _peer.setRemoteDescription(
        RTCSessionDescription(
          description['sdp'] as String?,
          description['type'] as String?,
        ),
      );

  @override
  Future<void> addCandidate(Map<String, dynamic> candidate) =>
      _peer.addCandidate(
        RTCIceCandidate(
          candidate['candidate'] as String?,
          candidate['sdpMid'] as String?,
          (candidate['sdpMLineIndex'] as num?)?.toInt(),
        ),
      );

  @override
  void setMuted(bool muted) {
    for (final track in _local?.getAudioTracks() ?? const []) {
      track.enabled = !muted;
    }
  }

  @override
  Future<void> setSpeaker(bool on) => Helper.setSpeakerphoneOn(on);

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
            // Keep stopping the other tracks; the mic must never stay open.
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
