import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'providers/appearance_provider.dart';
import 'providers/auth_provider.dart';

class NobleApp extends ConsumerWidget {
  const NobleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final accent = appearance.accent;

    // Sync appearance from Supabase when user becomes authenticated
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.userId == null && next.userId != null) {
        ref.read(appearanceProvider.notifier).syncFromSupabase();
      }
    });

    return MaterialApp(
      title: 'Noblara',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.withAccent(accent),
      home: const AppRouter(),
    );
  }
}
