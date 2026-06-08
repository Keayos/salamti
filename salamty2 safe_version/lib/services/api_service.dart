import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Change this to your server's IP when testing on a real device.
  // Use 10.0.2.2 for Android emulator, localhost for iOS simulator.
  static const String _baseUrl = 'http://10.0.2.2:3000';

  // ── Send all user data at once ──────────────────────────────
  static Future<bool> syncUserData(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/user/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('API Error: $e');
      return false;
    }
  }

  // ── Individual endpoint helpers ─────────────────────────────
  static Future<bool> saveProfile(Map<String, dynamic> data) async {
    return _post('/api/user/profile', data);
  }

  static Future<bool> saveVehicle(Map<String, dynamic> data) async {
    return _post('/api/user/vehicle', data);
  }

  static Future<bool> saveHealth(Map<String, dynamic> data) async {
    return _post('/api/health', data);
  }

  static Future<bool> saveContacts(List<dynamic> contacts) async {
    return _post('/api/contacts', {'contacts': contacts});
  }

  static Future<bool> _post(String path, dynamic body) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('API Error: $e');
      return false;
    }
  }
}
