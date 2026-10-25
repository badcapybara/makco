import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

const _recentsKey = 'makco_recent_trips';
const _maxRecents = 5;

/// Locally stored recent routes for one-tap repeat booking.
class RecentsController extends Notifier<List<RecentTrip>> {
  @override
  List<RecentTrip> build() {
    Future<void>.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_recentsKey) ?? const [];
      final trips = <RecentTrip>[];
      for (final item in raw) {
        try {
          final json = jsonDecode(item);
          if (json is Map<String, dynamic>) {
            final trip = RecentTrip.fromJson(json);
            if (trip.fromCode.isNotEmpty && trip.toCode.isNotEmpty) {
              trips.add(trip);
            }
          }
        } catch (_) {}
      }
      state = trips;
    } catch (_) {
      state = const [];
    }
  }

  Future<void> _persist(List<RecentTrip> trips) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _recentsKey,
        trips.map((t) => jsonEncode(t.toJson())).toList(),
      );
    } catch (_) {}
  }

  Future<void> add(RecentTrip trip) async {
    final next = <RecentTrip>[
      trip,
      ...state.where((t) => !t.sameRoute(trip.fromCode, trip.toCode)),
    ].take(_maxRecents).toList();
    state = next;
    await _persist(next);
  }

  Future<void> remove(RecentTrip trip) async {
    final next = state
        .where((t) => !t.sameRoute(trip.fromCode, trip.toCode))
        .toList();
    state = next;
    await _persist(next);
  }

  Future<void> clear() async {
    state = const [];
    await _persist(const []);
  }
}

final recentsProvider = NotifierProvider<RecentsController, List<RecentTrip>>(
  RecentsController.new,
);
