import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'package:route_guard/models/hazard.dart';
import 'package:route_guard/services/service_locator.dart';
import 'package:route_guard/services/location_service.dart';
import 'package:route_guard/services/synchronized_database_service.dart';
import 'package:route_guard/services/osm_service.dart';
import 'package:route_guard/routing/astar.dart';
import 'package:route_guard/routing/graph_astar.dart';
import 'package:route_guard/routing/hazard_integrator.dart';
import 'package:route_guard/routing/road_graph.dart';

/// Service for calculating routes that avoid hazards using A* algorithm
class RouteCalculator {
  late final SynchronizedDatabaseService _databaseService;
  late final LocationService _locationService;
  late final OsmService _osmService;
  late final RoadGraph _roadGraph;
  late final HazardIntegrator _hazardIntegrator;
  late final GraphAStar _graphAStar;
  final AStar _legacyAstar = AStar(); // Keep for fallback

  RouteCalculator() {
    final locator = ServiceLocator();
    _databaseService = locator.synchronizedDatabaseService;
    _locationService = locator.locationService;
    _osmService = OsmService(locator.localCacheService);
    _roadGraph = RoadGraph();
    _hazardIntegrator = HazardIntegrator();
    _graphAStar = GraphAStar();
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

      // Calculate route avoiding hazards using OSM-based routing
      return _calculateRouteWithOsm(
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

      // Calculate route avoiding hazards using OSM-based routing
      return _calculateRouteWithOsm(
        start: start,
        end: end,
        hazards: activeHazards,
      );
    } catch (e) {
      // print('Error calculating route between points: $e');
      return [start, end]; // Return direct path as fallback
    }
  }

  /// Calculate a route using OSM-based routing with hazard avoidance
  Future<List<LatLng>> _calculateRouteWithOsm({
    required LatLng start,
    required LatLng end,
    required List<Hazard> hazards,
  }) async {
    try {
      // Get OSM data for the area between start and end points
      final OsmData osmData = await _osmService.fetchOsmDataForBounds(
        start: start,
        end: end,
      );

      // Build the road graph from OSM data
      _roadGraph.buildFromOsmData(osmData);

      // Apply hazard penalties to the graph
      _hazardIntegrator.applyHazardsToGraph(_roadGraph, hazards);

      // Find nearest graph nodes to start and end points
      final GraphNode? startNode = _roadGraph.getNearestNode(
        start,
        maxDistance: 100.0, // 100m maximum walk to road
      );
      final GraphNode? endNode = _roadGraph.getNearestNode(
        end,
        maxDistance: 100.0,
      );

      // If we can't connect to the road network, fall back to geometric A*
      if (startNode == null || endNode == null) {
        // Fall back to legacy geometric A* algorithm
        return _legacyAstar.findPath(
          start: start,
          end: end,
          hazards: hazards,
        );
      }

      // Find path using graph-based A*
      final List<LatLng> graphPath = _graphAStar.findPath(
        start: start,
        end: end,
        graph: _roadGraph,
      );

      // If graph-based routing failed to find a path, fall back to geometric A*
      if (graphPath.length <= 1) {
        return _legacyAstar.findPath(
          start: start,
          end: end,
          hazards: hazards,
        );
      }

      return graphPath;
    } catch (e) {
      // If OSM-based routing fails, fall back to geometric A*
      return _legacyAstar.findPath(
        start: start,
        end: end,
        hazards: hazards,
      );
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

    // Calculate initial route using OSM-based routing
    final initialRoute = await _calculateRouteWithOsm(
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
        final newRoute = await _calculateRouteWithOsm(
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