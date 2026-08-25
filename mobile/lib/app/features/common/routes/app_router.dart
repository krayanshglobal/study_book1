import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../splash/presentation/splash_screen.dart';
import '../../landing/presentation/landing_screen.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/register_screen.dart';
import '../../auth/presentation/forgot_password_screen.dart';
import '../../auth/presentation/change_password_screen.dart';
import '../presentation/notifications_screen.dart';
import '../../dashboard/presentation/student_dashboard_screen.dart';
import '../../questions/presentation/question_bank_screen.dart';
import '../../questions/presentation/explorer_screen.dart';
import '../../tests/presentation/tests_list_screen.dart';
import '../../tests/presentation/live_test_screen.dart';
import '../../tests/presentation/test_result_screen.dart';
import '../../videos/presentation/videos_screen.dart';
import '../../leaderboard/presentation/leaderboard_screen.dart';
import '../../analytics/presentation/my_analytics_screen.dart';
import '../../referrals/presentation/referrals_screen.dart';
import '../../pricing/presentation/pricing_screen.dart';
import '../../pricing/presentation/payment_success_screen.dart';
import '../../profile/presentation/profile_screen.dart';

import '../../admin/presentation/admin_dashboard_screen.dart';
import '../../admin/presentation/manage_questions_screen.dart';
import '../../admin/presentation/manage_tests_screen.dart';
import '../../admin/presentation/manage_videos_screen.dart';
import '../../admin/presentation/manage_users_screen.dart';
import '../../admin/presentation/manage_plans_screen.dart';
import '../../admin/presentation/manage_announcements_screen.dart';
import '../../admin/presentation/admin_analytics_screen.dart';
import '../../admin/presentation/super_admin_screen.dart';
import '../../admin/presentation/manage_notes_screen.dart';
import '../../admin/presentation/manage_promos_screen.dart';
import '../../admin/presentation/manage_class_requests_screen.dart';
import '../../admin/presentation/manage_flashcards_screen.dart';
import '../../admin/presentation/manage_payments_screen.dart';

import '../../auth/providers/auth_provider.dart';

/// Material 3 slide-and-fade page transition helper
Page<dynamic> _buildFadeSlidePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeOutCubic).animate(animation),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.025, 0),
            end: Offset.zero,
          ).animate(CurveTween(curve: Curves.easeOutCubic).animate(animation)),
          child: child,
        ),
      );
    },
  );
}

