import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:makco/models/models.dart';
import 'package:makco/router.dart';
import 'package:makco/screens/home_screen.dart';
import 'package:makco/screens/ticket_screen.dart';
import 'package:makco/state/catalog.dart';
import 'package:makco/state/recents.dart';
import 'package:makco/state/session.dart';
import 'package:makco/theme/madras_flow.dart';

class _FakeSession extends SessionController {
  @override
  SessionState build() => SessionState(
    booted: true,
    authenticated: true,
    profile: Profile(id: 'u1', maskedMobile: '+91 ••••• 6721', gender: 'MALE'),
  );
}

class _EmptyRecents extends RecentsController {
  @override
  List<RecentTrip> build() => const [];
}

final _stations = [
  Station(code: 'AAA|01', name: 'Alpha Metro'),
  Station(code: 'BBB|02', name: 'Beta Metro'),
];

Widget _homeApp() => ProviderScope(
  overrides: [
    sessionProvider.overrideWith(_FakeSession.new),
    recentsProvider.overrideWith(_EmptyRecents.new),
    stationsProvider.overrideWith((ref) async => _stations),
    ticketsProvider.overrideWith((ref) async => <dynamic>[]),
  ],
  child: MaterialApp(
    theme: Mf.theme(),
    home: const Scaffold(body: SafeArea(child: HomeScreen())),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
  });

  testWidgets('home renders the one-screen booking card', (tester) async {
    await tester.pumpWidget(_homeApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Where to today?'), findsOneWidget);
    expect(find.text('Choose your start'), findsOneWidget);
    expect(find.text('Choose your destination'), findsOneWidget);
    expect(find.text('CHENNAI METRO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('station picker opens and lists stations', (tester) async {
    await tester.pumpWidget(_homeApp());
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose your start'));
    await tester.pumpAndSettle();

    expect(find.text('Where are you starting?'), findsOneWidget);
    expect(find.text('Alpha Metro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favourites filter keeps starred stations', (tester) async {
    await tester.pumpWidget(_homeApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose your start'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star_border_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favourites (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha Metro'), findsOneWidget);
    expect(find.text('Beta Metro'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fresh install lands on the phone sign-in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            theme: Mf.theme(),
            routerConfig: ref.watch(routerProvider),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in with your number'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('router boots signed-in users into the shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_FakeSession.new),
          recentsProvider.overrideWith(_EmptyRecents.new),
          stationsProvider.overrideWith((ref) async => _stations),
          ticketsProvider.overrideWith((ref) async => <dynamic>[]),
        ],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            theme: Mf.theme(),
            routerConfig: ref.watch(routerProvider),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Where to today?'), findsOneWidget);
    expect(find.text('Tickets'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmed ticket renders a QR code', (tester) async {
    const qrData = 'c2lnbmF0dXJl,TKT-123,AAA|01,BBB|02,1,0,METRO,24';
    final booking = Booking(
      bookingId: 'b1',
      status: 'CONFIRMED',
      price: 24,
      tickets: [
        {
          'ticketNumber': 'TKT-123',
          'qrData': qrData,
          'fromStation': 'Alpha Metro',
          'toStation': 'Beta Metro',
          'routeName': 'Blue Line',
        },
      ],
      stations: const [
        {'name': 'Alpha Metro'},
        {'name': 'Beta Metro'},
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: Mf.theme(),
          home: TicketScreen(booking: booking),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(booking.qrData, qrData);
    expect(booking.ticketNumber, 'TKT-123');
    expect(booking.fromName, 'Alpha Metro');
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('TICKET TKT-123'), findsOneWidget);
    expect(find.text('Ticket ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
