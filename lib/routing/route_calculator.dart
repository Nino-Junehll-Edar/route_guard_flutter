import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'package:route_guard/models/hazard.dart';
import 'package:route_guard/services/service_locator.dart';
import 'package:route_guard/services/location_service.dart';
import 'package:route_guard/services/synchronized_database_service.dart';
import 'package:route_guard/routing/astar.dart';

/// Service for calculating routes that avoid hazards using A* algorithm
class RouteCalculator {
  late final SynchronizedDatabaseService _databaseService;
  late final LocationService _locationService;
  final AStar _astar = AStar();

  RouteCalculator() {
    final locator = ServiceLocator();
    _databaseService = locator.synchronizedDatabaseService;
    _locationService = locator.locationService;
  }

  /// Calculate a route from current location to destination avoiding hazards
  Future<List<LatLng>> calculateRouteToDestination({
    required LatLng destination,
    List<Hazard>? hazards,
  }) async {
    try {
      // Get current location
      final position = await _locationService.getCurrentPosition();
      final LatLng start = LatLng(position.latitude, position.longitude);

      // Get hazards if not provided
      final List<Hazard> hazardList = hazards ?? await _databaseService.getHazards();

      // Filter to only active hazards (impassable or partial)
      final List<Hazard> activeHazards = hazardList.where((hazard) {
        final status = hazard.status;
        return status == HazardStatus.impassable || status == HazardStatus.partial;
      }).toList();

      // Calculate route avoiding hazards
      return _astar.findPath(
        start: start,
        end: destination,
        hazards: activeHazards,
      );
    } catch (e) {
      // If location unavailable, return empty route or handle error
      // print('Error calculating route: $e');
      return [];
    }
  }

  /// Calculate a route between two points avoiding hazards
  Future<List<LatLng>> calculateRouteBetweenPoints({
    required LatLng start,
    required LatLng end,
    List<Hazard>? hazards,
  }) async {
    try {
      // Get hazards if not provided
      final List<Hazard> hazardList = hazards ?? await _databaseService.getHazards();

      // Filter to only active hazards (impassable or partial)
      final List<Hazard> activeHazards = hazardList.where((hazard) {
        final status = hazard.status;
        return status == HazardStatus.impassable || status == HazardStatus.partial;
      }).toList();

      // Calculate route avoiding hazards
      return _astar.findPath(
        start: start,
        end: end,
        hazards: activeHazards,
      );
    } catch (e) {
      // print('Error calculating route between points: $e');
      return [start, end]; // Return direct path as fallback
    }
  }

  /// Get a stream of route updates as the user moves
  Stream<List<LatLng>> routeToDestinationStream({
    required LatLng destination,
  }) async* {
    // Get initial location
    final position = await _locationService.getCurrentPosition();
    final LatLng start = LatLng(position.latitude, position.longitude);

    // Get active hazards
    final hazards = await _databaseService.getHazards();
    final activeHazards = hazards.where((hazard) {
      final status = hazard.status;
      return status == HazardStatus.impassable || status == HazardStatus.partial;
    }).toList();

    // Calculate initial route
    final initialRoute = _astar.findPath(
      start: start,
      end: destination,
      hazards: activeHazards,
    );
    yield initialRoute;

    // Listen to location updates and recalculate when significant movement occurs
    final locationStream = _locationService.positionStream();
    LatLng? lastRouteStart;
    DateTime? lastRouteCalculationTime;

    await for (final position in locationStream) {
      final currentPosition = LatLng(position.latitude, position.longitude);

      // Recalculate if we've moved significantly (>10m) or if route is old
      final bool shouldRecalculate = lastRouteStart == null ||
          LocationService.distanceBetween(lastRouteStart, currentPosition) > 10 ||
          (lastRouteCalculationTime == null ||
              DateTime.now().difference(lastRouteCalculationTime).inSeconds > 30); // Recalculate every 30 seconds

      if (shouldRecalculate) {
        final newRoute = _astar.findPath(
          start: currentPosition,
          end: destination,
          hazards: activeHazards,
        );
        lastRouteStart = currentPosition;
        lastRouteCalculationTime = DateTime.now();
        yield newRoute;
      }
    }
  }
}