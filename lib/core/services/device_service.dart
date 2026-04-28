import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../../data/repositories/device_repository.dart';

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
      return await DeviceRepository.instance().isDeviceBanned(deviceId);
    } catch (e) {
      debugPrint('[device] Ban check failed: $e');
      return false;
    }
  }

  static Future<bool> deviceHasAccount() async {
    try {
      final deviceId = await getDeviceId();
      return await DeviceRepository.instance().profileExistsForDevice(deviceId);
    } catch (e) {
      debugPrint('[device] Account check failed: $e');
      return false;
    }
  }

  static Future<void> registerDevice(String userId) async {
    try {
      final info = await getDeviceInfo();
      await DeviceRepository.instance().registerDevice(
        userId: userId,
        deviceId: info['device_id'] ?? 'unknown',
        platform: info['platform'] ?? 'other',
        model: info['model'] ?? 'unknown',
      );
    } catch (e) { debugPrint('[device] Registration failed: $e'); }
  }
}
