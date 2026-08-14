import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import 'ticket_screen.dart';

class HistoryScreen extends StatefulWidget {
  final ApiService api;
  final TransitMode mode;
  const HistoryScreen({super.key, required this.api, required this.mode});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Booking> _bookings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bookings = await widget.api.getTickets(widget.mode, 'chennai');
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'HISTORY FEED OFFLINE';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: LiveIndicator('BOOKING ARCHIVE'),
        ),
        const SizedBox(height: 8),
        const SignHeader(title: 'TRANSIT HISTORY'),
        const SizedBox(height: 16),
        if (_loading)
          const Expanded(child: Center(child: Text('LOADING ARCHIVE...', style: TextStyle(fontFamily: 'monospace', color: Terminal.green))))
        else if (_error != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('!! $_error', style: Terminal.mono(14, color: Terminal.red)),
                  const SizedBox(height: 12),
                  TermButton(label: 'RETRY', color: Terminal.red, onPressed: _load),
                ],
              ),
            ),
          )
        else if (_bookings.isEmpty)
          const Expanded(
            child: Center(
              child: Text('NO BOOKINGS ON RECORD', style: TextStyle(fontFamily: 'monospace', color: Terminal.dim)),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final b = _bookings[i];
                final color = b.status == 'CONFIRMED'
                    ? Terminal.green
                    : b.status == 'CANCELLED'
                        ? Terminal.red
                        : Terminal.amber;
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TicketScreen(
                        api: widget.api,
                        mode: widget.mode,
                        bookingId: b.bookingId,
                      ),
                    ));
                  },
                  child: TerminalPanel(
                    borderColor: color,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(b.status, style: Terminal.mono(13, color: color, weight: FontWeight.w700, spacing: 1.5)),
                            const Spacer(),
                            Text('₹${b.price}', style: Terminal.mono(18, color: Terminal.amber, weight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('${widget.mode.label} // ${_short(b.bookingId)}', style: Terminal.mono(11, color: Terminal.dim)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  String _short(String s) => s.length > 14 ? '${s.substring(0, 10)}...' : s;
}