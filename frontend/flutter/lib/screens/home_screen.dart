import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import 'auth_screen.dart';
import 'booking_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final ApiService api;
  const HomeScreen({super.key, required this.api});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TransitMode _mode = TransitMode.metro;
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            _buildHome(),
            HistoryScreen(api: widget.api, mode: _mode),
            ProfileScreen(api: widget.api),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _buildHome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              LiveIndicator('CHENNAI'),
              Spacer(),
              Text('MAKCO v3.0', style: TextStyle(color: Terminal.dim, fontFamily: 'monospace', fontSize: 11, letterSpacing: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const SignHeader(title: 'TRANSIT TERMINAL'),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final m in TransitMode.all)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _modeChip(m),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('MODE:', style: Terminal.mono(12, color: Terminal.dim, spacing: 2)),
              const SizedBox(width: 8),
              Text(_mode.label, style: Terminal.mono(20, color: Terminal.amber, weight: FontWeight.w700, spacing: 2)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TerminalPanel(
            borderColor: Terminal.amber,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEXT DEPARTURE BOARD', style: Terminal.mono(11, color: Terminal.green, spacing: 2)),
                const SizedBox(height: 12),
                const DepartureRow(label: 'ROUTE', value: 'SELECT TO PROCEED', color: Terminal.dim, flapWidth: 200),
                const SizedBox(height: 16),
                TermButton(
                  label: 'BOOK ${_mode.label} TICKET',
                  onPressed: () => _openBooking(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SYSTEM', style: Terminal.mono(12, color: Terminal.dim, spacing: 2)),
              const SizedBox(height: 8),
              const TerminalPanel(
                borderColor: Terminal.hairline,
                child: Column(
                  children: [
                    DepartureRow(label: 'TRANSIT', value: 'BUS + METRO', color: Terminal.cyan, flapWidth: 160),
                    DepartureRow(label: 'PAYMENT', value: 'JUSPAY', color: Terminal.cyan, flapWidth: 160),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeChip(TransitMode m) {
    final selected = m.key == _mode.key;
    return GestureDetector(
      onTap: () => setState(() => _mode = m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Terminal.amber : Terminal.panel,
          border: Border.all(color: selected ? Terminal.amber : Terminal.hairline, width: 2),
        ),
        child: Text(
          m.label,
          style: Terminal.mono(14,
              color: selected ? Terminal.black : Terminal.white, weight: FontWeight.w700, spacing: 2),
        ),
      ),
    );
  }

  void _openBooking() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BookingScreen(api: widget.api, mode: _mode),
    ));
  }

  Widget _bottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Terminal.panel,
        border: Border(top: BorderSide(color: Terminal.hairline)),
      ),
      child: Row(
        children: [
          _navItem(0, 'BOOK', Icons.confirmation_number_outlined),
          _navItem(1, 'HISTORY', Icons.receipt_long_outlined),
          _navItem(2, 'OP', Icons.person_outline),
        ],
      ),
    );
  }

  Widget _navItem(int index, String label, IconData icon) {
    final selected = _tab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? Terminal.amber : Terminal.dim, size: 20),
              const SizedBox(height: 4),
              Text(label,
                  style: Terminal.mono(10,
                      color: selected ? Terminal.amber : Terminal.dim, spacing: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> logout(BuildContext context, ApiService api) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('token');
  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AuthScreen(api: api)),
      (route) => false,
    );
  }
}