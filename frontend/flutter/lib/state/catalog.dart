import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/cache.dart';

/// Chennai metro catalogue. Falls back to the last cached list offline.
final stationsProvider = FutureProvider<List<Station>>((ref) async {
  try {
    final stations = await Api.stations(TransitMode.metro);
    await Cache.saveStations(stations);
    return stations;
  } catch (_) {
    final cached = await Cache.readStations();
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
});

/// Tickets / bookings for the signed-in rider, cached for offline viewing.
final ticketsProvider = FutureProvider<List<dynamic>>((ref) async {
  final cached = await Cache.readTickets();
  final snapshots = await Cache.readBookingSnapshots();
  try {
    final tickets = await Api.tickets();
    final merged = _mergeTickets(tickets, snapshots);
    await Cache.saveTickets(merged);
    return merged;
  } catch (_) {
    final merged = _mergeTickets(cached, snapshots);
    if (merged.isNotEmpty) return merged;
    rethrow;
  }
});

String _ticketId(Map<String, dynamic> ticket) {
  final id = ticket['bookingId'] ?? ticket['ticketRef'] ?? ticket['booking_id'];
  return id?.toString() ?? '';
}

/// Adds locally seen bookings that the operator list has not returned yet.
/// The local copy also fills in payment/ticket data that `/tickets` omits.
List<dynamic> _mergeTickets(List<dynamic> primary, List<dynamic> extra) {
  final result = <Map<String, dynamic>>[];
  final index = <String, int>{};
  final seen = <String>{};

  for (final raw in primary) {
    if (raw is! Map) continue;
    final ticket = Map<String, dynamic>.from(raw);
    final id = _ticketId(ticket);
    if (id.isNotEmpty) {
      if (seen.contains(id)) continue;
      seen.add(id);
      index[id] = result.length;
    }
    result.add(ticket);
  }

  final localOnly = <Map<String, dynamic>>[];
  for (final raw in extra) {
    if (raw is! Map) continue;
    final ticket = Map<String, dynamic>.from(raw)..remove('_snapshotSavedAt');
    final id = _ticketId(ticket);
    final existing = id.isEmpty ? null : index[id];
    if (existing != null) {
      final current = result[existing];
      if (current['payment'] == null && ticket['payment'] != null) {
        current['payment'] = ticket['payment'];
      }
      final currentTickets = current['tickets'];
      if ((currentTickets is! List || currentTickets.isEmpty) &&
          ticket['tickets'] is List &&
          (ticket['tickets'] as List).isNotEmpty) {
        current['tickets'] = ticket['tickets'];
      }
      continue;
    }
    if (id.isNotEmpty) {
      if (seen.contains(id)) continue;
      seen.add(id);
    }
    localOnly.add(ticket);
  }

  return [...localOnly, ...result];
}
