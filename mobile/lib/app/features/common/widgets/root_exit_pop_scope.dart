import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// Wraps root screens (Landing, Login, etc.) to handle system back gesture
/// with double-tap exit confirmation via SnackBar.
class RootExitPopScope extends StatefulWidget {
  final Widget child;

  const RootExitPopScope({super.key, required this.child});

  @override
  State<RootExitPopScope> createState() => _RootExitPopScopeState();
}

class _RootExitPopScopeState extends State<RootExitPopScope> {
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _lastBackPressed = null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        // 1. Close drawer if open
        final scaffoldState = Scaffold.maybeOf(context);
        if (scaffoldState != null && scaffoldState.isDrawerOpen) {
          scaffoldState.closeDrawer();
          return;
        }

        // 2. Double back press exit confirmation
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Press back again to exit',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.navy,
            ),
          );
          return;
        }

        // 3. Exit application if pressed twice within 2 seconds
        _lastBackPressed = null;
        SystemNavigator.pop();
      },
      child: widget.child,
    );
  }
}
