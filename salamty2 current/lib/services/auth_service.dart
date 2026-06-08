import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kAccessToken = 'access_token';
const _kRefreshToken = 'refresh_token';
const _kUserId = 'user_id';

class AuthService {
  static final _storage = FlutterSecureStorage();
  static Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('device_id');
    if (saved != null) return saved;
    final deviceId = const Uuid().v4();
    await prefs.setString('device_id', deviceId);
    return deviceId;
  }

  // ── Token helpers ──────────────────────────────────────────

  static Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
    ]);
  }

  static Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: _kRefreshToken);

  static Future<String?> getUserId() => _storage.read(key: _kUserId);

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> signOut() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kUserId),
    ]);
  }

  // ── Register ───────────────────────────────────────────────
  // Returns null on success, error string on failure.

  static Future<String?> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required int age,
    required String bloodType, // e.g. "AB_PLUS"
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register/driver'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'phone': phone,
          'password': password,
          'age': age,
          'bloodType': bloodType,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 || res.statusCode == 201) return null;
      return _extractError(body);
    } catch (e) {
      return 'Network error. Please check your connection.';
    }
  }

  // ── Login ──────────────────────────────────────────────────
  // Returns null on success (tokens saved), error string on failure.

  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final deviceId = await _getDeviceId();
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'deviceId': deviceId,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = body['data'] as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>;
        await _saveTokens(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
        );
        await _storage.write(key: _kUserId, value: user['id'] as String);
        return null;
      }
      return _extractError(body);
    } catch (e) {
      return 'Network error: $e';
    }
  }

  // ── Send Verification Email ────────────────────────────────
  // GET /auth/verify-mail/:email
  // Returns null on success, error string on failure.

  static Future<String?> sendVerificationEmail(String email) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/verify-mail/$email'),
      );
      if (res.statusCode == 200 || res.statusCode == 201) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return _extractError(body);
    } catch (_) {
      return 'Network error. Please check your connection.';
    }
  }

  // ── Error extractor ────────────────────────────────────────
  // NestJS returns { message: '...' } or { message: [...] }

  static String _extractError(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map) {
      final msg = data['message'];
      if (msg is String) return msg;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
    }
    return 'Something went wrong. Please try again.';
  }
}
