import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/app_state.dart';
import 'features/auth/login_screen.dart';
import 'features/contractors/scorecard.dart';
import 'features/flags/flag_detail.dart';
import 'features/flags/flag_queue.dart';
import 'features/intake/intake_screen.dart';
import 'features/overview/city_screen.dart';
import 'features/overview/ward_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/shell.dart';
import 'features/trail/trail.dart';

/// Routes a role may not open. Everything else is open to all signed-in roles.
bool _allowed(Session s, String path) {
  if (path.startsWith('/flags')) return s.canSeeFlags;
  if (path.startsWith('/intake')) return s.isOfficer;
  if (path.startsWith('/settings')) return s.isAuditor;
  return true;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects when the session changes, without rebuilding the router.
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      final path = state.uri.path;
      if (s == null) return path == '/login' ? null : '/login';
      if (path == '/login' || path == '/') return s.home;
      if (!_allowed(s, path)) return '${s.home}?notice=notAllowed';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (_, state, child) => Shell(location: state.uri.toString(), notice: state.uri.queryParameters['notice'], child: child),
        routes: [
          GoRoute(path: '/city', pageBuilder: (_, _) => const NoTransitionPage(child: CityScreen())),
          GoRoute(
            path: '/ward/:slug',
            pageBuilder: (_, s) => NoTransitionPage(child: WardScreen(wardFromSlug(s.pathParameters['slug']!), tab: s.uri.queryParameters['tab'] ?? 'money')),
          ),
          GoRoute(path: '/flags', pageBuilder: (_, _) => const NoTransitionPage(child: FlagQueueScreen())),
          GoRoute(
            path: '/flags/:type/:id',
            pageBuilder: (_, s) => NoTransitionPage(child: FlagDetailPage(s.pathParameters['type']!, s.pathParameters['id']!)),
          ),
          GoRoute(path: '/contractors', pageBuilder: (_, _) => const NoTransitionPage(child: ContractorListScreen())),
          GoRoute(path: '/contractors/:id', pageBuilder: (_, s) => NoTransitionPage(child: ContractorScreen(s.pathParameters['id']!))),
          GoRoute(path: '/trail', pageBuilder: (_, _) => const NoTransitionPage(child: TrailSearchScreen())),
          // The API path is the same as the route path.
          GoRoute(path: '/trail/:kind/:id', pageBuilder: (_, s) => NoTransitionPage(child: TrailScreen(s.uri.path))),
          GoRoute(path: '/intake', pageBuilder: (_, _) => const NoTransitionPage(child: IntakeScreen())),
          GoRoute(path: '/settings', pageBuilder: (_, _) => const NoTransitionPage(child: SettingsScreen())),
        ],
      ),
    ],
  );
});
