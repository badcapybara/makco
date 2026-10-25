import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class Api {
  /// API base. Currently the backend is served directly over the server IP
  /// (no domain/TLS). Override with --dart-define=API_BASE=...
  static const baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://163.123.236.154:8080',
  );

  static const _merchantId = 'NAMMA_YATRI';
  static const _clientId = 'NAMMA_YATRI';
  static const _tokenKey = 'makco_token';
  static const _userIdKey = 'makco_user_id';
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String? token;
  static String? userId;

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  static Map<String, String> _headers({bool auth = true}) => {
    'Content-Type': 'application/json',
    if (auth && token != null) 'token': token!,
  };

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? query,
  }) async {
    try {
      final res = await http
          .post(_uri(path, query), headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      return await _decode(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  static Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final res = await http
          .get(_uri(path, query), headers: _headers())
          .timeout(const Duration(seconds: 20));
      return await _decode(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  static Future<Map<String, dynamic>> _decode(http.Response res) async {
    final text = res.body.isEmpty ? '{}' : res.body;
    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw ApiException(
        'The server sent an unexpected reply (${res.statusCode}). Please try again.',
      );
    }

    // The proxy passes some upstream endpoints through as bare JSON arrays
    // (stations, routes, quotes, tickets). Normalise them under `data`.
    if (decoded is List) {
      if (res.statusCode >= 400) {
        throw ApiException('Something went wrong (${res.statusCode}).');
      }
      return <String, dynamic>{'data': decoded};
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'The server sent an unexpected reply (${res.statusCode}). Please try again.',
      );
    }

    final body = decoded;
    if (res.statusCode >= 400 || body['errorCode'] != null) {
      throw ApiException(
        (body['error'] as String?) ??
            (body['message'] as String?) ??
            (body['errorCode'] as String?) ??
            'Something went wrong (${res.statusCode}).',
        code: body['errorCode'] as String?,
        status: res.statusCode,
      );
    }
    return body;
  }

  // ---- Auth ----

  static Future<AuthSession> requestOtp(
    String phone, {
    String country = '+91',
  }) async {
    final body = await _post('/auth', {
      'mobileNumber': phone,
      'mobileCountryCode': country,
      'merchantId': _merchantId,
      'clientId': _clientId,
    });
    return AuthSession(authId: body['authId'] as String?);
  }

  static Future<AuthSession> verifyOtp(String authId, String otp) async {
    final body = await _post('/auth/$authId/verify', {
      'otp': otp,
      'deviceToken': 'flutter',
    });
    final session = AuthSession(
      token: body['token'] as String? ?? body['accessToken'] as String?,
    );
    if (session.token == null &&
        (body['status'] as String?) == 'OTP_VERIFIED') {
      // Token issued via subsequent /auth/token call is handled by app.
      throw ApiException('Code verified, but no token was returned.');
    }
    return session;
  }

  static Future<AuthSession> tokenFromCode(String authId) async {
    final body = await _post('/auth/$authId/token', {'clientId': _clientId});
    return AuthSession(
      token: body['token'] as String?,
      userId: body['userId'] as String?,
    );
  }

  static Future<void> saveSession(String? tok, String? uid) async {
    token = tok;
    userId = uid;
    try {
      if (tok == null) {
        await _secure.delete(key: _tokenKey);
        await _secure.delete(key: _userIdKey);
      } else {
        await _secure.write(key: _tokenKey, value: tok);
        if (uid == null) {
          await _secure.delete(key: _userIdKey);
        } else {
          await _secure.write(key: _userIdKey, value: uid);
        }
      }
    } catch (_) {
      // Unsupported platform or keystore failure; memory session still works.
    }
    // Remove any token left by older builds in plain preferences.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userIdKey);
    } catch (_) {}
  }

  static Future<String?> _readSecure(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> restoreSession() async {
    var tok = await _readSecure(_tokenKey);
    var uid = await _readSecure(_userIdKey);
    if (tok == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        tok = prefs.getString(_tokenKey);
        uid = prefs.getString(_userIdKey);
        if (tok != null) await saveSession(tok, uid);
      } catch (_) {}
    }
    token = tok;
    userId = uid;
    return token != null;
  }

  // ---- Transit ----

  static Future<List<Station>> stations(TransitMode mode) async {
    final body = await _get(
      '/transit/stations',
      query: {'city': 'chennai', 'mode': mode.key},
    );
    final list =
        (body['stations'] as List?) ?? (body['data'] as List?) ?? const [];
    return list
        .map((e) => Station.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<RouteInfo>> routes(TransitMode mode) async {
    final body = await _get(
      '/transit/routes',
      query: {'city': 'chennai', 'mode': mode.key},
    );
    final list =
        (body['routes'] as List?) ?? (body['data'] as List?) ?? const [];
    return list
        .map((e) => RouteInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> search(
    TransitMode mode,
    String from,
    String to,
    int qty,
  ) async {
    return _post(
      '/transit/search',
      {'fromStationCode': from, 'toStationCode': to, 'quantity': qty},
      query: {'city': 'chennai', 'mode': mode.key},
    );
  }

  static Future<List<Quote>> quote(String searchId, {String? mode}) async {
    final body = await _get(
      '/transit/search/$searchId/quote',
      query: {'city': 'chennai', 'mode': ?mode},
    );
    final routes =
        (body['routes'] as List?) ?? (body['data'] as List?) ?? const [];
    return routes
        .map((e) => Quote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Booking> confirm(
    String quoteId,
    int qty, {
    String? mode,
  }) async {
    final body = await _post(
      '/transit/quote/$quoteId/confirm',
      {'quantity': qty},
      query: {'city': 'chennai', 'mode': ?mode},
    );
    return Booking.fromJson(body);
  }

  static Future<Booking> bookingStatus(String bookingId, {String? mode}) async {
    final body = await _get(
      '/transit/booking/$bookingId/status',
      query: {'city': 'chennai', 'mode': ?mode},
    );
    return Booking.fromJson(body);
  }

  static Future<List<dynamic>> tickets() async {
    final body = await _get('/tickets', query: {'city': 'chennai'});
    return (body['tickets'] as List?) ?? (body['data'] as List?) ?? const [];
  }

  static Future<Profile> profile() async {
    final body = await _get('/profile');
    return Profile.fromJson(body['profile'] as Map<String, dynamic>? ?? body);
  }
}

class ApiException implements Exception {
  final String message;
  final String? code;
  final int? status;
  ApiException(this.message, {this.code, this.status});

  @override
  String toString() => message;
}
