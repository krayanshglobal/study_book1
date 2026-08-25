import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/core/api/dio_client.dart';
import 'app/core/theme/app_colors.dart';
import 'app/core/theme/app_theme.dart';
import 'app/features/auth/providers/auth_provider.dart';
import 'app/features/common/routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the cookie-based Dio client once at startup
  dioClient = await DioClient.create();

  runApp(
    const ProviderScope(
      child: StudyBookApp(),
    ),
  );
}

/// Custom back button dispatcher that implements double-back-to-exit.
///
/// GoRouter on Android 14+ defers to the OS when the route stack has nothing
/// to pop, causing immediate exit. This dispatcher intercepts the back button
/// at the app level, shows a snackbar on first press, and exits on second
/// press within 2 seconds.
class StudyBookBackButtonDispatcher extends RootBackButtonDispatcher {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  DateTime? _lastBackPress;

  StudyBookBackButtonDispatcher({required this.scaffoldMessengerKey});

  @override
  Future<bool> didPopRoute() async {
    // Try to let GoRouter handle the pop first (e.g., child pages → pop to parent)
    final routerHandled = await super.didPopRoute();
    if (routerHandled) return true;

    // GoRouter couldn't pop — we're on a root screen.
    // Implement double-back-to-exit.
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      scaffoldMessengerKey.currentState?.clearSnackBars();
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            'Press back again to exit',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.navy,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      // Return true = we handled it (don't let OS exit the app)
      return true;
    } else {
      // Second press within 2 seconds → exit the app
      _lastBackPress = null;
      await SystemNavigator.pop();
      return true;
    }
  }
}

class StudyBookApp extends ConsumerStatefulWidget {
  const StudyBookApp({super.key});

  @override
  ConsumerState<StudyBookApp> createState() => _StudyBookAppState();
}

class _StudyBookAppState extends ConsumerState<StudyBookApp>
    with WidgetsBindingObserver {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  late final StudyBookBackButtonDispatcher _backButtonDispatcher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _backButtonDispatcher = StudyBookBackButtonDispatcher(
      scaffoldMessengerKey: _scaffoldMessengerKey,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called whenever the app lifecycle changes. On resume, silently refresh
  /// the user profile so that a premium upgrade granted while the app was
  /// backgrounded is reflected immediately — no restart required.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      ref.read(authProvider.notifier).refreshSilently();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'StudyBook',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
      backButtonDispatcher: _backButtonDispatcher,
      scaffoldMessengerKey: _scaffoldMessengerKey,
    );
  }
}
