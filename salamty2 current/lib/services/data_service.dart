import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════════════════════
// DATA SERVICE  —  single JSON file: {app_documents}/salamty_data.json
// ═══════════════════════════════════════════════════════════════════════════════
//
// JSON shape:
// {
//   "profile":   { "name", "phone", "vehicleMake", "vehicleColor",
//                  "vehicleYear", "vehiclePlate" },
//   "health":    { "bloodType", "conditions":[], "meds":[], "allergies":[] },
//   "contacts":  [ { "id", "name", "rel", "phone", "initials", "notify" } ],
//   "documents": [ { "docType", "name", "path", "size", "uploadedAt" } ]
// }

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

class DataService {
  DataService._();
  static final DataService instance = DataService._();

  static const _fileName = 'salamty_data.json';

  // ── File access ─────────────────────────────────────────────────────────────
  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  // ── Read the whole document ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> readAll() async {
    try {
      final f = await _file;
      if (!await f.exists()) return _defaultData();
      final raw = await f.readAsString();
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return _defaultData();
    }
  }

  // ── Write back the whole document ───────────────────────────────────────────
  Future<void> _writeAll(Map<String, dynamic> data) async {
    final f = await _file;
    await f.writeAsString(jsonEncode(data), flush: true);
  }

  // ── Section helpers ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> readSection(String key) async {
    final all = await readAll();
    return (all[key] as Map<String, dynamic>?) ?? {};
  }

  Future<List<dynamic>> readList(String key) async {
    final all = await readAll();
    return (all[key] as List<dynamic>?) ?? [];
  }

  Future<void> writeSection(String key, dynamic value) async {
    final all = await readAll();
    all[key] = value;
    await _writeAll(all);
  }

  // ── Profile ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> readProfile() => readSection('profile');

  Future<void> saveProfile(Map<String, dynamic> profile) =>
      writeSection('profile', profile);

  // ── Health ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> readHealth() => readSection('health');

  Future<void> saveHealth(Map<String, dynamic> health) =>
      writeSection('health', health);

  // ── Contacts ─────────────────────────────────────────────────────────────────
  Future<List<dynamic>> readContacts() => readList('contacts');

  Future<void> saveContacts(List<Map<String, dynamic>> contacts) =>
      writeSection('contacts', contacts);

  // ── Documents ────────────────────────────────────────────────────────────────
  Future<List<dynamic>> readDocuments() => readList('documents');

  Future<void> saveDocuments(List<Map<String, dynamic>> docs) =>
      writeSection('documents', docs);

  // ── Default empty structure ──────────────────────────────────────────────────
  static Map<String, dynamic> _defaultData() => {
        'profile': {
          'name': '',
          'phone': '',
          'vehicleMake': '',
          'vehicleColor': '',
          'vehicleYear': '2026',
          'vehiclePlate': '',
        },
        'health': {
          'bloodType': '',
          'conditions': [],
          'meds': [],
          'allergies': [],
        },
        'contacts': [],
        'documents': [],
      };
}
