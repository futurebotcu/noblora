import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';

/// Bucket-specific upload + getPublicUrl wrappers for the two storage
/// buckets the app uses (`galleries` for nob photos/videos and
/// `profile-photos` for avatars). Each upload method calls `uploadBinary`
/// then `getPublicUrl` and returns the public URL — the typical pair was
/// previously inlined at every caller. Mock mode short-circuits to a
/// `mock://` placeholder URL so callers can still drive their state
/// machines without touching the network.
class StorageRepository {
  final SupabaseClient? _supabase;

  StorageRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Upload [bytes] to the `galleries` bucket at [path] and return the
  /// public URL. Set [upsert] to overwrite an existing object — used for
  /// the deterministic-named video thumbnail sibling.
  Future<String> uploadToGallery({
    required String path,
    required Uint8List bytes,
    required String contentType,
    bool upsert = false,
  }) async {
    if (isMockMode) return 'mock://gallery/$path';
    final storage = _supabase!.storage.from('galleries');
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: upsert),
    );
    return storage.getPublicUrl(path);
  }

  /// Upload [bytes] to the `profile-photos` bucket at [path] and return
  /// the public URL. Used by onboarding (initial avatar) and the photos
  /// edit section (replace existing photo).
  Future<String> uploadProfilePhoto({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (isMockMode) return 'mock://profile-photo/$path';
    final storage = _supabase!.storage.from('profile-photos');
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType),
    );
    return storage.getPublicUrl(path);
  }

  /// Remove a single object from the `profile-photos` bucket. Caller
  /// decides whether to await — the photos edit dialog fires-and-forgets,
  /// the upload-replacement path awaits inside its try/catch.
  Future<void> removeProfilePhoto(String path) async {
    if (isMockMode) return;
    await _supabase!.storage.from('profile-photos').remove([path]);
  }
}
