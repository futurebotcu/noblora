import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceService {
  static final _plugin = DeviceInfoPlugin();

  static Future<Map<String, String>> getDeviceInfo() async {
    if (kIsWeb) {
      return {'device_id': 'web', 'platform': 'web', 'model': 'browser'};
    }
    if (Platform.isAndroid) {
      final info = await _plugin.androidInfo;
      return {
        'device_id': info.id,
        'platform': 'android',
        'model': '${info.manufacturer} ${info.model}',
      };
    } else if (Platform.isIOS) {
      final info = await _plugin.iosInfo;
      return {
        'device_id': info.identifierForVendor ?? 'unknown',
        'platform': 'ios',
        'model': info.model,
      };
    }
    return {'device_id': 'unknown', 'platform': 'other', 'model': 'unknown'};
  }

  static Future<String> getDeviceId() async {
    final info = await getDeviceInfo();
    return info['device_id'] ?? 'unknown';
  }

  static Future<bool> isDeviceBanned() async {
    try {
      final deviceId = await getDeviceId();
      final result = await Supabase.instance.client
          .from('banned_devices')
          .select('id')
          .eq('device_id', deviceId)
          .maybeSingle();
      return result != null;
    } catch (e) {
      debugPrint('[device] Ban check failed: $e');
      return false;
    }
  }

  static Future<bool> deviceHasAccount() async {
    try {
      final deviceId = await getDeviceId();
      final result = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('device_id', deviceId)
          .maybeSingle();
      return result != null;
    } catch (e) {
      debugPrint('[device] Account check failed: $e');
      return false;
    }
  }

  static Future<void> registerDevice(String userId) async {
    try {
      final info = await getDeviceInfo();
      await Supabase.instance.client.from('user_devices').upsert({
        'user_id': userId,
        'device_id': info['device_id'],
        'device_platform': info['platform'],
        'device_model': info['model'],
        'last_seen': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,device_id');

      await Supabase.instance.client.from('profiles').update({
        'device_id': info['device_id'],
        'device_platform': info['platform'],
      }).eq('id', userId);
    } catch (e) { debugPrint('[device] Registration failed: $e'); }
  }
}
