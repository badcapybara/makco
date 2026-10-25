import 'package:flutter/material.dart';

import '../theme/madras_flow.dart';
import 'madras_components.dart';

Map<String, dynamic>? _innerTicket(Map<String, dynamic> ticket) {
  if (ticket['qrData'] != null || ticket['ticketNumber'] != null) return ticket;
  final nested = ticket['tickets'];
  if (nested is List && nested.isNotEmpty && nested.first is Map) {
    return Map<String, dynamic>.from(nested.first as Map);
  }
  return null;
}

String ticketRouteName(Map<String, dynamic> ticket) {
  final inner = _innerTicket(ticket);
  final name =
      inner?['routeName'] ??
      ticket['routeName'] ??
      ticket['name'] ??
      ticket['routeShortName'];
  if (name is String && name.trim().isNotEmpty) return name;
  final ref = ticketRef(ticket);
  if (ref != null) return ref;
  return 'Metro trip';
}

String ticketStation(Map<String, dynamic> ticket, String side) {
  final inner = _innerTicket(ticket);
  final value =
      inner?['${side}Station'] ??
      ticket['${side}Station'] ??
      ticket[side] ??
      ticket['${side}StationName'];
  if (value is String && value.isNotEmpty) return value;
  if (value is Map) {
    final name = value['name'];
    if (name is String && name.isNotEmpty) return name;
  }
  final stations = ticket['stations'];
  if (stations is List && stations.isNotEmpty) {
    final station = side == 'from' ? stations.first : stations.last;
    if (station is Map) {
      final name = station['name'] ?? station['stationName'];
      if (name is String && name.isNotEmpty) return name;
    }
  }
  return '—';
}

String ticketStatus(Map<String, dynamic> ticket) {
  final status = ticket['status'];
  if (status is String && status.isNotEmpty) return status.toUpperCase();
  if (ticketRef(ticket) != null) return 'CONFIRMED';
  return 'UNKNOWN';
}

num? ticketPrice(Map<String, dynamic> ticket) {
  final price = ticket['price'] ?? ticket['fare'] ?? ticket['totalPrice'];
  return price is num ? price : null;
}

String? ticketRef(Map<String, dynamic> ticket) {
  final inner = _innerTicket(ticket) ?? ticket;
  final ref =
      inner['ticketNumber'] ?? inner['ticketNo'] ?? ticket['ticketNumber'];
  if (ref is List) return ref.isEmpty ? null : ref.first.toString();
  if (ref is String && ref.isNotEmpty) return ref;
  final qr = inner['qrData'] ?? ticket['qrData'];
  if (qr is String && qr.isNotEmpty) {
    final parts = qr.split(',');
    if (parts.length > 1 && parts[1].isNotEmpty) return parts[1];
  }
  return null;
}

StatusKind ticketStatusKind(String status) {
  switch (status.toUpperCase()) {
    case 'CONFIRMED':
    case 'SUCCESS':
    case 'VALID':
    case 'ACTIVE':
      return StatusKind.success;
    case 'CANCELLED':
    case 'EXPIRED':
    case 'FAILED':
      return StatusKind.error;
    case 'NEW':
    case 'PENDING':
      return StatusKind.info;
    default:
      return StatusKind.neutral;
  }
}

/// Ticket / booking row used on Home and in the Tickets tab.
class TicketTile extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback? onTap;
  final bool dense;

  const TicketTile({
    super.key,
    required this.ticket,
    this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = ticketStatus(ticket);
    final price = ticketPrice(ticket);
    final from = ticketStation(ticket, 'from');
    final to = ticketStation(ticket, 'to');

    if (dense) {
      return TicketCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Mf.tealSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                size: 17,
                color: Mf.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$from → $to',
                    style: Mf.body(14, weight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ticketRouteName(ticket),
                    style: Mf.body(12, color: Mf.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusChip(status, kind: ticketStatusKind(status)),
                if (price != null) ...[
                  const SizedBox(height: 4),
                  FareTag(price, size: 15),
                ],
              ],
            ),
          ],
        ),
      );
    }

    return TicketCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticketRouteName(ticket),
                  style: Mf.body(16, weight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              StatusChip(status, kind: ticketStatusKind(status)),
            ],
          ),
          const SizedBox(height: 12),
          RouteRow(from: from, to: to),
          if (price != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (ticketRef(ticket) != null)
                  Expanded(
                    child: Text(
                      'TICKET ${ticketRef(ticket)}',
                      style: Mf.overline(
                        color: Mf.inkFaint,
                      ).copyWith(letterSpacing: 0.6),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                FareTag(price),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
