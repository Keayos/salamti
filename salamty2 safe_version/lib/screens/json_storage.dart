import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class JsonStorage {
  static final JsonStorage instance = JsonStorage._();
  JsonStorage._();

  Future<File> get _file async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/app_data.json');
  }

  /// Reads the entire JSON file into a Map.
  Future<Map<String, dynamic>> readAll() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      // Return empty map if file doesn't exist or is corrupted
      print("Error reading JSON: $e");
    }
    return {};
  }

  /// Writes a specific key-value pair to the JSON file.
  Future<void> write(String key, dynamic value) async {
    final data = await readAll();
    data[key] = value;
    final file = await _file;
    await file.writeAsString(jsonEncode(data));
  }
}