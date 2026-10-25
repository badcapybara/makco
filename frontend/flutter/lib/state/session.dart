import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/cache.dart';
import 'catalog.dart';

class SessionState {
  final bool booted;
  final bool authenticated;
  final Profile? profile;

  const SessionState({
    this.booted = false,
    this.authenticated = false,
    this.profile,
  });
}

/// Owns the stored token, the signed-in profile and the boot handshake.
class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future<void>.microtask(_restore);
    return const SessionState();
  }

  Future<void> _restore() async {
    var hasToken = false;
    try {
      hasToken = await Api.restoreSession();
    } catch (_) {
      hasToken = false;
    }

    state = SessionState(booted: true, authenticated: hasToken);
    if (hasToken) {
      unawaited(refreshProfile());
    }
  }

  Future<void> signedIn(String token, String? userId) async {
    await Api.saveSession(token, userId);
    ref.invalidate(ticketsProvider);
    state = const SessionState(booted: true, authenticated: true);
    unawaited(refreshProfile());
  }

  Future<void> refreshProfile() async {
    if (!state.authenticated) return;
    try {
      final profile = await Api.profile();
      state = SessionState(booted: true, authenticated: true, profile: profile);
    } catch (_) {
      // Keep the cached profile.
    }
  }

  Future<void> signOut() async {
    await Api.saveSession(null, null);
    await Cache.clearTickets();
    ref.invalidate(ticketsProvider);
    state = const SessionState(booted: true);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
