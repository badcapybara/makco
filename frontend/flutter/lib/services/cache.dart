import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Small read-through cache so the app opens with the last known metro
/// catalogue and tickets when the network is unavailable.
class Cache {
  static const _stationsKey = 'makco_cache_stations_v1';
  static const _ticketsKey = 'makco_cache_tickets_v1';

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
}
