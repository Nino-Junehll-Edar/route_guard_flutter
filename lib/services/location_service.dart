import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:route_guard/services/performance_monitoring_service.dart';

class LocationService {
  final PerformanceMonitoringService _perfService = PerformanceMonitoringService();

  LocationService();

  Future<Position> getCurrentPosition() async {
    return await _perfService.logDurationWithResult<Position>('GetCurrentPosition', () async {
      bool serviceEnabled;
      LocationPermission permission;

      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return Future.error('Location services are disabled.');
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return Future.error('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return Future.error(
            'Location permissions are permanently denied, we cannot request permissions.');
      }

      return await Geolocator.getCurrentPosition();
    });
  }

  Stream<Position> positionStream() {
    return _perfService.logDurationSync<Stream<Position>>('PositionStream', () {
      return Geolocator.getPositionStream();
    });
  }

  /// Calculate the distance between two points in meters.
  static double distanceBetween(
    LatLng start,
    LatLng end,
  ) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  /// Check if a hazard is within the notification range (default 500 meters).
  static bool isWithinNotificationRange(
    LatLng userLocation,
    LatLng hazardLocation, {
    double rangeInMeters = 500,
  }) {
    final distance = distanceBetween(userLocation, hazardLocation);
    return distance <= rangeInMeters;
  }
}