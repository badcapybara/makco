import 'package:flutter/material.dart';

import 'package:makco/theme/madras_flow.dart';
import 'package:makco/widgets/madras_components.dart';

/// Brand splash while the stored session is restored by the session provider.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GopuramMark(width: 72, color: Mf.amber),
            const SizedBox(height: 18),
            Text('MAKCO', style: Mf.display(36, color: Mf.ink)),
            const SizedBox(height: 10),
            Text(
              'Chennai transit, made easy.',
              style: Mf.body(15, color: Mf.inkMuted),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Mf.teal),
            ),
          ],
        ),
      ),
    );
  }
}
