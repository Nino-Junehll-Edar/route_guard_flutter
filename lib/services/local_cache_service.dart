import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:route_guard/models/hazard.dart';

/// Service for local caching using shared_preferences
class LocalCacheService {
  static const String _hazardsCacheKey = 'cached_hazards';
  static const String _pendingReportsKey = 'pending_hazard_reports';

  final SharedPreferences _prefs;

  LocalCacheService(this._prefs);

  /// Generic method to get a string value from cache
  Future<String?> getString(String key) async {
    return _prefs.getString(key);
  }

  /// Generic method to set a string value in cache
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  /// Generic method to remove a value from cache
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  /// Cache a list of hazards locally
  Future<void> cacheHazards(List<Hazard> hazards) async {
    try {
      final jsonList = hazards.map((hazard) => hazard.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await _prefs.setString(_hazardsCacheKey, jsonString);
    } catch (e) {
      // Ignore cache errors - we don't want to break the app if caching fails
    }
  }

  /// Get cached hazards from local storage
  Future<List<Hazard>> getCachedHazards() async {
    try {
      final jsonString = _prefs.getString(_hazardsCacheKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => Hazard.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Return empty list if we can't read cache
      return [];
    }
  }

  /// Clear cached hazards
  Future<void> clearCachedHazards() async {
    await _prefs.remove(_hazardsCacheKey);
  }

  /// Add a hazard report to the pending queue (for offline submission)
  Future<void> addPendingReport(Hazard hazard) async {
    try {
      final pendingReports = await getPendingReports();
      pendingReports.add(hazard);
      final jsonList = pendingReports.map((h) => h.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await _prefs.setString(_pendingReportsKey, jsonString);
    } catch (e) {
      // Ignore cache errors
    }
  }

  /// Get pending hazard reports that need to be submitted
  Future<List<Hazard>> getPendingReports() async {
    try {
      final jsonString = _prefs.getString(_pendingReportsKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => Hazard.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Clear all pending reports (after successful submission)
  Future<void> clearPendingReports() async {
    await _prefs.remove(_pendingReportsKey);
  }

  /// Get count of pending reports
  Future<int> getPendingReportsCount() async {
    final pendingReports = await getPendingReports();
    return pendingReports.length;
  }
}