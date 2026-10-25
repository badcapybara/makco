class Station {
  final String code;
  final String name;
  final double? lat;
  final double? lon;

  Station({required this.code, required this.name, this.lat, this.lon});

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    if (lat != null) 'lat': lat,
    if (lon != null) 'lon': lon,
  };

  factory Station.fromJson(Map<String, dynamic> j) => Station(
    code:
        (j['code'] as String?) ??
        (j['stationCode'] as String?) ??
        (j['id'] as String?) ??
        '',
    name:
        (j['name'] as String?) ??
        (j['stationName'] as String?) ??
        (j['displayName'] as String?) ??
        '',
    lat: (j['lat'] as num?)?.toDouble(),
    lon: (j['lon'] as num?)?.toDouble(),
  );
}

class RouteInfo {
  final String code;
  final String longName;
  final String shortName;
  RouteInfo({
    required this.code,
    required this.longName,
    required this.shortName,
  });

  factory RouteInfo.fromJson(Map<String, dynamic> j) => RouteInfo(
    code:
        (j['code'] as String?) ??
        (j['routeCode'] as String?) ??
        (j['routeShortCode'] as String?) ??
        '',
    longName:
        (j['longName'] as String?) ??
        (j['routeName'] as String?) ??
        (j['name'] as String?) ??
        '',
    shortName:
        (j['shortName'] as String?) ?? (j['routeShortName'] as String?) ?? '',
  );
}

class Quote {
  final String type;
  final String quoteId;
  final num price;
  final int quantity;
  final String validTill;

  Quote({
    required this.type,
    required this.quoteId,
    required this.price,
    required this.quantity,
    required this.validTill,
  });

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
    type: (j['_type'] as String?) ?? 'Single',
    quoteId: (j['quoteId'] as String?) ?? '',
    price: (j['price'] as num?) ?? 0,
    quantity: (j['quantity'] as int?) ?? 1,
    validTill: (j['validTill'] as String?) ?? '',
  );
}

class Booking {
  final String bookingId;
  final String status;
  final num price;
  final Map<String, dynamic>? payment;
  final List<dynamic> tickets;
  final List<dynamic> stations;

  Booking({
    required this.bookingId,
    required this.status,
    required this.price,
    this.payment,
    this.tickets = const [],
    this.stations = const [],
  });

  String get paymentUrl {
    try {
      final order = payment?['paymentOrder'];
      final links = order is Map ? order['payment_links'] : null;
      final web = links is Map ? links['web'] : null;
      if (web is String && web.isNotEmpty) return web;
      final direct = payment?['payment_links'];
      final directWeb = direct is Map ? direct['web'] : null;
      return directWeb is String ? directWeb : '';
    } catch (_) {
      return '';
    }
  }

  String get paymentOrderStatus {
    try {
      final order = payment?['paymentOrder'];
      if (order is Map) {
        return (order['status'] as String?)?.toUpperCase() ?? '';
      }
    } catch (_) {}
    return '';
  }

  String get paymentStatus {
    final direct = (payment?['status'] as String?)?.toUpperCase() ?? '';
    return direct.isNotEmpty ? direct : paymentOrderStatus;
  }

  bool get paymentFailed {
    const failed = {
      'FAILURE',
      'FAILED',
      'CANCELLED',
      'DECLINED',
      'EXPIRED',
      'AUTHENTICATION_FAILED',
      'AUTHORIZATION_FAILED',
      'PAYMENT_DECLINED',
      'PAYMENT_FAILED',
      'TIMED_OUT',
    };
    return failed.contains(paymentStatus) ||
        failed.contains(paymentOrderStatus);
  }

  bool get paymentSucceeded =>
      paymentStatus == 'SUCCESS' ||
      paymentStatus == 'SUCCEEDED' ||
      paymentStatus == 'CAPTURED';

  DateTime? get validTillTime => DateTime.tryParse(validTill ?? '');

