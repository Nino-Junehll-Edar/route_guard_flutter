import 'package:route_guard/services/location_service.dart';
import 'package:route_guard/services/notification_service.dart';
import 'package:route_guard/services/database_service.dart';
import 'package:route_guard/services/performance_monitoring_service.dart';
import 'package:latlong2/latlong.dart';

class ProximityNotificationService {
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final DatabaseService _databaseService = DatabaseService();
  final PerformanceMonitoringService _perfService = PerformanceMonitoringService();

  bool _isInitialized = false;
  final Set<String> _notifiedHazardIds = {};

  Future<void> initialize() async {
    return _perfService.logDuration('Initialize', () async {
      if (_isInitialized) return;

      await _notificationService.initialize();
      _isInitialized = true;
    });
  }

  Future<void> checkCurrentPositionForHazards() async {
    return _perfService.logDuration('CheckCurrentPositionForHazards', () async {
      if (!_isInitialized) await initialize();

      try {
        final position = await _locationService.getCurrentPosition();
        final userLocation = LatLng(position.latitude, position.longitude);

        // Get active (impassable) hazards
        final hazards = await _databaseService.getHazards(status: 'impassable');

        for (final hazard in hazards) {
          final hazardLocation = LatLng(hazard.latitude, hazard.longitude);
          final isInRange = LocationService.isWithinNotificationRange(
            userLocation,
            hazardLocation,
            rangeInMeters: 500, // 500 meters as specified
          );

          if (isInRange && !_notifiedHazardIds.contains(hazard.id)) {
            // Show notification for this hazard
            await _notificationService.showLocalNotification(
              title: 'Hazard Alert',
              body: 'You are near an active hazard: ${hazard.hazardType}',
              payload: {
                'hazard_id': hazard.id,
                'hazard_type': hazard.hazardType,
              },
            );

            _notifiedHazardIds.add(hazard.id);

            // Remove from notified set after some time to allow re-notification
            // if the hazard is still active later
            Future.delayed(const Duration(minutes: 30), () {
              _notifiedHazardIds.remove(hazard.id);
            });
          }
        }
      } catch (e) {
        // Handle errors (location denied, etc.)
        // Error checking proximity: $e
      }
    });
  }

  void dispose() {
    // Clean up any streams if needed
  }
}