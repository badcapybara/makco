import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:makco/router.dart';
import 'package:makco/theme/madras_flow.dart';

void main() {
  runApp(const ProviderScope(child: MakcoApp()));
}

class MakcoApp extends ConsumerWidget {
  const MakcoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'MAKCO',
      debugShowCheckedModeBanner: false,
      theme: Mf.theme(),
      routerConfig: router,
    );
  }
}
