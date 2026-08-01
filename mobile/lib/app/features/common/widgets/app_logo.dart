import 'package:flutter/material.dart';

/// Official StudyBook logo widget.
/// Uses the uploaded brand asset — never renders a placeholder.
/// [size] controls the displayed height; width is auto-sized to preserve aspect ratio.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/studybook_logo.png',
      height: size,
      fit: BoxFit.contain,
    );
  }
}
