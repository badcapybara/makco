import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/models.dart';
import 'screens/auth_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/ticket_screen.dart';
import 'state/session.dart';
import 'theme/madras_flow.dart';
import 'widgets/madras_components.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen<SessionState>(sessionProvider, (_, _) => refresh.value++);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;

      if (!session.booted) {
        return location == '/splash' ? null : '/splash';
      }
      if (!session.authenticated) {
        return location == '/auth' ? null : '/auth';
      }
      if (location == '/splash' || location == '/auth') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
      GoRoute(path: '/home', builder: (_, _) => const ShellScreen()),
      GoRoute(
        path: '/ticket',
        builder: (context, state) => TicketScreen(
          booking: state.extra is Booking ? state.extra as Booking : null,
          ticketRef: state.uri.queryParameters['ref'],
        ),
      ),
      GoRoute(
        path: '/payment',
        builder: (context, state) {
          final booking = state.extra;
          if (booking is! Booking) {
            return const _RouteMessage(
              icon: Icons.receipt_long_outlined,
              title: 'Payment session expired',
              message: 'Go back and start the booking again.',
            );
          }
          return PaymentScreen(booking: booking);
        },
      ),
    ],
  );
});

class _RouteMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _RouteMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Mf.paper,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 52, color: Mf.inkFaint),
                const SizedBox(height: 18),
                Text(title, style: Mf.display(24), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Mf.body(15, color: Mf.inkMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  'Back to booking',
                  onPressed: () => context.go('/home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
