import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    // Show a failed load at once with a Retry button, instead of retrying silently.
    retry: (_, _) => null,
    child: const SathiApp(),
  ));
}

class SathiApp extends ConsumerWidget {
  const SathiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'BMC Sathi',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(SathiColors.light),
        darkTheme: buildTheme(SathiColors.dark),
        themeMode: ref.watch(themeModeProvider),
        routerConfig: ref.watch(routerProvider),
      );
}
