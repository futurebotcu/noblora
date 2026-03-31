import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_router.dart';

class NobleApp extends ConsumerWidget {
  const NobleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Noblara',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppRouter(),
    );
  }
}
