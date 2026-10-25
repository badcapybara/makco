import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:makco/models/models.dart';
import 'package:makco/services/api_service.dart';
import 'package:makco/theme/madras_flow.dart';
import 'package:makco/widgets/madras_components.dart';

/// Hosts the payment webview and watches for booking confirmation.
class PaymentScreen extends StatefulWidget {
  final Booking booking;

  const PaymentScreen({super.key, required this.booking});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final WebViewController _controller;
  Timer? _timer;
  bool _webLoading = true;
  bool _finished = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
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
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            final scheme = uri?.scheme.toLowerCase() ?? '';
            if (scheme == 'http' ||
                scheme == 'https' ||
                scheme == 'about' ||
                scheme == 'data') {
              return NavigationDecision.navigate;
            }
            unawaited(_openExternal(request.url));
            return NavigationDecision.prevent;
          },
        ),
      );
    final url = widget.booking.paymentUrl;
    if (url.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _finish();
        _snack('Payment link is missing. Please book again.');
        if (context.canPop()) context.pop();
      });
    } else {
      _controller.loadRequest(Uri.parse(url));
      _timer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _checkStatus(),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

  Future<void> _checkStatus() async {
    if (_finished || _checking) return;
    _checking = true;
    Booking updated;
    try {
      updated = await Api.bookingStatus(widget.booking.bookingId);
    } catch (_) {
      _checking = false;
      return;
    }
    _checking = false;
    if (!mounted || _finished) return;
    if (updated.status == 'CONFIRMED' || updated.confirmed) {
      _finish();
      context.pushReplacement('/ticket', extra: updated);
      return;
    }
    final status = updated.status.toUpperCase();
    if (status == 'CANCELLED' ||
        status == 'FAILED' ||
        status == 'EXPIRED' ||
        status == 'PAYMENT_FAILED') {
      _finish();
      _snack('Payment was not completed. Your ticket was not issued.');
      if (context.canPop()) context.pop();
    }
  }

  void _finish() {
    _finished = true;
    _timer?.cancel();
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
                Text(
                  'Waiting for payment…',
                  style: Mf.body(
                    14,
                    color: Mf.inkMuted,
                    weight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const StatusChip('PAYMENT', kind: StatusKind.info),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_webLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Mf.teal),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
