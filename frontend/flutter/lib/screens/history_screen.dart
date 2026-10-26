import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:makco/models/models.dart';
import 'package:makco/state/catalog.dart';
import 'package:makco/theme/madras_flow.dart';
import 'package:makco/widgets/madras_components.dart';
import 'package:makco/widgets/ticket_tile.dart';

/// The Tickets tab — active and past bookings.
class HistoryScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBook;
  final int refreshKey;

  const HistoryScreen({super.key, this.onBook, this.refreshKey = 0});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with WidgetsBindingObserver {
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshKey != oldWidget.refreshKey) {
      unawaited(_refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(ticketsProvider);
    try {
      await ref.read(ticketsProvider.future);
    } catch (_) {}
  }

  bool _isActive(Map<String, dynamic> ticket) {
    final status = ticketStatus(ticket);
    return status == 'CONFIRMED' ||
        status == 'SUCCESS' ||
        status == 'VALID' ||
        status == 'ACTIVE' ||
        status == 'NEW' ||
        status == 'PENDING' ||
        status == 'PAYMENT_PENDING' ||
        status == 'PROCESSING' ||
        status == 'APPROVED';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ticketsProvider);
    final all = (async.value ?? const [])
        .whereType<Map>()
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
    final active = all.where(_isActive).toList();
    final past = all.where((t) => !_isActive(t)).toList();

    final visible = switch (_filter) {
      1 => active,
      2 => past,
      _ => all,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tickets', style: Mf.display(28, color: Mf.ink)),
                    const SizedBox(height: 4),
                    Text(
                      all.isEmpty
                          ? 'Your rides live here'
                          : '${all.length} booking${all.length == 1 ? '' : 's'}',
                      style: Mf.body(14, color: Mf.inkMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: async.isLoading ? null : _refresh,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded, color: Mf.teal),
              ),
            ],
          ),
        ),
        if (all.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _FilterPill(
                  label: 'All',
                  count: all.length,
                  selected: _filter == 0,
                  onTap: () => setState(() => _filter = 0),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'Active',
                  count: active.length,
                  selected: _filter == 1,
                  onTap: () => setState(() => _filter = 1),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'Past',
                  count: past.length,
                  selected: _filter == 2,
                  onTap: () => setState(() => _filter = 2),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            color: Mf.teal,
            onRefresh: _refresh,
            child: _body(async, visible),
          ),
        ),
      ],
    );
  }

  Widget _body(
    AsyncValue<List<dynamic>> async,
    List<Map<String, dynamic>> tickets,
  ) {
    if (async.isLoading && async.value == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: const [
          SkeletonCard(height: 120),
          SizedBox(height: 12),
          SkeletonCard(height: 120),
          SizedBox(height: 12),
          SkeletonCard(height: 120),
        ],
      );
    }

    if (async.hasError) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.cloud_off_outlined, size: 46, color: Mf.inkFaint),
          const SizedBox(height: 16),
          Text(
            "Couldn't load your tickets",
            style: Mf.display(22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '${async.error}',
            style: Mf.body(14, color: Mf.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: GhostButton('Try again', onPressed: _refresh),
          ),
        ],
      );
    }

    if (tickets.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const SizedBox(height: 40),
          const Icon(
            Icons.confirmation_number_outlined,
            size: 50,
            color: Mf.inkFaint,
          ),
          const SizedBox(height: 16),
          Text(
            _filter == 1
                ? 'No active tickets'
                : (_filter == 2 ? 'No past trips yet' : 'No trips yet'),
            style: Mf.display(22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Book a metro ride and your ticket will show up here.',
            style: Mf.body(14, color: Mf.inkMuted),
            textAlign: TextAlign.center,
          ),
          if (widget.onBook != null) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: PrimaryButton(
                'Book a ride',
                icon: Icons.arrow_forward_rounded,
                onPressed: widget.onBook,
              ),
            ),
          ],
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      itemCount: tickets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ticket = tickets[index];
        return TicketTile(
          ticket: ticket,
          onTap: () =>
              context.push('/ticket', extra: Booking.fromTicket(ticket)),
        );
      },
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Mf.ink : Mf.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            '$label · $count',
            style: Mf.body(
              12,
              color: selected ? Mf.paper : Mf.inkMuted,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
