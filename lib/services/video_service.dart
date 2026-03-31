import 'package:url_launcher/url_launcher.dart';

/// Manages video call sessions using Jitsi Meet (free, no API key).
class VideoService {
  static const _baseUrl = 'https://meet.jit.si';

  /// Generates a deterministic room name for a match
  static String roomName(String matchId) {
    final short = matchId.replaceAll('-', '').substring(0, 12);
    return 'noblara-$short';
  }

  /// Full Jitsi Meet room URL (plain, for storage in DB)
  static String roomUrl(String matchId) {
    return '$_baseUrl/${roomName(matchId)}';
  }

  /// Full Jitsi URL with config params for starting a call.
  /// [displayName] is shown to the other participant.
  static String callUrl(String matchId, {String displayName = ''}) {
    final room = roomName(matchId);
    final encoded = Uri.encodeComponent(displayName);
    // Jitsi hash-based config
    return '$_baseUrl/$room'
        '#userInfo.displayName=$encoded'
        '&config.startWithAudioMuted=false'
        '&config.startWithVideoMuted=false'
        '&config.prejoinPageEnabled=false'
        '&config.fileRecordingsEnabled=false'
        '&config.localRecording.enabled=false'
        '&config.disableRecordAudioNotification=true';
  }

  /// Opens the video call in the browser with camera/mic enabled
  static Future<void> openCall(String matchId, {String displayName = ''}) async {
    final uri = Uri.parse(callUrl(matchId, displayName: displayName));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch video call URL');
    }
  }

  /// Default Short Intro call duration: 4 minutes (user can set 3-5)
  static const defaultCallDurationMinutes = 4;
  static const minCallDurationMinutes = 3;
  static const maxCallDurationMinutes = 5;

  /// Duration from minutes count
  static Duration callDuration(int minutes) => Duration(minutes: minutes);

  /// 12-hour window to respond to a scheduling proposal
  static const scheduleWindowHours = 12;
}
