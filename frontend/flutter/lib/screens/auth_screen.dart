import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:makco/services/api_service.dart';
import 'package:makco/state/session.dart';
import 'package:makco/theme/madras_flow.dart';
import 'package:makco/widgets/madras_components.dart';

/// Phone + 4-digit OTP sign-in. Navigation is owned by the router.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  String? _authId;
  bool _busy = false;
  Timer? _resendTimer;
  int _resendIn = 0;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendIn <= 1) {
        timer.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn--);
      }
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_digits.length != 10) {
      _toast('Enter your 10-digit mobile number.');
      return;
    }
    setState(() => _busy = true);
    try {
      final session = await Api.requestOtp(_digits);
      if (!mounted) return;
      if (session.authId == null) {
        throw ApiException('Could not start sign-in. Try again.');
      }
      _otp.clear();
      _startResendTimer();
      setState(() {
        _authId = session.authId;
        _busy = false;
      });
      if (resend) _toast('A new code is on its way.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('Could not reach the server. Check your connection.');
    }
  }

  Future<void> _verify() async {
    final authId = _authId;
    if (authId == null) return;
    if (_otp.text.trim().length != 4) {
      _toast('Enter the 4-digit code.');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final session = await Api.verifyOtp(authId, _otp.text.trim());
      final token = session.token;
      if (token == null) {
        throw ApiException('Code verified, but no token came back. Try again.');
      }
      await ref.read(sessionProvider.notifier).signedIn(token, session.userId);
      // The router redirects to /home when the session flips.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('Could not verify the code. Check your connection.');
    }
  }

  void _changeNumber() {
    _resendTimer?.cancel();
    _otp.clear();
    setState(() {
      _authId = null;
      _busy = false;
      _resendIn = 0;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final verifying = _authId != null;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (verifying)
                IconButton(
                  onPressed: _changeNumber,
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Mf.ink,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                )
              else
                const SizedBox(height: 28),
              const SizedBox(height: 12),
              const GopuramMark(width: 54, color: Mf.amber),
              const SizedBox(height: 16),
              Text('MAKCO', style: Mf.display(30, color: Mf.ink)),
              const SizedBox(height: 4),
              Text(
                'Chennai metro, minus the queue.',
                style: Mf.body(14, color: Mf.inkMuted),
              ),
              const SizedBox(height: 34),
              Text(
                verifying ? 'Enter your code' : 'Sign in with your number',
                style: Mf.display(26, color: Mf.ink),
              ),
              const SizedBox(height: 6),
              Text(
                verifying
                    ? 'We sent a 4-digit code to +91 ${_phone.text}.'
                    : 'No passwords. Just a quick code.',
                style: Mf.body(14, color: Mf.inkMuted),
              ),
              const SizedBox(height: 24),
              TicketCard(
                padding: const EdgeInsets.all(18),
                child: verifying ? _otpForm() : _phoneForm(),
              ),
              if (!verifying) ...[
                const SizedBox(height: 20),
                Text(
                  'By continuing you agree to ride with a valid metro ticket.',
                  style: Mf.body(12, color: Mf.inkFaint),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mobile number',
          style: Mf.body(13, color: Mf.inkMuted, weight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          style: Mf.body(20, weight: FontWeight.w700),
          decoration: InputDecoration(
            prefixText: '+91  ',
            prefixStyle: Mf.body(
              18,
              color: Mf.inkMuted,
              weight: FontWeight.w600,
            ),
            hintText: '98400 00000',
            hintStyle: Mf.body(18, color: Mf.inkFaint),
            filled: true,
            fillColor: Mf.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Mf.amber, width: 2),
            ),
          ),
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          'Send me the code',
          icon: Icons.sms_outlined,
          busy: _busy,
          onPressed: _busy ? null : _sendCode,
        ),
      ],
    );
  }

  Widget _otpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '4-digit code',
          style: Mf.body(13, color: Mf.inkMuted, weight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _otp,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          style: Mf.display(32, color: Mf.ink).copyWith(letterSpacing: 18),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••',
            hintStyle: Mf.display(
              30,
              color: Mf.inkFaint,
            ).copyWith(letterSpacing: 18),
            filled: true,
            fillColor: Mf.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Mf.amber, width: 2),
            ),
          ),
          onChanged: (value) {
            setState(() {});
            if (value.length == 4) _verify();
          },
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          'Verify & continue',
          icon: Icons.check_rounded,
          busy: _busy,
          onPressed: _busy ? null : _verify,
        ),
        const SizedBox(height: 6),
        Center(
          child: _resendIn > 0
              ? Text(
                  'Resend in 0:${_resendIn.toString().padLeft(2, '0')}',
                  style: Mf.body(13, color: Mf.inkFaint),
                )
              : TextButton(
                  onPressed: _busy ? null : () => _sendCode(resend: true),
                  style: TextButton.styleFrom(foregroundColor: Mf.teal),
                  child: Text(
                    'Resend code',
                    style: Mf.body(13, color: Mf.teal, weight: FontWeight.w700),
                  ),
                ),
        ),
      ],
    );
  }
}
