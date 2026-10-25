import 'package:flutter/material.dart';

import 'package:makco/theme/madras_flow.dart';

import 'history_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Bottom-nav shell hosting the Book, History and Profile tabs.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(
              onOpenProfile: () => setState(() => _index = 2),
              onOpenTickets: () => setState(() => _index = 1),
            ),
            HistoryScreen(onBook: () => setState(() => _index = 0)),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: _PillNav(
          currentIndex: _index,
          onChanged: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

class _PillNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _PillNav({required this.currentIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Mf.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Mf.ink.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _PillItem(
            icon: Icons.directions_subway,
            label: 'Book',
            selected: currentIndex == 0,
            onTap: () => onChanged(0),
          ),
          _PillItem(
            icon: Icons.confirmation_number_outlined,
            label: 'Tickets',
            selected: currentIndex == 1,
            onTap: () => onChanged(1),
          ),
          _PillItem(
            icon: Icons.person_outline,
            label: 'Profile',
            selected: currentIndex == 2,
            onTap: () => onChanged(2),
          ),
        ],
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PillItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Mf.amber : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: selected ? Mf.ink : Mf.inkMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: Mf.body(
                  13,
                  color: selected ? Mf.ink : Mf.inkMuted,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
