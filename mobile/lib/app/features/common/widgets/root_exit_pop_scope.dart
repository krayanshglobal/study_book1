import 'package:flutter/material.dart';

/// Compatibility wrapper for root screens.
///
/// Back handling is centralized in [CMathsBackButtonDispatcher] at the app
/// level. A second PopScope used to trigger an additional SystemNavigator.pop,
/// which could close the app unexpectedly on some Android versions.
class RootExitPopScope extends StatelessWidget {
  final Widget child;

  const RootExitPopScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
