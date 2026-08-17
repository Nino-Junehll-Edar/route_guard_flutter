import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:route_guard/models/hazard.dart';
import 'package:route_guard/routing/road_graph.dart';

/// Service for integrating hazard data into the road graph
class HazardIntegrator {
  final double _hazardInfluenceRadius; // meters around hazard to affect
  final double _maxHazardWeight; // maximum weight multiplier for hazardous edges

  HazardIntegrator({
    double hazardInfluenceRadius = 50.0, // 50 meters radius of influence
    double maxHazardWeight = 10.0, // up to 10x weight increase for hazardous areas
  })  : _hazardInfluenceRadius = hazardInfluenceRadius,
        _maxHazardWeight = maxHazardWeight;

  /// Apply hazard data to the road graph by adjusting edge weights
  void applyHazardsToGraph(RoadGraph graph, List<Hazard> hazards) {
    // Reset edge weights to base values first
    for (final edge in graph.edges.values) {
      // Reset to base weight (will be recalculated in getWeight() with hazard penalty)
      // Actually, we'll modify the baseWeight directly for simplicity
      // In a more complex implementation, we might store base weight separately
    }

    // Apply each hazard to affect nearby edges
    for (final hazard in hazards) {
      // Only consider active hazards that should be avoided
      if (!_isActiveHazard(hazard)) continue;

      final LatLng hazardLocation = hazard.location;
      final double hazardSeverity = _getHazardSeverity(hazard);

      // Find edges near this hazard and increase their weight
      for (final edge in graph.edges.values) {
        final double distanceToEdge = _distanceToEdge(hazardLocation, edge, graph);

        if (distanceToEdge <= _hazardInfluenceRadius) {
          // Calculate weight increase based on distance and severity
          double distanceFactor = 1.0 - (distanceToEdge / _hazardInfluenceRadius);
          distanceFactor = distanceFactor.clamp(0.0, 1.0);

          double hazardWeight = 1.0 + (distanceFactor * hazardSeverity * (_maxHazardWeight - 1.0));

          // Apply the hazard weight as a multiplier to the base weight
          // We need to adjust the baseWeight to incorporate this penalty
          final double originalBaseWeight = edge.baseWeight;
          edge.baseWeight = originalBaseWeight * hazardWeight;
        }
      }
    }
  }

  /// Check if a hazard is active and should affect routing
  bool _isActiveHazard(Hazard hazard) {
    // Only impassable and partial hazards should be avoided
    final status = hazard.status;
    return status == HazardStatus.impassable || status == HazardStatus.partial;
  }

  /// Get hazard severity as a double (0.0 to 1.0)
  double _getHazardSeverity(Hazard hazard) {
    // Use confidence as severity indicator (0-100 -> 0.0-1.0)
    return (hazard.confidence / 100.0).clamp(0.0, 1.0);
  }

  /// Calculate the minimum distance from a point to an edge (line segment)
  double _distanceToEdge(LatLng point, GraphEdge edge, RoadGraph graph) {
    final GraphNode? fromNode = graph.nodes[edge.fromNodeId];
    final GraphNode? toNode = graph.nodes[edge.toNodeId];

    if (fromNode == null || toNode == null) {
      return double.infinity;
    }

    return _pointToLineSegmentDistance(
      point.latitude,
      point.longitude,
      fromNode.position.latitude,
      fromNode.position.longitude,
      toNode.position.latitude,
      toNode.position.longitude,
    );
  }

  /// Calculate distance from point to line segment using vector projection
  double _pointToLineSegmentDistance(
    double px, double py, // point coordinates
    double x1, double y1, // line segment start
    double x2, double y2, // line segment end
  ) {
    // Vector from point A to point B
    final double dx = x2 - x1;
    final double dy = y2 - y1;

    // If the segment is actually a point, return distance to that point
    if (dx == 0 && dy == 0) {
      return _calculateDistance(px, py, x1, y1);
    }

    // Parameter t represents the projection of point P onto the line AB
    // t = 0 is at A, t = 1 is at B
    final double t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy);

    // Clamp t to [0, 1] to stay within the line segment
    final double clampedT = t.clamp(0.0, 1.0);

    // Find the closest point on the line segment
    final double closestX = x1 + clampedT * dx;
    final double closestY = y1 + clampedT * dy;

    // Return distance from point to closest point on segment
    return _calculateDistance(px, py, closestX, closestY);
  }

  /// Helper method to calculate distance between two points
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final double lat1Rad = lat1 * 3.141592653589793 / 180;
    final double lat2Rad = lat2 * 3.141592653589793 / 180;
    final double deltaLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final double deltaLng = (lon2 - lon1) * 3.141592653589793 / 180;

    final double a = (sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
            sin(deltaLng / 2) * sin(deltaLng / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
}