import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class ApiService {
  // ── Auth header ────────────────────────────────────────────

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Individual endpoint helpers ─────────────────────────────

  static Future<bool> saveProfile(Map<String, dynamic> data) =>
      _post('/user/profile', data);

  static Future<bool> saveVehicle(Map<String, dynamic> data) =>
      _post('/user/vehicle', data);

  static Future<bool> saveHealth(Map<String, dynamic> data) =>
      _post('/health', data);

  static Future<bool> saveContacts(List<dynamic> contacts) =>
      _post('/contacts', {'contacts': contacts});

  // ── Private helper ─────────────────────────────────────────

  static Future<bool> _post(String path, dynamic body) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: await _headers(),
        body: jsonEncode(body),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('API Error: $e');
      return false;
    }
  }
}
