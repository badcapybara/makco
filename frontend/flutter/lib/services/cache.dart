import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Small read-through cache so the app opens with the last known metro
/// catalogue and tickets when the network is unavailable.
class Cache {
  static const _stationsKey = 'makco_cache_stations_v1';
  static const _ticketsKey = 'makco_cache_tickets_v1';
  static const _bookingsKey = 'makco_cache_bookings_v1';
  static const _profileKey = 'makco_cache_profile_v1';

  static Future<void> _write(String key, Object value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(value));
    } catch (_) {}
  }

  static Future<dynamic> _read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveStations(List<Station> stations) async {
    if (stations.isEmpty) return;
    await _write(_stationsKey, {
      'savedAt': DateTime.now().toIso8601String(),
      'items': stations.map((s) => s.toJson()).toList(),
    });
  }

  static Future<List<Station>> readStations() async {
    final data = await _read(_stationsKey);
    if (data is! Map || data['items'] is! List) return const [];
    try {
      return (data['items'] as List)
          .whereType<Map>()
          .map((e) => Station.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.code.isNotEmpty && s.name.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveTickets(List<dynamic> tickets) async {
    await _write(_ticketsKey, {
      'savedAt': DateTime.now().toIso8601String(),
      'items': tickets,
    });
  }

  static Future<List<dynamic>> readTickets() async {
    final data = await _read(_ticketsKey);
    if (data is! Map || data['items'] is! List) return const [];
    return data['items'] as List;
  }

  static Future<void> clearTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ticketsKey);
    } catch (_) {}
  }

  static Future<void> saveProfile(Profile profile) async {
    if (profile.id.isEmpty && profile.maskedMobile.isEmpty) return;
    await _write(_profileKey, profile.toJson());
  }

  static Future<Profile?> readProfile() async {
    final data = await _read(_profileKey);
    if (data is! Map) return null;
    try {
      final profile = Profile.fromJson(Map<String, dynamic>.from(data));
      if (profile.id.isEmpty && profile.maskedMobile.isEmpty) return null;
      return profile;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileKey);
    } catch (_) {}
  }

  static Future<void> saveBookingSnapshot(Booking booking) async {
    if (booking.bookingId.isEmpty) return;
    final data = await _read(_bookingsKey);
    final items = <Map<String, dynamic>>[];
    if (data is Map && data['items'] is List) {
      for (final entry in data['items'] as List) {
        if (entry is Map) items.add(Map<String, dynamic>.from(entry));
      }
    }
    items.removeWhere(
      (entry) => _snapshotBookingId(entry) == booking.bookingId,
    );
    items.insert(0, {
      'savedAt': DateTime.now().toIso8601String(),
      'item': booking.toTicketJson(),
    });
    await _write(_bookingsKey, {
      'savedAt': DateTime.now().toIso8601String(),
      'items': items.where(_freshSnapshot).toList(),
    });
  }

  static Future<List<Map<String, dynamic>>> readBookingSnapshots() async {
    final data = await _read(_bookingsKey);
    if (data is! Map || data['items'] is! List) return const [];
    final result = <Map<String, dynamic>>[];
    for (final entry in data['items'] as List) {
      if (entry is! Map) continue;
      final snapshot = Map<String, dynamic>.from(entry);
      if (!_freshSnapshot(snapshot)) continue;
      final item = snapshot['item'];
      if (item is! Map) continue;
      result.add({
        ...Map<String, dynamic>.from(item),
        '_snapshotSavedAt': snapshot['savedAt'],
      });
    }
    return result;
  }

  static Future<void> clearBookingSnapshots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bookingsKey);
    } catch (_) {}
  }

  static String _snapshotBookingId(Map<String, dynamic> entry) {
    final item = entry['item'];
    if (item is! Map) return '';
    return (item['bookingId'] as String?) ??
        (item['ticketRef'] as String?) ??
        '';
  }

  static bool _freshSnapshot(Map<String, dynamic> entry) {
    final savedAt = DateTime.tryParse(entry['savedAt'] as String? ?? '');
    if (savedAt == null) return false;
    final item = entry['item'];
    final status = item is Map
        ? (item['status'] as String?)?.toUpperCase() ?? ''
        : '';
    const terminal = {
      'CONFIRMED',
      'SUCCESS',
      'VALID',
      'ACTIVE',
      'CANCELLED',
      'FAILED',
      'EXPIRED',
      'PAYMENT_FAILED',
    };
    final maxAge = terminal.contains(status)
        ? const Duration(hours: 24)
        : const Duration(hours: 2);
    return DateTime.now().difference(savedAt) < maxAge;
  }
}
