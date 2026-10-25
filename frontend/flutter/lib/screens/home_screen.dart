import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:makco/models/models.dart';
import 'package:makco/services/api_service.dart';
import 'package:makco/state/catalog.dart';
import 'package:makco/state/recents.dart';
import 'package:makco/state/ride.dart';
import 'package:makco/state/session.dart';
import 'package:makco/theme/madras_flow.dart';
import 'package:makco/widgets/madras_components.dart';
import 'package:makco/widgets/ticket_tile.dart';

import 'station_picker.dart';

/// The Book tab: one screen from "where to?" to fares and payment.
class HomeScreen extends ConsumerWidget {
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenTickets;

  const HomeScreen({super.key, this.onOpenProfile, this.onOpenTickets});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(stationsProvider);
    ref.invalidate(ticketsProvider);
    try {
      await ref.read(stationsProvider.future);
    } catch (_) {}
    try {
      await ref.read(ticketsProvider.future);
    } catch (_) {}
    await ref.read(sessionProvider.notifier).refreshProfile();
  }

  Future<void> _pickStation(
    BuildContext context,
    WidgetRef ref,
    bool isFrom,
  ) async {
    var async = ref.read(stationsProvider);
    if (async.isLoading) {
      _snack(context, 'Loading metro stations…');
      try {
        await ref.read(stationsProvider.future);
      } catch (_) {}
      if (!context.mounted) return;
      async = ref.read(stationsProvider);
    }
    final stations = async.value ?? const <Station>[];
    if (stations.isEmpty) {
      _snack(context, 'Stations are unavailable. Pull down to retry.');
      return;
    }

    final picked = await showStationPicker(
      context,
      stations,
      title: isFrom ? 'Where are you starting?' : 'Where are you headed?',
    );
    if (picked == null || !context.mounted) return;

    final controller = ref.read(rideProvider.notifier);
    if (isFrom) {
      controller.pickFrom(picked);
    } else {
      controller.pickTo(picked);
    }
  }

  Future<void> _pay(BuildContext context, WidgetRef ref, Quote quote) async {
    try {
      final booking = await ref.read(rideProvider.notifier).confirm(quote);
      if (!context.mounted) return;
      if (booking.paymentUrl.isNotEmpty) {
        context.push('/payment', extra: booking);
      } else {
        ref.invalidate(ticketsProvider);
        context.push('/ticket', extra: booking);
      }
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (_) {
      if (context.mounted) {
        _snack(context, 'Could not start the payment. Try again.');
      }
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: Mf.body(14, color: Mf.surface)),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(stationsProvider);
    final ride = ref.watch(rideProvider);
    final profile = ref.watch(sessionProvider).profile;
    final tickets = ref.watch(ticketsProvider).value ?? const [];
    final recents = ref.watch(recentsProvider);
    final recentTickets = tickets.take(3).toList();

    return RefreshIndicator(
      color: Mf.teal,
      onRefresh: () => _refresh(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          _header(context),
          const SizedBox(height: 24),
          _greeting(ride, profile),
          const SizedBox(height: 18),
          _bookingCard(context, ref, ride),
          const SizedBox(height: 14),
          if (ride.searching)
            const _SearchingFares()
          else if (ride.error != null)
            _FareError(
              message: ride.error!,
              onRetry: () => ref.read(rideProvider.notifier).search(),
            )
          else if (ride.quotes.isNotEmpty)
            _fares(context, ref, ride),
          if (recents.isNotEmpty) ...[
            const SizedBox(height: 28),
            _SectionHeader(
              title: 'Repeat a trip',
              trailing: '${recents.length} saved',
            ),
            const SizedBox(height: 12),
            for (final trip in recents.take(3)) ...[
              _RecentTripCard(
                trip: trip,
                onTap: () => ref.read(rideProvider.notifier).loadTrip(trip),
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (recentTickets.isNotEmpty) ...[
            const SizedBox(height: 22),
            _SectionHeader(
              title: 'Recent tickets',
              trailing: 'See all',
              onTrailing: onOpenTickets,
            ),
            const SizedBox(height: 12),
            for (final raw in recentTickets) ...[
              Builder(
                builder: (context) {
                  final ticket = Map<String, dynamic>.from(raw as Map);
                  return TicketTile(
                    ticket: ticket,
                    dense: true,
                    onTap: () => context.push(
                      '/ticket',
                      extra: Booking.fromTicket(ticket),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (recentTickets.isEmpty && recents.isEmpty) ...[
            const SizedBox(height: 24),
            const _FirstRideCard(),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const GopuramMark(width: 26, color: Mf.amber),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MAKCO', style: Mf.display(22, color: Mf.ink)),
            Text(
              'CHENNAI METRO',
              style: Mf.overline(
                color: Mf.inkFaint,
              ).copyWith(fontSize: 9, letterSpacing: 1.4),
            ),
          ],
        ),
        const Spacer(),
        const StatusChip('Metro', kind: StatusKind.info),
        const SizedBox(width: 8),
        Material(
          color: Mf.surface,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onOpenProfile,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.person_outline_rounded,
                size: 21,
                color: Mf.teal,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _greeting(RideState ride, Profile? profile) {
    final hour = DateTime.now().hour;
    final part = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(part.toUpperCase(), style: Mf.overline(color: Mf.teal)),
        const SizedBox(height: 4),
        Text(
          ride.ready ? 'Fares are ready.' : 'Where to today?',
          style: Mf.display(30, color: Mf.ink),
        ),
        const SizedBox(height: 6),
        Text(
          profile == null
              ? 'Pick a start and a stop — fares appear instantly.'
              : 'Riding as ${profile.maskedMobile}',
          style: Mf.body(14, color: Mf.inkMuted),
        ),
      ],
    );
  }

  Widget _bookingCard(BuildContext context, WidgetRef ref, RideState ride) {
    return TicketCard(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        children: [
          _StationRow(
            tag: 'FROM',
            station: ride.from,
            hint: 'Choose your start',
            icon: Icons.trip_origin_rounded,
            onTap: () => _pickStation(context, ref, true),
          ),
          _ConnectorRow(
            onSwap: ride.from != null && ride.to != null
                ? () => ref.read(rideProvider.notifier).swap()
                : null,
          ),
          _StationRow(
            tag: 'TO',
            station: ride.to,
            hint: 'Choose your destination',
            icon: Icons.location_on_outlined,
            onTap: () => _pickStation(context, ref, false),
          ),
          const Divider(height: 1, thickness: 1, color: Mf.hairline),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.confirmation_number_outlined,
                  size: 18,
                  color: Mf.teal,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tickets',
                  style: Mf.body(
                    14,
                    color: Mf.inkMuted,
                    weight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _StepButton(
                  icon: Icons.remove_rounded,
                  onTap: ride.quantity > 1
                      ? () => ref
                            .read(rideProvider.notifier)
                            .setQuantity(ride.quantity - 1)
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '${ride.quantity}',
                    style: Mf.display(18, color: Mf.ink),
                  ),
                ),
                _StepButton(
                  icon: Icons.add_rounded,
                  onTap: ride.quantity < 10
                      ? () => ref
                            .read(rideProvider.notifier)
                            .setQuantity(ride.quantity + 1)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fares(BuildContext context, WidgetRef ref, RideState ride) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Fares',
          trailing: '${ride.quotes.length} options',
        ),
        const SizedBox(height: 12),
        for (final quote in ride.quotes) ...[
          _FareCard(
            quote: quote,
            quantity: ride.quantity,
            busy: ride.confirmingQuoteId == quote.quoteId,
            disabled: ride.confirmingQuoteId != null,
            onPay: () => _pay(context, ref, quote),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _StationRow extends StatelessWidget {
  final String tag;
  final Station? station;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  const _StationRow({
    required this.tag,
    required this.station,
    required this.hint,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: station == null ? Mf.surfaceAlt : Mf.tealSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: station == null ? Mf.inkFaint : Mf.teal,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tag, style: Mf.overline(color: Mf.inkFaint)),
                  const SizedBox(height: 3),
                  Text(
                    station?.name ?? hint,
                    style: Mf.body(
                      18,
                      color: station == null ? Mf.inkFaint : Mf.ink,
                      weight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Mf.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _ConnectorRow extends StatelessWidget {
  final VoidCallback? onSwap;

  const _ConnectorRow({this.onSwap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 17, child: Center(child: _DottedLine())),
        const Spacer(),
        if (onSwap != null)
          TextButton.icon(
            onPressed: onSwap,
            style: TextButton.styleFrom(
              foregroundColor: Mf.teal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.swap_vert_rounded, size: 17),
            label: Text('Swap', style: Mf.body(12, color: Mf.teal)),
          ),
      ],
    );
  }
}

class _DottedLine extends StatelessWidget {
  const _DottedLine();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 2,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 1.5),
            color: Mf.hairline,
          ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Mf.surfaceAlt,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? Mf.inkFaint : Mf.ink,
        ),
      ),
    );
  }
}

class _FareCard extends StatelessWidget {
  final Quote quote;
  final int quantity;
  final bool busy;
  final bool disabled;
  final VoidCallback onPay;

  const _FareCard({
    required this.quote,
    required this.quantity,
    required this.busy,
    required this.disabled,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final total = quote.price * quantity;
    final label = quote.type.toLowerCase().contains('return')
        ? 'RETURN'
        : 'SINGLE';
    return TicketCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(label, kind: StatusKind.info),
              const Spacer(),
              if (quantity > 1)
                Text(
                  '₹${quote.price.round()} × $quantity',
                  style: Mf.body(12, color: Mf.inkMuted),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: Mf.overline(color: Mf.inkFaint)),
                    const SizedBox(height: 2),
                    FareTag(total, size: 32),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: PrimaryButton(
                  'Pay ₹${total.round()}',
                  onPressed: disabled ? null : onPay,
                  busy: busy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchingFares extends StatelessWidget {
  const _SearchingFares();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Mf.teal),
            ),
            const SizedBox(width: 10),
            Text(
              'Finding live fares…',
              style: Mf.body(14, color: Mf.inkMuted, weight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const SkeletonCard(height: 96),
        const SizedBox(height: 10),
        const SkeletonCard(height: 96),
      ],
    );
  }
}

class _FareError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FareError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return TicketCard(
      color: Mf.coralSoft,
      border: Border.all(color: Mf.coral.withValues(alpha: 0.25)),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 20, color: Mf.coral),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Mf.body(13, color: Mf.ink, weight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: Mf.coral),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _RecentTripCard extends StatelessWidget {
  final RecentTrip trip;
  final VoidCallback onTap;

  const _RecentTripCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TicketCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Mf.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.replay_rounded, size: 18, color: Mf.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trip.fromName} → ${trip.toName}',
                  style: Mf.body(14, weight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${trip.quantity} ticket${trip.quantity == 1 ? '' : 's'} · tap to repeat',
                  style: Mf.body(12, color: Mf.inkMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Mf.inkFaint),
        ],
      ),
    );
  }
}

class _FirstRideCard extends StatelessWidget {
  const _FirstRideCard();

  @override
  Widget build(BuildContext context) {
    return TicketCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Mf.amber,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.waving_hand_outlined,
              size: 20,
              color: Mf.ink,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your first ride', style: Mf.display(18)),
                const SizedBox(height: 4),
                Text(
                  'Pick a start and a destination above. Live fares show up here in seconds.',
                  style: Mf.body(13, color: Mf.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String trailing;
  final VoidCallback? onTrailing;

  const _SectionHeader({
    required this.title,
    required this.trailing,
    this.onTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Mf.display(20, color: Mf.ink)),
        ),
        if (onTrailing == null)
          Text(trailing, style: Mf.overline(color: Mf.inkFaint))
        else
          TextButton(
            onPressed: onTrailing,
            style: TextButton.styleFrom(
              foregroundColor: Mf.teal,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
            ),
            child: Text(
              trailing,
              style: Mf.body(13, color: Mf.teal, weight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}
