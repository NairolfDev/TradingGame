import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Named, device-local market views. Invalid saved entries are ignored.
class MarketFilterViews {
  static const storageKey = 'tg_market_filter_views_v1';

  Future<Map<String, Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString(storageKey) ?? '{}');
      if (raw is! Map<String, dynamic>) return {};
      return {
        for (final entry in raw.entries)
          if (entry.key.trim().isNotEmpty &&
              entry.value is Map<String, dynamic>)
            entry.key: Map<String, dynamic>.from(entry.value as Map),
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> save(Map<String, Map<String, dynamic>> views) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(storageKey, jsonEncode(views))) {
      throw StateError('Filteransichten konnten nicht gespeichert werden.');
    }
  }
}
