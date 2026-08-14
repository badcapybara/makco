import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import 'ticket_screen.dart';

class PaymentScreen extends StatefulWidget {
  final ApiService api;
  final TransitMode mode;
  final Booking booking;
  const PaymentScreen({super.key, required this.api, required this.mode, required this.booking});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  Booking _booking = Booking(bookingId: '', status: 'NEW', price: 0);

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _startPolling();
  }

  Future<void> _startPolling() async {
    var paid = false;
    while (mounted && !paid) {
      await Future.delayed(const Duration(seconds: 5));
      try {
        final b = await widget.api
            .getBookingStatus(widget.mode, 'chennai', _booking.bookingId);
        if (!mounted) return;
        setState(() => _booking = b);
        if (b.status == 'CONFIRMED' || b.tickets.isNotEmpty) {
          paid = true;
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => TicketScreen(
              api: widget.api,
              mode: widget.mode,
              bookingId: b.bookingId,
            ),
          ));
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _booking.paymentUrl;
    return Scaffold(
      appBar: AppBar(
        title: Text('PAYMENT // JUSPAY', style: Terminal.mono(15, color: Terminal.white, spacing: 2)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: Terminal.panelLift,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const LiveIndicator('PAYMENT PENDING'),
                    const Spacer(),
                    Text('₹${_booking.price}', style: Terminal.mono(24, color: Terminal.amber, weight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('BOOKING ${_booking.bookingId}', style: Terminal.mono(10, color: Terminal.dim, spacing: 1)),
                Text('STATUS: ${_booking.status}', style: Terminal.mono(12, color: Terminal.cyan, spacing: 1.5)),
              ],
            ),
          ),
          Expanded(
            child: url.isNotEmpty
                ? WebViewWidget(
                    controller: WebViewController()
                      ..setJavaScriptMode(JavaScriptMode.unrestricted)
                      ..loadRequest(Uri.parse(url)),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('AWATING PAYMENT ORDER...', style: TextStyle(fontFamily: 'monospace', color: Terminal.green)),
                        const SizedBox(height: 16),
                        TermButton(
                          label: 'REFRESH',
                          color: Terminal.amber,
                          onPressed: () => setState(() {}),
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