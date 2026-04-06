import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/utils/mock_mode.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env
  await dotenv.load(fileName: '.env');

  // Initialize Firebase (graceful — app works without it)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[main] Firebase init skipped: $e');
  }

  // Initialize Supabase only when not in mock mode
  if (!isMockMode) {
    await Supabase.initialize(
      url: dotenv.get('SUPABASE_URL'),
      anonKey: dotenv.get('SUPABASE_ANON_KEY'),
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  // Initialize push notifications (graceful — fails silently if Firebase not configured)
  final pushReady = await PushNotificationService.initialize();
  if (pushReady) {
    await PushNotificationService.registerToken();
  }

  runApp(
    const ProviderScope(
      child: NobleApp(),
    ),
  );
}
