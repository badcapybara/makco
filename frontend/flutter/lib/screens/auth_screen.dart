import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  final ApiService api;
  const AuthScreen({super.key, required this.api});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  String? _authId;
  String? _error;

  Future<void> _sendOtp() async {
    final phone = _phone.text.trim();
    if (phone.length != 10) {
      setState(() => _error = 'INVALID PHONE. 10 DIGITS REQUIRED');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final session = await widget.api.initiateAuth(phone);
      if (session.authId == null) {
        setState(() => _error = 'AUTH FAILED');
      } else {
        setState(() => _authId = session.authId);
      }
    } catch (e) {
      setState(() => _error = 'NETWORK ERROR');
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otp.text.trim();
    if (otp.length != 4) {
      setState(() => _error = 'OTP MUST BE 4 DIGITS');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final session = await widget.api.verifyAuth(_authId!, otp);
      if (session.token == null) {
        setState(() => _error = 'INVALID OTP');
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', session.token!);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => HomeScreen(api: widget.api),
        ));
      }
    } catch (e) {
      setState(() => _error = 'VERIFY ERROR');
    } finally {
      setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const LiveIndicator('AUTH GATEWAY OPEN'),
              const SizedBox(height: 16),
              const SignHeader(title: 'OPERATOR AUTH'),
              const SizedBox(height: 24),
              TerminalPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ENTER MOBILE NUMBER', style: Terminal.mono(12, color: Terminal.dim, spacing: 1.5)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: Terminal.mono(20, color: Terminal.amber, weight: FontWeight.w700),
                      decoration: _dec('+91 -------'),
                    ),
                    const SizedBox(height: 8),
                    TermButton(
                      label: _authId == null ? 'REQUEST OTP' : 'RESEND OTP',
                      onPressed: _sending ? null : _sendOtp,
                    ),
                    if (_authId != null) ...[
                      const SizedBox(height: 20),
                      Text('ENTER 4-DIGIT OTP', style: Terminal.mono(12, color: Terminal.dim, spacing: 1.5)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _otp,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        style: Terminal.mono(24, color: Terminal.amber, weight: FontWeight.w700),
                        decoration: _dec('_ _ _ _'),
                      ),
                      const SizedBox(height: 8),
                      TermButton(
                        label: _verifying ? 'VERIFYING...' : 'VERIFY & CONNECT',
                        color: Terminal.green,
                        onPressed: _verifying ? null : _verifyOtp,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text('!! $_error', style: Terminal.mono(13, color: Terminal.red, weight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'SECURE CHANNEL: MOVINGTECH >> JUSPAY\nTOKEN: PERSISTENT SESSION',
                style: Terminal.mono(11, color: Terminal.dim, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: Terminal.mono(16, color: Terminal.dim),
      counterText: '',
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Terminal.hairline),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Terminal.amber, width: 2),
      ),
    );
  }
}