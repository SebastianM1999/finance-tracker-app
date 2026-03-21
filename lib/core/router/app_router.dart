import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/investments/screens/investments_screen.dart';
import '../../features/giro/screens/giro_screen.dart';
import '../../features/schulden/screens/schulden_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/verlauf/screens/verlauf_screen.dart';
import '../../shared/widgets/app_bottom_nav.dart';

// Named routes
class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const investments = '/investments';
  static const accounts = '/accounts';
  static const debts = '/debts';
  static const settings = '/settings';
  static const verlauf = '/verlauf';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isLoggedIn = ref.read(authStateProvider).valueOrNull != null;
      final isOnLogin = state.matchedLocation == AppRoutes.login;

      if (!isLoggedIn && !isOnLogin) return AppRoutes.login;
      if (isLoggedIn && isOnLogin) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeScaleTransition(animation: animation, child: child),
        ),
      ),
      GoRoute(
        path: AppRoutes.verlauf,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const VerlaufScreen(),
          transitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            AppScaffold(navigationShell: navigationShell),
        // Only mount the active tab — widgets rebuild on each visit so
        // flutter_animate entrance animations replay every time.
        // StreamProviders are NOT autoDispose, so cached data loads instantly.
        navigatorContainerBuilder: (context, navigationShell, children) =>
            children[navigationShell.currentIndex],
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.investments,
                builder: (context, state) => const InvestmentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.accounts,
                builder: (context, state) => const GiroScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.debts,
                builder: (context, state) => const SchuldenScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod auth state to GoRouter's ChangeNotifier-based refresh.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
