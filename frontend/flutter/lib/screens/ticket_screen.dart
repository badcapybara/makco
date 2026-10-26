import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:makco/models/models.dart';
import 'package:makco/services/api_service.dart';
import 'package:makco/services/cache.dart';
import 'package:makco/state/catalog.dart';
import 'package:makco/state/ride.dart';
import 'package:makco/theme/madras_flow.dart';
import 'package:makco/widgets/madras_components.dart';

/// Confirmed ticket with a scannable QR. Can also resolve a ticket deep link.
class TicketScreen extends ConsumerStatefulWidget {
  final Booking? booking;
  final String? ticketRef;

  const TicketScreen({super.key, this.booking, this.ticketRef});

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> {
  Booking? _booking;
  String? _error;
  bool _loading = false;
  Timer? _timer;
  int _tries = 0;
  bool _timedOut = false;
  bool _notFound = false;
  String? _pollError;
  static const _maxTries = 30;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    if (_booking == null) {
      _resolveFromRef();
    } else {
      _startPollingIfNeeded();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resolveFromRef() async {
    final ticketRef = widget.ticketRef;
    if (ticketRef == null || ticketRef.isEmpty) {
      setState(() => _error = 'No ticket reference was provided.');
      return;
    }
    setState(() => _loading = true);
    try {
      final tickets = await ref.read(ticketsProvider.future);
      Map<String, dynamic>? match;
      for (final raw in tickets) {
        if (raw is! Map) continue;
        final ticket = Map<String, dynamic>.from(raw);
        if (_matchesRef(ticket, ticketRef)) {
          match = ticket;
          break;
        }
      }
      if (!mounted) return;
      if (match == null) {
        setState(() {
          _loading = false;
          _error = 'We could not find ticket $ticketRef on this account.';
        });
        return;
      }
      setState(() {
        _booking = Booking.fromTicket(match!);
        _loading = false;
      });
      _startPollingIfNeeded();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this ticket. Check your connection.';
      });
    }
  }

  bool _matchesRef(Map<String, dynamic> raw, String ref) {
    if ((raw['bookingId']?.toString() ?? '') == ref) return true;
    final direct = raw['ticketNumber'] ?? raw['ticketNo'] ?? raw['ticketRef'];
    if (direct is List) {
      if (direct.any((value) => value?.toString() == ref)) return true;
    } else if (direct?.toString() == ref) {
      return true;
    }
    final nested = raw['tickets'];
    if (nested is List) {
      for (final ticket in nested) {
        if (ticket is Map &&
            _matchesRef(Map<String, dynamic>.from(ticket), ref)) {
          return true;
        }
      }
    }
    return false;
  }

  void _startPollingIfNeeded() {
    final booking = _booking;
    if (booking == null) return;
    if (booking.tickets.isNotEmpty && booking.qrData.isNotEmpty) return;
    if (booking.bookingId.isEmpty) return;
    _timer?.cancel();
    _tries = 0;
    _timedOut = false;
    _notFound = false;
    _pollError = null;
    unawaited(_poll());
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _retryQr() async => _startPollingIfNeeded();

  void _openPayment() {
    final booking = _booking;
    if (booking == null || booking.paymentUrl.isEmpty) return;
    _timer?.cancel();
    context.pushReplacement('/payment', extra: booking);
  }

  Future<void> _poll() async {
    final booking = _booking;
    if (booking == null) return;
    if (_tries >= _maxTries) {
      _timer?.cancel();
      if (mounted && !_timedOut) setState(() => _timedOut = true);
      return;
    }
    _tries++;
    Booking updated;
    try {
      updated = await Api.bookingStatus(
        booking.bookingId,
        mode: TransitMode.metro.key,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final notFound = e.status == 404;
      setState(() {
        _notFound = notFound;
        _pollError = notFound
            ? 'This booking is no longer available.'
            : e.message;
        _timedOut = notFound || _tries >= _maxTries;
      });
      if (_timedOut) _timer?.cancel();
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pollError = 'Could not reach the server.';
        _timedOut = _tries >= _maxTries;
      });
      if (_timedOut) _timer?.cancel();
      return;
    }
    if (!mounted) return;
    final ready = updated.confirmed || updated.tickets.isNotEmpty;
    final status = updated.status.toUpperCase();
    final failed =
        updated.paymentFailed ||
        updated.expired ||
        status == 'CANCELLED' ||
        status == 'FAILED' ||
        status == 'EXPIRED' ||
        status == 'PAYMENT_FAILED';
    final timedOut = !ready && !failed && _tries >= _maxTries;
    if (ready || failed || timedOut) _timer?.cancel();
    await Cache.saveBookingSnapshot(updated);
    if (ready || failed) ref.invalidate(ticketsProvider);
    setState(() {
      _booking = updated;
      _pollError = null;
      _timedOut = timedOut;
    });
  }

  bool get _ready =>
      _booking != null && (_booking!.confirmed || _booking!.tickets.isNotEmpty);

  bool get _failed {
    final booking = _booking;
    if (booking == null || _ready) return false;
    final status = booking.status.toUpperCase();
    return _notFound ||
        booking.paymentFailed ||
        booking.expired ||
        status == 'CANCELLED' ||
        status == 'FAILED' ||
        status == 'EXPIRED' ||
        status == 'PAYMENT_FAILED';
  }

