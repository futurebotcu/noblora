// Helpers for working with video Nob assets stored in Supabase storage.
//
// Videos are uploaded to the same storage prefix as photos but with a `.mp4`
// extension. At upload time we also generate a first-frame JPEG thumbnail
// and store it next to the video at the same path with `.jpg`. This file
// only deals with deriving the thumbnail URL — the actual generation lives
// in the compose screen using the video_thumbnail package.

bool isVideoUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final lower = url.toLowerCase().split('?').first;
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.m4v') ||
      lower.endsWith('.webm');
}

/// Returns a sibling thumbnail URL for a video URL, or null if not derivable.
/// e.g. `.../foo.mp4?token=abc` → `.../foo.jpg?token=abc`
String? videoThumbnailUrlFor(String? url) {
  if (!isVideoUrl(url)) return null;
  final qIndex = url!.indexOf('?');
  final query = qIndex >= 0 ? url.substring(qIndex) : '';
  final base = qIndex >= 0 ? url.substring(0, qIndex) : url;
  final dot = base.lastIndexOf('.');
  if (dot < 0) return null;
  return '${base.substring(0, dot)}.jpg$query';
}
