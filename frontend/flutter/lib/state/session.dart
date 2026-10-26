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
  final bool profileLoading;

  const SessionState({
    this.booted = false,
    this.authenticated = false,
    this.profile,
    this.profileLoading = false,
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

    final cachedProfile = hasToken ? await Cache.readProfile() : null;
    state = SessionState(
      booted: true,
      authenticated: hasToken,
      profile: cachedProfile,
      profileLoading: hasToken && cachedProfile == null,
    );
    if (hasToken) {
      unawaited(refreshProfile());
    }
  }

  Future<void> signedIn(String token, String? userId) async {
    await Api.saveSession(token, userId);
    await Cache.clearTickets();
    await Cache.clearBookingSnapshots();
    await Cache.clearProfile();
    ref.invalidate(ticketsProvider);
    state = const SessionState(
      booted: true,
      authenticated: true,
      profileLoading: true,
    );
    unawaited(refreshProfile());
  }

  Future<void> refreshProfile() async {
    if (!state.authenticated) return;
    if (state.profile == null) {
      state = const SessionState(
        booted: true,
        authenticated: true,
        profileLoading: true,
      );
    }
    final token = Api.token;
    try {
      final profile = await Api.profile();
      await Cache.saveProfile(profile);
      if (!state.authenticated || Api.token != token) return;
      state = SessionState(booted: true, authenticated: true, profile: profile);
    } catch (_) {
      if (!state.authenticated || Api.token != token) return;
      // Keep the cached profile.
      state = SessionState(
        booted: true,
        authenticated: true,
        profile: state.profile,
      );
    }
  }

  Future<void> signOut() async {
    await Api.saveSession(null, null);
    await Cache.clearTickets();
    await Cache.clearBookingSnapshots();
    await Cache.clearProfile();
    ref.invalidate(ticketsProvider);
    state = const SessionState(booted: true);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