/// Listens to authState changes without recreating the GoRouter instance.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  ref.keepAlive();
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/',
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      if (authState.isLoading) return null;

      final bool loggedIn = authState.user != null;
      final String loc = state.matchedLocation;

      final bool isPublic = loc == '/' || loc == '/landing' || loc == '/login' || loc == '/register' || loc == '/forgot-password';

      if (loggedIn) {
        if (loc != '/' && isPublic) {
          return authState.user!.isAdmin ? '/admin' : '/dashboard';
        }
        if (loc == '/dashboard' && authState.user!.isAdmin) {
          return '/admin';
        }
        if (loc.startsWith('/admin') && !authState.user!.isAdmin) {
          return '/dashboard';
        }
        if (loc == '/superadmin' && !authState.user!.isSuperAdmin) {
          return '/admin';
        }
        return null;
      } else {
        if (!isPublic) {
          return '/login';
        }
        return null;
      }
    },
    routes: [
      // Public / Splash
      GoRoute(path: '/', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const SplashScreen())),
      GoRoute(path: '/landing', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const LandingScreen())),
      GoRoute(path: '/login', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const LoginScreen())),
      GoRoute(path: '/register', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const RegisterScreen())),
      GoRoute(path: '/forgot-password', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const ForgotPasswordScreen())),
      GoRoute(path: '/change-password', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const ChangePasswordScreen())),
      GoRoute(path: '/notifications', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const NotificationsScreen())),

      // Full screen student pages
      GoRoute(
        path: '/tests/:id/live',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _buildFadeSlidePage(
              state: state, child: LiveTestScreen(testId: id));
        },
      ),
      GoRoute(
        path: '/tests/:id/result',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _buildFadeSlidePage(
              state: state, child: TestResultScreen(testId: id));
        },
      ),
      GoRoute(
        path: '/payment/success',
        pageBuilder: (context, state) {
          final sessionId = state.uri.queryParameters['session_id'];
          return _buildFadeSlidePage(
              state: state, child: PaymentSuccessScreen(sessionId: sessionId));
        },
      ),

      // Student Stateful Shell Navigation for Tab State Preservation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return navigationShell;
        },
        branches: [
          // Branch 0: Home (Dashboard)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                pageBuilder: (context, state) => _buildFadeSlidePage(
                    state: state, child: const StudentDashboardScreen()),
              ),
            ],
          ),

          // Branch 1: Explore (Study Explorer & Question Bank)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explorer',
                pageBuilder: (context, state) => _buildFadeSlidePage(
                    state: state, child: const ExplorerScreen()),
              ),
              GoRoute(
                path: '/questions',
                pageBuilder: (context, state) => _buildFadeSlidePage(
                    state: state, child: const QuestionBankScreen()),
              ),
            ],
          ),

          // Branch 2: Tests
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tests',
                pageBuilder: (context, state) => _buildFadeSlidePage(
                    state: state, child: const TestsListScreen()),
              ),
            ],
          ),

          // Branch 3: Analytics (My Analytics & Leaderboard)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-analytics',
                pageBuilder: (context, state) => _buildFadeSlidePage(
                    state: state, child: const MyAnalyticsScreen()),
              ),
              GoRoute(
                path: '/leaderboard',
                pageBuilder: (context, state) => _buildFadeSlidePage(
                    state: state, child: const LeaderboardScreen()),
              ),
            ],
          ),

          // Branch 4: Profile (Profile, Videos, Referrals, Pricing)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => _buildFadeSlidePage(
                    state: state, child: const ProfileScreen()),
              ),
              GoRoute(
                path: '/videos',
                pageBuilder: (context, state) => _buildFadeSlidePage(
                    state: state, child: const VideosScreen()),
              ),
              GoRoute(
                path: '/referrals',
                pageBuilder: (context, state) => _buildFadeSlidePage(
                    state: state, child: const ReferralsScreen()),
              ),
              GoRoute(
                path: '/pricing',
                pageBuilder: (context, state) => _buildFadeSlidePage(
                    state: state, child: const PricingScreen()),
              ),
            ],
          ),
        ],
      ),

      // Admin & SuperAdmin
      GoRoute(path: '/admin', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const AdminDashboardScreen())),
      GoRoute(path: '/admin/questions', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const ManageQuestionsScreen())),
      GoRoute(path: '/admin/tests', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const ManageTestsScreen())),
      GoRoute(path: '/admin/videos', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const ManageVideosScreen())),
      GoRoute(path: '/admin/notes', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const ManageNotesScreen())),
      GoRoute(path: '/admin/promos', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const ManagePromosScreen())),
      GoRoute(path: '/admin/class-requests', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const ManageClassRequestsScreen())),
      GoRoute(path: '/admin/flashcards', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const ManageFlashcardsScreen())),
      GoRoute(path: '/admin/users', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const ManageUsersScreen())),
      GoRoute(path: '/admin/plans', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const ManagePlansScreen())),
      GoRoute(path: '/admin/payments', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const ManagePaymentsScreen())),
      GoRoute(path: '/admin/announcements', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const ManageAnnouncementsScreen())),
      GoRoute(path: '/admin/analytics', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const AdminAnalyticsScreen())),
      GoRoute(path: '/superadmin', pageBuilder: (context, state) => _buildFadeSlidePage(state: state, child: const SuperAdminScreen())),
    ],
  );
});
