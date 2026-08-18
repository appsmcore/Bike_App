import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/layout/app_layout.dart';
import 'core/theme/app_theme.dart';
import 'data/app_state.dart';

class PaceMatchApp extends StatelessWidget {
  const PaceMatchApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<AppState>().themeMode;
    final authReady = context.watch<AppState>().authReady;

    return MaterialApp.router(
      title: 'PaceMatch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        if (!authReady) {
          return const Material(
            child: ColoredBox(
              color: Color(0xFF0E1311),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1A7A4C)),
              ),
            ),
          );
        }

        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: AppLayout.clampedTextScaler(context)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
