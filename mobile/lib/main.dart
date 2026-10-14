import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/core/api/dio_client.dart';
import 'app/core/config/firebase_config.dart';
import 'app/core/theme/app_colors.dart';
import 'app/core/theme/app_theme.dart';
import 'app/features/auth/providers/auth_provider.dart';
import 'app/features/common/routes/app_router.dart';

void main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Keep recoverable framework/plugin exceptions from terminating the
    // process without diagnostics on release builds.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('[FLUTTER ERROR] ${details.exceptionAsString()}');
      debugPrintStack(stackTrace: details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('[UNCAUGHT ASYNC ERROR] $error');
      debugPrintStack(stackTrace: stack);
      return true;
    };

    try {
      await FirebaseConfig.initialize().timeout(const Duration(seconds: 15));
    } catch (error, stack) {
      // Password login and cached sessions must continue even if Firebase is
      // unavailable. OTP will display a specific configuration/network error.
      debugPrint('[FIREBASE STARTUP] $error');
      debugPrintStack(stackTrace: stack);
    }

    try {
      dioClient = await DioClient.create().timeout(const Duration(seconds: 15));
    } catch (error, stack) {
      debugPrint('[APP STARTUP] $error');
      debugPrintStack(stackTrace: stack);
      runApp(_StartupFailureApp(error: error.toString()));
      return;
    }

    runApp(
      const ProviderScope(
        child: CMathsApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('[UNCAUGHT ZONE ERROR] $error');
    debugPrintStack(stackTrace: stack);
  });
}

class _StartupFailureApp extends StatelessWidget {
  final String error;

  const _StartupFailureApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 52, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'C Maths could not start',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please restart the app. If the problem continues, check internet access and update the app.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom back button dispatcher that implements double-back-to-exit.
///
/// GoRouter on Android 14+ defers to the OS when the route stack has nothing
/// to pop, causing immediate exit. This dispatcher intercepts the back button
/// at the app level, shows a snackbar on first press, and exits on second
/// press within 2 seconds.
class CMathsBackButtonDispatcher extends RootBackButtonDispatcher {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  DateTime? _lastBackPress;

  CMathsBackButtonDispatcher({required this.scaffoldMessengerKey});

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

class CMathsApp extends ConsumerStatefulWidget {
  const CMathsApp({super.key});

  @override
  ConsumerState<CMathsApp> createState() => _CMathsAppState();
}

class _CMathsAppState extends ConsumerState<CMathsApp>
    with WidgetsBindingObserver {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  late final CMathsBackButtonDispatcher _backButtonDispatcher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _backButtonDispatcher = CMathsBackButtonDispatcher(
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
      title: 'C Maths',
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
