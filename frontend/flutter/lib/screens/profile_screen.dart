import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:makco/models/models.dart';
import 'package:makco/services/api_service.dart';
import 'package:makco/state/session.dart';
import 'package:makco/theme/madras_flow.dart';
import 'package:makco/widgets/madras_components.dart';

/// The Profile tab — account details and sign-out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Mf.paper,
        title: Text('Log out?', style: Mf.display(20)),
        content: Text(
          'Your tickets stay safe on this account. You can sign back in with your number.',
          style: Mf.body(14, color: Mf.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Stay', style: Mf.body(14, color: Mf.inkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Log out',
              style: Mf.body(14, color: Mf.coral, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(sessionProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final profile = session.profile;

    return RefreshIndicator(
      color: Mf.teal,
      onRefresh: () => ref.read(sessionProvider.notifier).refreshProfile(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Profile', style: Mf.display(28, color: Mf.ink)),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Mf.tealSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: Mf.teal),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (profile == null)
            _ProfileFallback(
              onRetry: () =>
                  ref.read(sessionProvider.notifier).refreshProfile(),
            )
          else
            _ProfileCard(profile: profile),
          const SizedBox(height: 18),
          _InfoCard(
            rows: [
              (
                'Signed in',
                profile?.maskedMobile.isNotEmpty == true
                    ? profile!.maskedMobile
                    : 'Yes',
              ),
              ('Mode', 'Chennai Metro'),
              ('Server', Api.baseUrl.replaceFirst('http://', '')),
              ('Version', '3.3.2 (332)'),
            ],
          ),
          const SizedBox(height: 26),
          GhostButton(
            'Log out',
            color: Mf.coral,
            onPressed: () => _logout(context, ref),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'MAKCO · Chennai transit, made easy.',
              style: Mf.body(12, color: Mf.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Profile profile;

  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return TicketCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Mf.amber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_subway_rounded,
                  color: Mf.ink,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hello', style: Mf.body(13, color: Mf.inkMuted)),
                    const SizedBox(height: 2),
                    Text(
                      profile.maskedMobile.isEmpty
                          ? 'Chennai rider'
                          : profile.maskedMobile,
                      style: Mf.display(23, color: Mf.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Mf.hairline),
          const SizedBox(height: 14),
          Row(
            children: [
              _Meta(label: 'Gender', value: _titleCase(profile.gender)),
              const SizedBox(width: 28),
              _Meta(label: 'Transit', value: 'Metro'),
            ],
          ),
        ],
      ),
    );
  }

  String _titleCase(String value) {
    if (value.isEmpty) return '—';
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }
}

class _Meta extends StatelessWidget {
  final String label;
  final String value;

  const _Meta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Mf.overline(color: Mf.inkFaint)),
        const SizedBox(height: 3),
        Text(value, style: Mf.body(15, weight: FontWeight.w600)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<(String, String)> rows;

  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return TicketCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(rows[i].$1, style: Mf.body(13, color: Mf.inkMuted)),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      rows[i].$2,
                      style: Mf.body(13, weight: FontWeight.w600),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1)
              const Divider(height: 1, color: Mf.hairline),
          ],
        ],
      ),
    );
  }
}

class _ProfileFallback extends StatelessWidget {
  final VoidCallback onRetry;

  const _ProfileFallback({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return TicketCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Couldn't load your profile", style: Mf.display(20)),
          const SizedBox(height: 6),
          Text(
            'You are still signed in. Pull down to refresh.',
            style: Mf.body(14, color: Mf.inkMuted),
          ),
          const SizedBox(height: 16),
          GhostButton('Try again', onPressed: onRetry),
        ],
      ),
    );
  }
}
