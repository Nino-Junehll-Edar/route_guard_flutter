import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:route_guard/routing/road_graph.dart';

/// Represents a node in the A* algorithm for graph-based routing
class _GraphAStarNode {
  final String nodeId;
  final GraphNode graphNode;

  _GraphAStarNode({
    required this.nodeId,
    required this.graphNode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _GraphAStarNode &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId;

  @override
  int get hashCode => nodeId.hashCode;
}

/// Graph-based A* pathfinding algorithm for finding routes along roads
class GraphAStar {
  final double _heuristicWeight; // Weight for heuristic vs actual cost (1.0 = pure heuristic)

  GraphAStar({double heuristicWeight = 1.0}) : _heuristicWeight = heuristicWeight;

  /// Find a path from start to end using the road graph
  List<LatLng> findPath({
    required LatLng start,
    required LatLng end,
    required RoadGraph graph,
  }) {
    // Handle edge cases
    if (graph.nodes.isEmpty) return [start, end];

    // Find nearest graph nodes to start and end points
    final GraphNode? startNode = graph.getNearestNode(start, maxDistance: 100.0); // 100m max
    final GraphNode? endNode = graph.getNearestNode(end, maxDistance: 100.0);

    if (startNode == null || endNode == null) {
      // If we can't find nearby nodes, fall back to direct path
      return [start, end];
    }

    // A* algorithm
    final Set<String> openSet = {};
    final Set<String> closedSet = {};
    final Map<String, String> cameFrom = {};
    final Map<String, double> gScore = {};
    final Map<String, double> fScore = {};

    openSet.add(startNode!.id);
    gScore[startNode.id] = 0;
    fScore[startNode.id] = _heuristic(startNode, endNode, graph) * _heuristicWeight;

    while (openSet.isNotEmpty) {
      // Find node in openSet with lowest fScore
      String? currentId;
      double lowestFScore = double.infinity;

      for (final String nodeId in openSet) {
        final double score = fScore[nodeId] ?? double.infinity;
        if (score < lowestFScore) {
          lowestFScore = score;
          currentId = nodeId;
        }
      }

      if (currentId == null) break;

      final String currentNodeId = currentId;
      final GraphNode? currentNode = graph.nodes[currentNodeId];

      if (currentNode == null) {
        openSet.remove(currentNodeId);
        continue;
      }

      // Check if we reached the goal
      if (currentNodeId == endNode!.id) {
        return _reconstructPath(cameFrom, currentNodeId, graph);
      }

      openSet.remove(currentNodeId);
      closedSet.add(currentNodeId);

      // Check neighbors (edges connected to current node)
      for (final GraphEdge edge in graph.getEdgesForNode(currentNodeId)) {
        final String neighborId = edge.toNodeId;
        if (closedSet.contains(neighborId)) continue;

        // Tentative gScore is distance from start to neighbor through current
        final double tentativeGScore = (gScore[currentNodeId] ?? double.infinity) +
            edge.getWeight();

        if (!openSet.contains(neighborId)) {
          openSet.add(neighborId);
        } else if (tentativeGScore >= (gScore[neighborId] ?? double.infinity)) {
          continue; // This is not a better path
        }

        // This path is the best until now
        cameFrom[neighborId] = currentNodeId;
        gScore[neighborId] = tentativeGScore;
        fScore[neighborId] = tentativeGScore +
            _heuristic(graph.nodes[neighborId]!, endNode, graph) * _heuristicWeight;
      }
    }

    // No path found or open set empty, return direct path with warning
    return [start, end];
  }

  /// Heuristic function for A* (straight-line distance)
  double _heuristic(
    GraphNode a,
    GraphNode b,
    RoadGraph graph,
  ) {
    return _calculateDistance(
      a.position.latitude,
      a.position.longitude,
      b.position.latitude,
      b.position.longitude,
    );
  }

  /// Check if two nodes represent the same position
  bool _nodesEqual(GraphNode a, GraphNode b) {
    return (a.position.latitude - b.position.latitude).abs() < 0.000001 &&
           (a.position.longitude - b.position.longitude).abs() < 0.000001;
  }

  /// Reconstruct path from cameFrom map
  List<LatLng> _reconstructPath(
    Map<String, String> cameFrom,
    String currentNodeId,
    RoadGraph graph,
  ) {
    final List<LatLng> path = [graph.nodes[currentNodeId]!.position];
    String? current = currentNodeId;

    while (cameFrom.containsKey(current)) {
      current = cameFrom[current];
      if (current == null) break;
      path.add(graph.nodes[current]!.position);
    }

    return path.reversed.toList();
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1, double lon1, double lat2, double lon2,
  ) {
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