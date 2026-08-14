import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import 'payment_screen.dart';
import 'station_picker.dart';

class BookingScreen extends StatefulWidget {
  final ApiService api;
  final TransitMode mode;
  const BookingScreen({super.key, required this.api, required this.mode});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  List<Station> _stations = [];
  bool _loading = true;
  String? _error;

  Station? _from;
  Station? _to;
  int _qty = 1;

  bool _searching = false;  List<Quote> _quotes = [];
  bool _quoting = false;

  Quote? _selected;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stations = await widget.api.getStations(widget.mode, 'chennai');
      if (!mounted) return;
      setState(() {
        _stations = stations;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'STATION FEED OFFLINE';
        _loading = false;
      });
    }
  }

  Future<void> _search() async {
    if (_from == null || _to == null) {
      setState(() => _error = 'SELECT FROM + TO');
      return;
    }
    setState(() {
      _searching = true;
      _quotes = [];
      _error = null;
    });
    try {
      final searchId = await widget.api
          .searchFare(widget.mode, 'chennai', _from!.code, _to!.code, qty: _qty);
      await _pollQuotes(searchId);
    } catch (e) {
      setState(() => _error = 'SEARCH FAILED');
    } finally {
      setState(() => _searching = false);
    }
  }

  Future<void> _pollQuotes(String searchId) async {
    for (var i = 0; i < 6; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() => _quoting = true);
      try {
        final quotes = await widget.api.getQuotes(widget.mode, 'chennai', searchId);
        if (quotes.isNotEmpty) {
          setState(() {
            _quotes = quotes;
            _quoting = false;
          });
          return;
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _quoting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.mode.label} BOOKING', style: Terminal.mono(16, color: Terminal.white, spacing: 2)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LiveIndicator('FARE TERMINAL'),
            const SizedBox(height: 12),
            SignHeader(title: '${widget.mode.label} // CHENNAI'),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('LOADING STATIONS...', style: TextStyle(fontFamily: 'monospace', color: Terminal.green))))
            else if (_error != null && _stations.isEmpty)
              TerminalPanel(
                borderColor: Terminal.red,
                child: Column(
                  children: [
                    Text('!! $_error', style: Terminal.mono(14, color: Terminal.red, weight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    TermButton(label: 'RETRY FEED', color: Terminal.red, onPressed: _loadStations),
                  ],
                ),
              )
            else ...[
              TerminalPanel(
                child: Column(
                  children: [
                    _stationRow('FROM', _from, () => _pickStation(true)),
                    const SizedBox(height: 8),
                    _stationRow('TO  ', _to, () => _pickStation(false)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('QTY', style: Terminal.mono(12, color: Terminal.dim, spacing: 2)),
                        const SizedBox(width: 12),
                        _qtyBtn('-', () => setState(() => _qty = _qty > 1 ? _qty - 1 : 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: SplitFlap('$_qty', width: 60, height: 44, fontSize: 22),
                        ),
                        _qtyBtn('+', () => setState(() => _qty = _qty < 5 ? _qty + 1 : 5)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TermButton(
                label: _searching ? 'SEARCHING...' : 'SEARCH FARE',
                color: Terminal.amber,
                onPressed: _searching ? null : _search,
              ),
              const SizedBox(height: 20),
              if (_quoting) const Text('POLLING QUOTE BOARD...', style: TextStyle(fontFamily: 'monospace', color: Terminal.dim)),
              if (_quotes.isNotEmpty) ..._quotes.map((q) => _quoteCard(q)),
              if (_error != null) Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('!! $_error', style: Terminal.mono(13, color: Terminal.red)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stationRow(String label, Station? s, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Terminal.panelLift,
          border: Border.all(color: Terminal.hairline),
        ),
        child: Row(
          children: [
            Text(label, style: Terminal.mono(12, color: Terminal.dim, spacing: 2)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                s?.name ?? '-------',
                style: Terminal.mono(16,
                    color: s != null ? Terminal.white : Terminal.dim, weight: FontWeight.w600),
              ),
            ),
            if (s != null) Text(s.code, style: Terminal.mono(12, color: Terminal.amber, spacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Terminal.panelLift,
          border: Border.all(color: Terminal.amber, width: 2),
        ),
        child: Center(child: Text(label, style: Terminal.mono(20, color: Terminal.amber, weight: FontWeight.w700))),
      ),
    );
  }

  Future<void> _pickStation(bool isFrom) async {
    final picked = await Navigator.of(context).push<Station>(
      MaterialPageRoute(builder: (_) => StationPicker(stations: _stations)),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
        } else {
          _to = picked;
        }
        _quotes = [];
      });
    }
  }

  Widget _quoteCard(Quote q) {
    final selected = _selected?.quoteId == q.quoteId;
    return GestureDetector(
      onTap: () => setState(() => _selected = q),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF241D00) : Terminal.panel,
          border: Border.all(color: selected ? Terminal.amber : Terminal.hairline, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(q.type.toUpperCase(), style: Terminal.mono(13, color: Terminal.cyan, spacing: 1.5)),
                const Spacer(),
                Text('₹${q.price}', style: Terminal.mono(22, color: Terminal.amber, weight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text('VALID TILL ${q.validTill}', style: Terminal.mono(10, color: Terminal.dim)),
            if (selected) ...[
              const SizedBox(height: 12),
              TermButton(
                label: 'CONFIRM BOOKING',
                color: Terminal.green,
                onPressed: () => _confirm(q),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(Quote q) async {
    try {
      final booking = await widget.api.confirmBooking(widget.mode, 'chennai', q.quoteId, qty: q.quantity);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PaymentScreen(
          api: widget.api,
          mode: widget.mode,
          booking: booking,
        ),
      ));
    } catch (e) {
      setState(() => _error = 'CONFIRM FAILED');
    }
  }
}