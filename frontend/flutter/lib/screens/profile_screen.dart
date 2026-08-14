import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import 'home_screen.dart';

class ProfileScreen extends StatefulWidget {
  final ApiService api;
  const ProfileScreen({super.key, required this.api});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.api.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: LiveIndicator('OPERATOR IDENTITY'),
        ),
        const SizedBox(height: 8),
        const SignHeader(title: 'OPERATOR PROFILE'),
        const SizedBox(height: 20),
        if (_loading)
          const Expanded(child: Center(child: Text('READING IDENTITY...', style: TextStyle(fontFamily: 'monospace', color: Terminal.green))))
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TerminalPanel(
                    borderColor: Terminal.amber,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID', style: Terminal.mono(11, color: Terminal.dim, spacing: 2)),
                        const SizedBox(height: 4),
                        Text(_profile?.id ?? '----------', style: Terminal.mono(13, color: Terminal.white, spacing: 1)),
                        const SizedBox(height: 14),
                        Text('MASKED NUMBER', style: Terminal.mono(11, color: Terminal.dim, spacing: 2)),
                        const SizedBox(height: 4),
                        Text(_profile?.maskedMobile ?? '----------', style: Terminal.mono(18, color: Terminal.amber, weight: FontWeight.w700)),
                        const SizedBox(height: 14),
                        Text('GENDER', style: Terminal.mono(11, color: Terminal.dim, spacing: 2)),
                        const SizedBox(height: 4),
                        Text(_profile?.gender ?? 'UNKNOWN', style: Terminal.mono(13, color: Terminal.white, spacing: 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TermButton(
                    label: 'TERMINATE SESSION',
                    color: Terminal.red,
                    onPressed: () => logout(context, widget.api),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SESSION TOKEN IS PERSISTENT.\nDO NOT SHARE.',
                    style: Terminal.mono(11, color: Terminal.dim, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}