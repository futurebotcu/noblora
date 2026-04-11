// Phase 4 video thumbnail helper'ları için pure-fonksiyon table testleri.
// Bunlar URL parse mantığını sigortalar — feed/detail/compose render
// path'lerinde regression olursa burası ilk bağırır.

import 'package:flutter_test/flutter_test.dart';
import 'package:noblara/core/utils/video_assets.dart';

void main() {
  group('isVideoUrl', () {
    test('null and empty are not videos', () {
      expect(isVideoUrl(null), isFalse);
      expect(isVideoUrl(''), isFalse);
    });

    test('common video extensions are detected', () {
      expect(isVideoUrl('https://x/foo.mp4'), isTrue);
      expect(isVideoUrl('https://x/foo.mov'), isTrue);
      expect(isVideoUrl('https://x/foo.m4v'), isTrue);
      expect(isVideoUrl('https://x/foo.webm'), isTrue);
    });

    test('uppercase extensions are detected', () {
      expect(isVideoUrl('https://x/foo.MP4'), isTrue);
      expect(isVideoUrl('https://x/foo.MOV'), isTrue);
    });

    test('extension with query string is detected', () {
      expect(isVideoUrl('https://x/foo.mp4?token=abc&v=1'), isTrue);
    });

    test('image extensions are not videos', () {
      expect(isVideoUrl('https://x/foo.jpg'), isFalse);
      expect(isVideoUrl('https://x/foo.png'), isFalse);
      expect(isVideoUrl('https://x/foo.jpg?token=abc'), isFalse);
    });

    test('no extension at all is not a video', () {
      expect(isVideoUrl('https://x/foo'), isFalse);
    });
  });

  group('videoThumbnailUrlFor', () {
    test('returns null for non-video', () {
      expect(videoThumbnailUrlFor(null), isNull);
      expect(videoThumbnailUrlFor(''), isNull);
      expect(videoThumbnailUrlFor('https://x/foo.jpg'), isNull);
    });

    test('replaces .mp4 with .jpg, preserves base path', () {
      expect(
        videoThumbnailUrlFor('https://x/path/foo.mp4'),
        'https://x/path/foo.jpg',
      );
    });

    test('preserves query string when replacing extension', () {
      expect(
        videoThumbnailUrlFor('https://x/path/foo.mp4?token=abc'),
        'https://x/path/foo.jpg?token=abc',
      );
    });

    test('handles .mov, .m4v, .webm', () {
      expect(
        videoThumbnailUrlFor('https://x/foo.mov'),
        'https://x/foo.jpg',
      );
      expect(
        videoThumbnailUrlFor('https://x/foo.m4v'),
        'https://x/foo.jpg',
      );
      expect(
        videoThumbnailUrlFor('https://x/foo.webm'),
        'https://x/foo.jpg',
      );
    });

    test('preserves complex query with multiple params', () {
      expect(
        videoThumbnailUrlFor('https://x/foo.mp4?a=1&b=2&token=xyz'),
        'https://x/foo.jpg?a=1&b=2&token=xyz',
      );
    });
  });
}
