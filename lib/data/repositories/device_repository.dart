import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/mock_mode.dart';

/// Device-level Supabase ops: ban check, prior-account lookup, register.
/// Backs the static `DeviceService` API. Device-info plugin (device_info_plus)
/// stays in DeviceService — this repo only handles Supabase data.
class DeviceRepository {
  final SupabaseClient? _supabase;

  DeviceRepository({SupabaseClient? supabase}) : _supabase = supabase;

  /// Lazy singleton for non-Riverpod static callers (DeviceService).
  /// Riverpod-aware code should use `deviceRepositoryProvider`.
  static DeviceRepository? _singleton;
  static DeviceRepository instance() {
    if (isMockMode) return _singleton ??= DeviceRepository();
    return _singleton ??= DeviceRepository(supabase: Supabase.instance.client);
  }

  Future<bool> isDeviceBanned(String deviceId) async {
    if (isMockMode) return false;
    final res = await _supabase!
        .from('banned_devices')
        .select('id')
        .eq('device_id', deviceId)
        .maybeSingle();
    return res != null;
  }

  Future<bool> profileExistsForDevice(String deviceId) async {
    if (isMockMode) return false;
    final res = await _supabase!
        .from('profiles')
        .select('id')
        .eq('device_id', deviceId)
        .maybeSingle();
    return res != null;
  }

  /// Atomic register: upserts user_devices row + syncs profiles.device_id /
  /// device_platform. Caller's outer try/catch wraps both ops (split would
  /// change R4 catch-pattern semantics).
  Future<void> registerDevice({
    required String userId,
    required String deviceId,
    required String platform,
    required String model,
  }) async {
    if (isMockMode) return;
    await _supabase!.from('user_devices').upsert(
      {
        'user_id': userId,
        'device_id': deviceId,
        'device_platform': platform,
        'device_model': model,
        'last_seen': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,device_id',
    );

    await _supabase.from('profiles').update({
      'device_id': deviceId,
      'device_platform': platform,
    }).eq('id', userId);
  }
}
