class Station {
  final String code;
  final String name;
  final double? lat;
  final double? lon;

  Station({required this.code, required this.name, this.lat, this.lon});

  factory Station.fromJson(Map<String, dynamic> json) => Station(
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        lat: (json['lat'] as num?)?.toDouble(),
        lon: (json['lon'] as num?)?.toDouble(),
      );
}

class RouteInfo {
  final String code;
  final String longName;
  final String shortName;

  RouteInfo({required this.code, required this.longName, required this.shortName});

  factory RouteInfo.fromJson(Map<String, dynamic> json) => RouteInfo(
        code: json['code'] as String? ?? '',
        longName: json['longName'] as String? ?? '',
        shortName: json['shortName'] as String? ?? '',
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

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        type: json['_type'] as String? ?? 'Unknown',
        quoteId: json['quoteId'] as String? ?? '',
        price: json['price'] as num? ?? 0,
        quantity: json['quantity'] as int? ?? 1,
        validTill: json['validTill'] as String? ?? '',
      );
}

class Booking {
  final String bookingId;
  final String status;
  final num price;
  final Map<String, dynamic>? payment;
  final List<dynamic> tickets;

  Booking({
    required this.bookingId,
    required this.status,
    required this.price,
    this.payment,
    this.tickets = const [],
  });

  String get paymentUrl {
    try {
      final links = payment?['paymentOrder']?['payment_links']?['web'];
      return links as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        bookingId: json['bookingId'] as String? ?? '',
        status: json['status'] as String? ?? 'NEW',
        price: json['price'] as num? ?? 0,
        payment: json['payment'] as Map<String, dynamic>?,
        tickets: json['tickets'] as List<dynamic>? ?? const [],
      );
}

class Profile {
  final String id;
  final String maskedMobile;
  final String gender;

  Profile({required this.id, required this.maskedMobile, required this.gender});

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String? ?? '',
        maskedMobile: json['maskedMobileNumber'] as String? ?? '',
        gender: json['gender'] as String? ?? 'UNKNOWN',
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

  static const metro = TransitMode('metro', 'METRO', 'M');
  static const bus = TransitMode('bus', 'BUS', 'B');

  static const all = [metro, bus];
}
