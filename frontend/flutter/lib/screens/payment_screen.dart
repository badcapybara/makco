import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:makco/models/models.dart';
import 'package:makco/services/api_service.dart';
import 'package:makco/services/cache.dart';
import 'package:makco/state/catalog.dart';
import 'package:makco/theme/madras_flow.dart';
import 'package:makco/widgets/madras_components.dart';

/// Hosts the Juspay webview and watches the booking until the operator issues
/// the ticket. The webview is only the payment surface; the booking status is
/// always the source of truth.
class PaymentScreen extends ConsumerStatefulWidget {
  final Booking booking;

  const PaymentScreen({super.key, required this.booking});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  Timer? _pollTimer;
  Timer? _expiryTimer;
  bool _webLoading = true;
  bool _finished = false;
  bool _checking = false;
  bool _timedOut = false;
  bool _failed = false;
  String? _webError;
  String? _loadedUrl;
  String _status = 'Waiting for payment…';
  String _snapshotKey = '';

  static const _pollInterval = Duration(seconds: 2);
  static const _paymentWindow = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _webLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _webLoading = false);
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) return;
            setState(() {
              _webLoading = false;
              _webError = error.description.isEmpty
                  ? 'The payment page could not be loaded.'
                  : error.description;
            });
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            final scheme = uri?.scheme.toLowerCase() ?? '';
            // Keep the payment page itself in the webview. Hand UPI app
            // schemes (phonepe://, upi://, tez://, ...) to Android.
            if (scheme == 'http' ||
                scheme == 'https' ||
                scheme == 'about' ||
                scheme == 'data' ||
                scheme == 'blob') {
              return NavigationDecision.navigate;
            }
            unawaited(_openExternal(request.url));
            return NavigationDecision.prevent;
          },
        ),
      );

    final url = widget.booking.paymentUrl;
    if (url.isNotEmpty) {
      _loadPaymentPage(url);
    } else {
      _status = 'Preparing payment page…';
    }
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from PhonePe/GPay is the moment the status usually changes.
    if (state == AppLifecycleState.resumed && !_finished) {
      unawaited(_checkStatus(manual: true));
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _expiryTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkStatus());
    _expiryTimer = Timer(_paymentWindow, _onPaymentWindowClosed);
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
  }

  void _loadPaymentPage(String url) {
    if (url.isEmpty || _loadedUrl == url) return;
    _loadedUrl = url;
    _webError = null;
    _webLoading = true;
    _controller.loadRequest(Uri.parse(url));
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      _snack('No payment app found for this link. Choose another method.');
    }
  }

  Future<void> _openPaymentInBrowser() async {
    final url = widget.booking.paymentUrl.isNotEmpty
        ? widget.booking.paymentUrl
        : (_loadedUrl ?? '');
    if (url.isEmpty) {
      _snack('Payment link is not ready yet.');
      return;
    }
    await _openExternal(url);
  }

  Future<void> _checkStatus({bool manual = false}) async {
    if (_finished || _checking) return;
    if (manual) {
      _timedOut = false;
      _failed = false;
    }
    _checking = true;
    Booking updated;
    try {
      updated = await Api.bookingStatus(widget.booking.bookingId);
    } on ApiException catch (e) {
      _checking = false;
      if (!mounted || _finished) return;
      final notFound = e.status == 404;
      setState(() {
        _status = notFound ? 'This booking is no longer available.' : e.message;
        if (notFound) _failed = true;
      });
      if (notFound) {
        _stopPolling();
        ref.invalidate(ticketsProvider);
      }
      return;
    } catch (_) {
      _checking = false;
      if (!mounted || _finished) return;
      setState(() => _status = 'Could not check the payment status.');
      return;
    }
    _checking = false;
    if (!mounted || _finished) return;
    await _saveSnapshot(updated);
    if (!mounted || _finished) return;

    if (updated.confirmed || updated.tickets.isNotEmpty) {
      _finish();
      ref.invalidate(ticketsProvider);
      context.pushReplacement('/ticket', extra: updated);
      return;
    }

    final failed =
        updated.paymentFailed ||
        updated.expired ||
        const {
          'CANCELLED',
          'FAILED',
          'EXPIRED',
          'PAYMENT_FAILED',
        }.contains(updated.status.toUpperCase());

    setState(() {
      _status = _statusFor(updated);
      _failed = failed;
    });

    if (failed) {
      _stopPolling();
      ref.invalidate(ticketsProvider);
      return;
    }

    final link = updated.paymentUrl;
    if (link.isNotEmpty) {
      if (_loadedUrl == null || _webError != null) {
        _loadPaymentPage(link);
      } else if (_loadedUrl != link) {
        _loadPaymentPage(link);
      }
    }
  }

  String _statusFor(Booking booking) {
    switch (booking.status.toUpperCase()) {
      case 'CANCELLED':
      case 'FAILED':
      case 'EXPIRED':
      case 'PAYMENT_FAILED':
        return 'Payment was not completed.';
    }
    if (booking.paymentFailed) return 'Payment was not completed.';
    if (booking.paymentSucceeded) {
      return 'Payment received. Issuing ticket…';
    }
    switch (booking.status.toUpperCase()) {
      case 'APPROVED':
        return 'Payment approved. Issuing ticket…';
      case 'PAYMENT_PENDING':
        return 'Payment pending…';
      case 'NEW':
        return booking.paymentUrl.isNotEmpty
            ? 'Waiting for payment…'
            : 'Preparing payment page…';
    }
    if (booking.paymentStatus == 'PENDING') {
      return 'Payment pending…';
    }
    return 'Waiting for payment…';
  }

  void _onPaymentWindowClosed() {
    if (_finished) return;
    _stopPolling();
    setState(() {
      _timedOut = true;
      _status = 'Payment not confirmed yet.';
    });
  }

  Future<void> _retryPayment() async {
    final url = widget.booking.paymentUrl.isNotEmpty
        ? widget.booking.paymentUrl
        : (_loadedUrl ?? '');
    if (url.isEmpty) {
      await _checkStatus(manual: true);
      if (!mounted) return;
      final link = _loadedUrl;
      if (link == null) {
        _snack('Payment link is not ready. Tap Check status again.');
        return;
      }
      _startPolling();
      return;
    }
    setState(() {
      _failed = false;
      _timedOut = false;
      _webError = null;
      _status = 'Waiting for payment…';
      _loadedUrl = null;
    });
    _loadPaymentPage(url);
    _startPolling();
  }

  void _finish() {
    _finished = true;
    _stopPolling();
  }

  Future<void> _saveSnapshot(Booking booking) async {
    final key =
        '${booking.status}|${booking.paymentStatus}|${booking.paymentUrl}|'
        '${booking.tickets.length}';
    if (key == _snapshotKey) return;
    _snapshotKey = key;
    await Cache.saveBookingSnapshot(booking);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: Mf.body(14, color: Mf.surface)),
        ),
      );
  }

  StatusKind get _chipKind {
    if (_failed) return StatusKind.error;
    if (_status.startsWith('Payment received') ||
        _status.startsWith('Payment approved')) {
      return StatusKind.success;
    }
    return StatusKind.info;
  }

  String get _chipLabel {
    if (_failed) return 'FAILED';
    if (_status.startsWith('Payment received') ||
        _status.startsWith('Payment approved')) {
      return 'PROCESSING';
    }
    return 'PAYMENT';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Mf.paper,
      appBar: AppBar(
        backgroundColor: Mf.paper,
        title: Text('Payment', style: Mf.display(20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () {
              _finish();
              if (context.canPop()) context.pop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: Mf.surfaceAlt,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _status,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Mf.body(
                      14,
                      color: Mf.inkMuted,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                StatusChip(_chipLabel, kind: _chipKind),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loadedUrl == null)
                  const Center(child: CircularProgressIndicator(color: Mf.teal))
                else if (_webLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Mf.teal),
                  ),
                if (_webError != null)
                  ColoredBox(
                    color: Mf.paper,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.public_off_rounded,
                              size: 52,
                              color: Mf.coral,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Payment page did not load',
                              style: Mf.display(22),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _webError!,
                              style: Mf.body(13, color: Mf.inkMuted),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            SecondaryButton(
                              'Try again',
                              onPressed: _retryPayment,
                            ),
                            const SizedBox(height: 10),
                            GhostButton(
                              'Open in browser',
                              onPressed: _openPaymentInBrowser,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      _checking ? 'Checking…' : 'Check status',
                      onPressed: _checking
                          ? null
                          : () => _checkStatus(manual: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _failed || _timedOut
                        ? PrimaryButton('Try again', onPressed: _retryPayment)
                        : PrimaryButton(
                            'Open in browser',
                            onPressed: _openPaymentInBrowser,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
