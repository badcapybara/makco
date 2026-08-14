import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8080';

  String? _token;

  void setToken(String token) => _token = token;
  String? get token => _token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'token': _token!,
      };

  Future<AuthSession> initiateAuth(String mobileNumber) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth'),
      headers: _headers,
      body: jsonEncode({
        'mobileNumber': mobileNumber,
        'mobileCountryCode': '+91',
        'merchantId': 'NAMMA_YATRI',
        'clientId': 'NAMMA_YATRI',
      }),
    );
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return AuthSession(authId: data['authId'] as String?);
  }

  Future<AuthSession> verifyAuth(String authId, String otp) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/$authId/verify'),
      headers: _headers,
      body: jsonEncode({'otp': otp, 'deviceToken': 'makco_device'}),
    );
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['token'] != null) {
      setToken(data['token'] as String);
    }
    return AuthSession(token: data['token'] as String?, userId: data['userId'] as String?);
  }

  Future<List<Station>> getStations(TransitMode mode, String city) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/transit/stations?city=$city&mode=${mode.key}'),
      headers: _headers,
    );
    final data = jsonDecode(resp.body) as List;
    return data.map((e) => Station.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<RouteInfo>> getRoutes(TransitMode mode, String city) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/transit/routes?city=$city&mode=${mode.key}'),
      headers: _headers,
    );
    final data = jsonDecode(resp.body) as List;
    return data.map((e) => RouteInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> searchFare(TransitMode mode, String city, String from, String to, {int qty = 1}) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/transit/search?city=$city&mode=${mode.key}'),
      headers: _headers,
      body: jsonEncode({
        'fromStationCode': from,
        'toStationCode': to,
        'quantity': qty,
      }),
    );
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['searchId'] as String? ?? '';
  }

  Future<List<Quote>> getQuotes(TransitMode mode, String city, String searchId) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/transit/search/$searchId/quote?city=$city&mode=${mode.key}'),
      headers: _headers,
    );
    final data = jsonDecode(resp.body) as List;
    return data.map((e) => Quote.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Booking> confirmBooking(TransitMode mode, String city, String quoteId, {int qty = 1}) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/transit/quote/$quoteId/confirm?city=$city&mode=${mode.key}'),
      headers: _headers,
      body: jsonEncode({'quantity': qty}),
    );
    return Booking.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<Booking> getBookingStatus(TransitMode mode, String city, String bookingId) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/transit/booking/$bookingId/status?city=$city&mode=${mode.key}'),
      headers: _headers,
    );
    return Booking.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<Profile> getProfile() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/profile'),
      headers: _headers,
    );
    return Profile.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<List<Booking>> getTickets(TransitMode mode, String city) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/tickets?city=$city&mode=${mode.key}'),
      headers: _headers,
    );
    final data = jsonDecode(resp.body) as List;
    return data.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
  }
}
