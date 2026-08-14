import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:route_guard/models/hazard.dart';

/// A* pathfinding algorithm for finding routes around hazards
class AStar {
  final double hazardAvoidanceWeight; // Higher values = stronger hazard avoidance
  final double maxRouteDeviation;     // Maximum deviation from direct path (as ratio)

  AStar({
    this.hazardAvoidanceWeight = 2.0,
    this.maxRouteDeviation = 0.3, // 30% max deviation from direct path
  });

  /// Find a path from start to end avoiding hazards
  List<LatLng> findPath({
    required LatLng start,
    required LatLng end,
    required List<Hazard> hazards,
    int maxIterations = 1000,
  }) {
    if (hazards.isEmpty) {
      // No hazards, return direct path
      return [start, end];
    }

    // Convert hazards to dangerous zones (circles around each hazard)
    final dangerousZones = _createDangerousZones(hazards);

    // A* algorithm
    final openSet = <AStarNode>{};
    final closedSet = <AStarNode>{};
    final cameFrom = <AStarNode, AStarNode>{};
    final gScore = <AStarNode, double>{};
    final fScore = <AStarNode, double>{};

    final startNode = AStarNode(start);
    final endNode = AStarNode(end);

    openSet.add(startNode);
    gScore[startNode] = 0;
    fScore[startNode] = _heuristic(startNode, endNode);

    int iterations = 0;
    while (openSet.isNotEmpty && iterations < maxIterations) {
      iterations++;

      // Find node in openSet with lowest fScore
      AStarNode? current;
      double lowestFScore = double.infinity;
      for (final node in openSet) {
        if (fScore[node]! < lowestFScore) {
          lowestFScore = fScore[node]!;
          current = node;
        }
      }

      if (current == null) break;

      if (_nodesEqual(current, endNode)) {
        // Found path, reconstruct and return
        return _reconstructPath(cameFrom, current);
      }

      openSet.remove(current);
      closedSet.add(current);

      // Check neighbors
      final neighbors = _getNeighbors(current, start, end, dangerousZones);
      for (final neighbor in neighbors) {
        if (closedSet.contains(neighbor)) continue;

        final tentativeGScore = gScore[current]! + _distanceBetween(current, neighbor);

        if (!openSet.contains(neighbor)) {
          openSet.add(neighbor);
        } else if (tentativeGScore >= gScore[neighbor]!) {
          continue; // This is not a better path
        }

        // This path is the best until now
        cameFrom[neighbor] = current;
        gScore[neighbor] = tentativeGScore;
        fScore[neighbor] = tentativeGScore + _heuristic(neighbor, endNode);
      }
    }

    // No path found or max iterations reached, return direct path with warning
    return [start, end];
  }

  /// Create dangerous zones around hazards (buffer zones)
  List<_DangerousZone> _createDangerousZones(List<Hazard> hazards) {
    return hazards.map((hazard) {
      // Convert confidence to radius (more confidence = larger danger zone)
      // Base radius of 50m, scaled by confidence (0-100)
      final double baseRadius = 50.0;
      final double confidenceFactor = hazard.confidence / 100.0;
      final double radius = baseRadius * (1 + confidenceFactor);

      return _DangerousZone(
        center: hazard.location,
        radius: radius,
        weight: hazardAvoidanceWeight,
      );
    }).toList();
  }

  /// Get neighboring points for A* search
  List<AStarNode> _getNeighbors(
    AStarNode node,
    LatLng start,
    LatLng end,
    List<_DangerousZone> dangerousZones,
  ) {
    final List<AStarNode> neighbors = [];

    // Generate points in a circle around the current node
    const int numPoints = 8; // 8 directions
    final double angleStep = 2 * pi / numPoints;
    final double baseDistance = _distanceBetween(
      AStarNode(start),
      AStarNode(end),
    ) / 10; // Step size is 1/10th of total distance

    for (int i = 0; i < numPoints; i++) {
      final double angle = i * angleStep;
      final double dx = baseDistance * cos(angle);
      final double dy = baseDistance * sin(angle);

      final double newLat = node.position.latitude + (dy / 111000); // Approximate meters to degrees
      final double newLng = node.position.longitude + (dx / (111000 * cos(node.position.latitude * pi / 180)));

      final LatLng newPosition = LatLng(newLat, newLng);

      // Check if the new position is valid (not in dangerous zone)
      if (!_isInDangerousZone(newPosition, dangerousZones)) {
        neighbors.add(AStarNode(newPosition));
      }
    }

    // Also add a point directly toward the goal (helps with direct paths)
    final directPoint = _interpolatePoint(node.position, end, 0.1); // 10% toward goal
    if (!_isInDangerousZone(directPoint, dangerousZones)) {
      neighbors.add(AStarNode(directPoint));
    }

    return neighbors;
  }

  /// Check if a point is in any dangerous zone
  bool _isInDangerousZone(LatLng point, List<_DangerousZone> dangerousZones) {
    for (final zone in dangerousZones) {
      final distance = _distanceBetweenPoints(point, zone.center);
      if (distance <= zone.radius) {
        return true;
      }
    }
    return false;
  }

  /// Calculate distance between two points in meters
  double _distanceBetween(AStarNode a, AStarNode b) {
    return _distanceBetweenPoints(a.position, b.position);
  }

  double _distanceBetweenPoints(LatLng a, LatLng b) {
    // Haversine formula for distance between two lat/lng points
    const double earthRadius = 6371000; // meters
    final double lat1Rad = a.latitude * pi / 180;
    final double lat2Rad = b.latitude * pi / 180;
    final double deltaLat = (b.latitude - a.latitude) * pi / 180;
    final double deltaLng = (b.longitude - a.longitude) * pi / 180;

    final double aVal = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLng / 2) * sin(deltaLng / 2);
    final double c = 2 * atan2(sqrt(aVal), sqrt(1 - aVal));

    return earthRadius * c;
  }

  /// Heuristic function for A* (straight-line distance)
  double _heuristic(AStarNode a, AStarNode b) {
    return _distanceBetween(a, b);
  }

  /// Check if two nodes represent the same position
  bool _nodesEqual(AStarNode a, AStarNode b) {
    return (a.position.latitude - b.position.latitude).abs() < 0.000001 &&
           (a.position.longitude - b.position.longitude).abs() < 0.000001;
  }

  /// Reconstruct path from cameFrom map
  List<LatLng> _reconstructPath(
    Map<AStarNode, AStarNode> cameFrom,
    AStarNode current,
  ) {
    final List<LatLng> path = [current.position];
    while (cameFrom.containsKey(current)) {
      current = cameFrom[current]!;
      path.add(current.position);
    }
    return path.reversed.toList();
  }

  /// Interpolate between two points by a fraction
  LatLng _interpolatePoint(LatLng start, LatLng end, double fraction) {
    final double lat = start.latitude + (end.latitude - start.latitude) * fraction;
    final double lng = start.longitude + (end.longitude - start.longitude) * fraction;
    return LatLng(lat, lng);
  }
}

/// Internal node representation for A* algorithm
class AStarNode {
  final LatLng position;

  AStarNode(this.position);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AStarNode &&
          runtimeType == other.runtimeType &&
          position.latitude == other.position.latitude &&
          position.longitude == other.position.longitude;

  @override
  int get hashCode =>
      position.latitude.hashCode ^ position.longitude.hashCode;
}

/// Represents a dangerous zone around a hazard
class _DangerousZone {
  final LatLng center;
  final double radius; // in meters
  final double weight; // hazard avoidance weight

  _DangerousZone({
    required this.center,
    required this.radius,
    required this.weight,
  });
}