  bool get expired {
    final until = validTillTime;
    return until != null && until.isBefore(DateTime.now());
  }

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
    bookingId: (j['bookingId'] as String?) ?? '',
    status: (j['status'] as String?) ?? 'NEW',
    price: (j['price'] as num?) ?? 0,
    payment: j['payment'] is Map
        ? Map<String, dynamic>.from(j['payment'] as Map)
        : null,
    tickets: (j['tickets'] as List?) ?? const [],
    stations: (j['stations'] as List?) ?? const [],
  );

  /// Builds a booking from a `/tickets` list item (booking-level or a single
  /// ticket object).
  factory Booking.fromTicket(Map<String, dynamic> j) {
    final rawTickets = j['tickets'];
    final tickets = rawTickets is List ? rawTickets : [j];
    return Booking(
      bookingId:
          (j['bookingId'] as String?) ?? (j['ticketRef'] as String?) ?? '',
      status:
          (j['status'] as String?) ??
          (tickets.isNotEmpty ? 'CONFIRMED' : 'UNKNOWN'),
      price: (j['price'] as num?) ?? ((j['fare'] as num?) ?? 0),
      tickets: tickets,
      stations: (j['stations'] as List?) ?? const [],
    );
  }

  Map<String, dynamic>? get firstTicket {
    if (tickets.isEmpty) return null;
    final t = tickets.first;
    return t is Map ? Map<String, dynamic>.from(t) : null;
  }

  /// Scannable payload issued by the transit operator. CMRL tickets carry a
  /// signed `qrData` string; it must be shown verbatim at the gate.
  String get qrData {
    final ticket = firstTicket;
    if (ticket == null) return '';
    final qr = ticket['qrData'];
    if (qr is String && qr.isNotEmpty) return qr;
    final legacy = ticket['tickets'];
    if (legacy is List && legacy.isNotEmpty && legacy.first is String) {
      return legacy.first as String;
    }
    return '';
  }

  String get ticketNumber {
    final ticket = firstTicket;
    if (ticket == null) return '';
    final number =
        ticket['ticketNumber'] ?? ticket['ticketNo'] ?? ticket['ticketRef'];
    if (number is List) {
      return number.isEmpty ? '' : number.first.toString();
    }
    if (number != null && number.toString().isNotEmpty) {
      return number.toString();
    }
    // Direct BPP QR format: signature,ticketNumber,from,to,...
    final parts = qrData.split(',');
    return parts.length > 1 ? parts[1] : '';
  }

  /// Human-readable ticket id. Never use this as the QR payload.
  String get ticketRef => ticketNumber.isNotEmpty ? ticketNumber : bookingId;

  String? get validTill => firstTicket?['validTill']?.toString();

  String? _stationName(int index) {
    if (stations.isEmpty) return null;
    final i = index < 0 ? stations.length + index : index;
    if (i < 0 || i >= stations.length) return null;
    final station = stations[i];
    if (station is Map) {
      final name = station['name'] ?? station['stationName'];
      if (name is String && name.isNotEmpty) return name;
    }
    return null;
  }

  String? get fromName {
    final direct = firstTicket?['fromStation'];
    if (direct is String && direct.isNotEmpty) return direct;
    if (direct is Map) {
      final name = direct['name'];
      if (name is String && name.isNotEmpty) return name;
    }
    return _stationName(0);
  }

  String? get toName {
    final direct = firstTicket?['toStation'];
    if (direct is String && direct.isNotEmpty) return direct;
    if (direct is Map) {
      final name = direct['name'];
      if (name is String && name.isNotEmpty) return name;
    }
    return _stationName(-1);
  }
}

/// A locally persisted recent trip for one-tap repeat booking.
class RecentTrip {
  final String fromCode;
  final String fromName;
  final String toCode;
  final String toName;
  final int quantity;

  const RecentTrip({
    required this.fromCode,
    required this.fromName,
    required this.toCode,
    required this.toName,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
    'fromCode': fromCode,
    'fromName': fromName,
    'toCode': toCode,
    'toName': toName,
    'quantity': quantity,
  };

  factory RecentTrip.fromJson(Map<String, dynamic> j) => RecentTrip(
    fromCode: j['fromCode'] as String? ?? '',
    fromName: j['fromName'] as String? ?? '',
    toCode: j['toCode'] as String? ?? '',
    toName: j['toName'] as String? ?? '',
    quantity: j['quantity'] as int? ?? 1,
  );

  bool sameRoute(String from, String to) => fromCode == from && toCode == to;
}

class Profile {
  final String id;
  final String maskedMobile;
  final String gender;

  Profile({required this.id, required this.maskedMobile, required this.gender});

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: (j['id'] as String?) ?? '',
    maskedMobile: (j['maskedMobileNumber'] as String?) ?? '',
    gender: (j['gender'] as String?) ?? 'UNKNOWN',
  );
}

class AuthSession {
  final String? authId;
  final String? token;
  final String? userId;
  AuthSession({this.authId, this.token, this.userId});
}

class TransitMode {
  final String key;
  final String label;
  final String prefix;
  const TransitMode(this.key, this.label, this.prefix);

  static const metro = TransitMode('metro', 'Metro', 'M');
  static const bus = TransitMode('bus', 'Bus', 'B');
  static const all = [metro, bus];
}

extension BookingStatusX on Booking {
  bool get confirmed => status == 'CONFIRMED' || tickets.isNotEmpty;
}
