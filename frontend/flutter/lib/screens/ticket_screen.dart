import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import 'home_screen.dart';

class TicketScreen extends StatefulWidget {
  final ApiService api;
  final TransitMode mode;
  final String bookingId;
  const TicketScreen({super.key, required this.api, required this.mode, required this.bookingId});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  Booking _booking = Booking(bookingId: '', status: 'NEW', price: 0);
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final b = await widget.api.getBookingStatus(widget.mode, 'chennai', widget.bookingId);
      if (!mounted) return;
      setState(() {
        _booking = b;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TICKET CONFIRMED', style: Terminal.mono(15, color: Terminal.white, spacing: 2)),
      ),
      body: !_loaded
          ? const Center(child: Text('RETRIEVING TICKET...', style: TextStyle(fontFamily: 'monospace', color: Terminal.green)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TerminalPanel(
                    borderColor: Terminal.green,
                    child: Column(
                      children: [
                        LiveIndicator('PAYMENT CONFIRMED'),
                        SizedBox(height: 14),
                        SplitFlap('CONFIRMED', width: 260, height: 56, fontSize: 26, color: Terminal.green),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SignHeader(title: 'E-TICKET'),
                  const SizedBox(height: 12),
                  TerminalPanel(
                    borderColor: Terminal.amber,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DepartureRow(label: 'BOOKING', value: _short(_booking.bookingId), flapWidth: 200),
                        DepartureRow(label: 'STATUS', value: _booking.status, color: Terminal.green, flapWidth: 200),
                        DepartureRow(label: 'FARE', value: '₹${_booking.price}', color: Terminal.amber, flapWidth: 200),
                        const SizedBox(height: 8),
                        if (_booking.tickets.isNotEmpty)
                          Text(
                            '${_booking.tickets.length} TICKET(S) ISSUED',
                            style: Terminal.mono(13, color: Terminal.cyan, spacing: 1.5),
                          )
                        else
                          Text('NO TICKET OBJECTS YET', style: Terminal.mono(12, color: Terminal.dim)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TermButton(
                    label: 'BACK TO TERMINAL',
                    color: Terminal.amber,
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => HomeScreen(api: widget.api)),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  String _short(String s) => s.length > 12 ? '${s.substring(0, 8)}...' : s;
}