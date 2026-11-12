import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/student.dart';

class StorageService {
  static const _boardingLogKey = 'boarding_log';
  static const _stopsKey = 'bus_stops';

  static Future<void> saveBoardingLog(List<BoardingRecord> log) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = log
        .map(
          (r) => {
            'studentNumber': r.studentNumber,
            'studentName': r.studentName,
            'wasFunded': r.wasFunded,
            'stopName': r.stopName,
            'timestamp': r.timestamp.toIso8601String(),
            'overridden': r.overridden,
          },
        )
        .toList();
    final saved = await prefs.setString(_boardingLogKey, jsonEncode(jsonList));
    if (!saved) {
      throw StateError('Boarding records could not be saved.');
    }
  }

  static Future<List<BoardingRecord>> loadBoardingLog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_boardingLogKey);
    if (raw == null) {
      return [];
    }
    final List decoded = jsonDecode(raw);
    return decoded
        .map(
          (r) => BoardingRecord(
            studentNumber: r['studentNumber'],
            studentName: r['studentName'],
            wasFunded: r['wasFunded'],
            stopName: r['stopName'],
            timestamp: DateTime.parse(r['timestamp']),
            overridden: r['overridden'] ?? false,
          ),
        )
        .toList();
  }

  static Future<void> saveStops(List<String> stops) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_stopsKey, jsonEncode(stops));
    if (!saved) {
      throw StateError('Stops could not be saved.');
    }
  }

  static Future<List<String>?> loadStops() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stopsKey);
    if (raw == null) {
      return null;
    }
    return List<String>.from(jsonDecode(raw));
  }
}
