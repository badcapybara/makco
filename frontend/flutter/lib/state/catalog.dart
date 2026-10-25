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
  try {
    final tickets = await Api.tickets();
    await Cache.saveTickets(tickets);
    return tickets;
  } catch (_) {
    final cached = await Cache.readTickets();
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
});
