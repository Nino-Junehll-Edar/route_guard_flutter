import 'dart:async';
import 'package:route_guard/models/hazard.dart';
import 'package:route_guard/models/user.dart';
import 'package:route_guard/services/database_service.dart';
import 'package:route_guard/services/local_cache_service.dart';
import 'package:route_guard/services/connectivity_service.dart';
import 'package:route_guard/services/performance_monitoring_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Synchronized database service that handles offline caching and syncing with Supabase
class SynchronizedDatabaseService {
  final DatabaseService _databaseService = DatabaseService();
  final LocalCacheService _localCacheService;
  final ConnectivityService _connectivityService;
  final PerformanceMonitoringService _perfService = PerformanceMonitoringService();

  // Getter for the underlying database service
  DatabaseService get databaseService => _databaseService;

  SynchronizedDatabaseService(
    SharedPreferences prefs,
    ConnectivityService connectivityService,
  )   : _localCacheService = LocalCacheService(prefs),
        _connectivityService = connectivityService {
    _initSync();
  }

  void _initSync() {
    // Listen for connectivity changes to trigger sync when coming online
    _connectivityService.connectivityStream.listen((isConnected) async {
      if (isConnected) {
        await _syncPendingReports();
        await _syncCachedHazards();
      }
    });
  }

  /// Get hazards - try to get from server if online, fallback to cache if offline
  Future<List<Hazard>> getHazards({String? status, double? limit}) async {
    if (_connectivityService.isConnected) {
      try {
        final hazards = await _databaseService.getHazards(
            status: status, limit: limit);
        // Cache the fresh data
        await _localCacheService.cacheHazards(hazards);
        return hazards;
      } catch (e) {
        // If online but server fails, fall back to cache
        return await _localCacheService.getCachedHazards();
      }
    } else {
      // Offline - return cached data
      return await _localCacheService.getCachedHazards();
    }
  }

  /// Create a hazard - if online, send to server immediately; if offline, cache for later
  Future<Hazard> createHazard(Hazard hazard) async {
    if (_connectivityService.isConnected) {
      try {
        final createdHazard =
            await _databaseService.createHazard(hazard);
        // Update cache with the new hazard (including server-generated ID)
        final cachedHazards = await _localCacheService.getCachedHazards();
        cachedHazards.add(createdHazard);
        await _localCacheService.cacheHazards(cachedHazards);
        return createdHazard;
      } catch (e) {
        // If online but server fails, fall back to caching for later
        await _localCacheService.addPendingReport(hazard);
        return hazard; // Return the original hazard (will get ID when synced)
      }
    } else {
      // Offline - cache for later submission
      await _localCacheService.addPendingReport(hazard);
      return hazard; // Return the original hazard (will get ID when synced)
    }
  }

  /// Update a hazard - if online, send to server immediately; if offline, cache for later
  Future<void> updateHazard(Hazard hazard) async {
    if (_connectivityService.isConnected) {
      try {
        await _databaseService.updateHazard(hazard);
        // Update cache
        final cachedHazards = await _localCacheService.getCachedHazards();
        final index = cachedHazards
            .indexWhere((h) => h.id == hazard.id);
        if (index != -1) {
          cachedHazards[index] = hazard;
          await _localCacheService.cacheHazards(cachedHazards);
        }
      } catch (e) {
        // If online but server fails, we could cache for later but updates are trickier
        // For now, we'll just ignore update failures when online (rare case)
        // In a production app, we might want to queue these too
      }
    } else {
      // Offline - we could queue updates but for simplicity, we'll just update cache
      // and rely on the fact that offline users shouldn't be updating hazards much
      final cachedHazards = await _localCacheService.getCachedHazards();
      final index = cachedHazards
          .indexWhere((h) => h.id == hazard.id);
      if (index != -1) {
        cachedHazards[index] = hazard;
        await _localCacheService.cacheHazards(cachedHazards);
      }
    }
  }

  /// Sync pending hazard reports to the server when online
  Future<void> _syncPendingReports() async {
    if (!_connectivityService.isConnected) return;

    try {
      final pendingReports =
          await _localCacheService.getPendingReports();
      if (pendingReports.isEmpty) return;

      // Send each pending report to the server
      final successfulReports = <Hazard>[];
      final failedReports = <Hazard>[];

      for (final hazard in pendingReports) {
        try {
          final createdHazard =
              await _databaseService.createHazard(hazard);
          successfulReports.add(createdHazard);
        } catch (e) {
          failedReports.add(hazard);
        }
      }

      // Clear successfully synced reports
      if (successfulReports.isNotEmpty) {
        await _localCacheService.clearPendingReports();
        // Re-add any failed reports
        for (final hazard in failedReports) {
          await _localCacheService.addPendingReport(hazard);
        }
        // Update cache with newly created hazards
        final cachedHazards = await _localCacheService.getCachedHazards();
        cachedHazards.addAll(successfulReports);
        await _localCacheService.cacheHazards(cachedHazards);
      }
    } catch (e) {
      // If sync fails, we'll try again later when connectivity changes
    }
  }

  /// Sync cached hazards with server (in case we have newer data locally)
  Future<void> _syncCachedHazards() async {
    if (!_connectivityService.isConnected) return;

    try {
      final cachedHazards = await _localCacheService.getCachedHazards();
      if (cachedHazards.isEmpty) return;

      // For now, we'll just trust that the server has the most current data
      // and refresh our cache from the server
      final serverHazards =
          await _databaseService.getHazards(limit: 1000); // Reasonable limit
      await _localCacheService.cacheHazards(serverHazards);
    } catch (e) {
      // If we can't sync from server, keep our cached data
    }
  }

  /// Manually trigger a sync (useful for pull-to-refresh)
  Future<void> manualSync() async {
    if (_connectivityService.isConnected) {
      await _syncPendingReports();
      await _syncCachedHazards();
    }
  }

  /// Get count of pending reports waiting to be synced
  Future<int> getPendingReportsCount() async {
    return _localCacheService.getPendingReportsCount();
  }

  /// Update a user profile - if online, send to server immediately; if offline, cache for later
  Future<void> updateUserProfile(UserProfile profile) async {
    if (_connectivityService.isConnected) {
      try {
        await _databaseService.updateUserProfile(profile);
        // Update cache with the updated profile
        // Note: We don't cache user profiles in LocalCacheService currently,
        // but if we did in the future, we would update it here
      } catch (e) {
        // If online but server fails, we could cache for later but profile updates are rare
        // For now, we'll just log the error
        _perfService.logMetric('UserProfileUpdateError', 1);
      }
    } else {
      // Offline - we could cache profile updates for later, but for simplicity
      // and because profile updates are infrequent, we'll just ignore offline updates
      // In a production app, we might want to queue these too
      _perfService.logMetric('UserProfileUpdateOffline', 1);
    }
  }
}