  String get _waitingStatus {
    final status = _booking?.status ?? '';
    final payment = _booking?.paymentStatus ?? '';
    if (status.isEmpty && payment.isEmpty) return '';
    if (payment.isEmpty) return status;
    return '$status · payment $payment';
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _bookAnother() {
    ref.read(rideProvider.notifier).reset();
    context.go('/home');
  }

  String? get _qrData {
    final data = _booking?.qrData ?? '';
    return data.isEmpty ? null : data;
  }

  String? get _validTillText {
    final raw = _booking?.validTill;
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final suffix = parsed.hour < 12 ? 'AM' : 'PM';
    return 'Valid till $hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _booking?.firstTicket;
    final from = _booking?.fromName ?? 'Chennai Metro';
    final to = _booking?.toName ?? 'Your ride';
    final routeValue = ticket?['routeName'];
    final route = routeValue is String ? routeValue : null;

    return Scaffold(
      backgroundColor: Mf.paper,
      appBar: AppBar(
        backgroundColor: Mf.paper,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: _close,
          icon: const Icon(Icons.close_rounded),
        ),
        actions: [
          if (_ready)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Center(
                child: StatusChip('Confirmed', kind: StatusKind.success),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Mf.teal))
            : _booking == null
            ? _message(
                icon: Icons.confirmation_number_outlined,
                title: 'Ticket unavailable',
                body: _error ?? 'Start a booking to get a ticket.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                children: [
                  const Center(child: GopuramMark(width: 86)),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      _ready
                          ? 'Ticket ready'
                          : _failed
                          ? 'Payment not completed'
                          : _timedOut
                          ? 'Still waiting for the ticket'
                          : 'Confirming your ticket',
                      style: Mf.display(28),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      _ready
                          ? 'Show this at the gate.'
                          : _failed
                          ? 'No ticket was issued for this booking.'
                          : _timedOut
                          ? 'The operator has not issued the QR yet.'
                          : 'This updates automatically in a moment.',
                      style: Mf.body(14, color: Mf.inkMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TicketCard(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RouteRow(from: from, to: to, meta: route),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Mf.hairline),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fare',
                                    style: Mf.body(12, color: Mf.inkFaint),
                                  ),
                                  const SizedBox(height: 2),
                                  FareTag(_booking!.price, size: 34),
                                ],
                              ),
                            ),
                            if (_booking!.tickets.length > 1)
                              Text(
                                '${_booking!.tickets.length} tickets',
                                style: Mf.body(13, color: Mf.inkMuted),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        if (_ready && _qrData != null)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Mf.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Mf.hairline,
                                  width: 1.4,
                                ),
                              ),
                              child: QrImageView(
                                data: _qrData!,
                                version: QrVersions.auto,
                                size: 184,
                                gapless: true,
                                backgroundColor: Mf.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Mf.ink,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Mf.ink,
                                ),
                              ),
                            ),
                          )
                        else if (_ready)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 42,
                                    color: Mf.inkFaint,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Ticket confirmed, but the QR is not here yet.',
                                    style: Mf.body(13, color: Mf.inkMuted),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  GhostButton(
                                    'Refresh ticket',
                                    onPressed: _retryQr,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_failed)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 42,
                                    color: Mf.coral,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _waitingStatus.isEmpty
                                        ? 'This booking did not complete.'
                                        : _waitingStatus,
                                    style: Mf.body(13, color: Mf.inkMuted),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_timedOut)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    size: 42,
                                    color: Mf.inkFaint,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _pollError ??
                                        (_waitingStatus.isEmpty
                                            ? 'The ticket is taking longer than expected.'
                                            : 'Ticket status: $_waitingStatus'),
                                    style: Mf.body(13, color: Mf.inkMuted),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  if (_booking!.paymentUrl.isNotEmpty)
                                    GhostButton(
                                      'Complete payment',
                                      onPressed: _openPayment,
                                    ),
                                  if (_booking!.paymentUrl.isNotEmpty)
                                    const SizedBox(height: 8),
                                  GhostButton(
                                    'Check again',
                                    onPressed: _retryQr,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                children: [
                                  const SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Mf.teal,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Waiting for the ticket…',
                                    style: Mf.body(13, color: Mf.inkMuted),
                                  ),
                                  if (_waitingStatus.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _waitingStatus,
                                      style: Mf.body(12, color: Mf.inkFaint),
                                    ),
                                  ],
                                  if (_booking!.paymentUrl.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    GhostButton(
                                      'Complete payment',
                                      onPressed: _openPayment,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        if (_ready && _booking!.ticketNumber.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Center(
                            child: Text(
                              'TICKET ${_booking!.ticketNumber}',
                              style: Mf.overline(
                                color: Mf.inkFaint,
                              ).copyWith(letterSpacing: 1.2),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        if (_validTillText != null) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              _validTillText!,
                              style: Mf.body(13, color: Mf.teal),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    'Book another ride',
                    icon: Icons.add_rounded,
                    onPressed: _bookAnother,
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton('Done', onPressed: _close),
                ],
              ),
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Mf.inkFaint),
            const SizedBox(height: 16),
            Text(title, style: Mf.display(24), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              body,
              style: Mf.body(14, color: Mf.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              'Back to booking',
              onPressed: () => context.go('/home'),
            ),
          ],
        ),
      ),
    );
  }
}
