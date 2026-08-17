import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:route_guard/services/osm_service.dart';

/// Represents a node in the road graph
class GraphNode {
  final String id;
  final LatLng position;
  final Map<String, GraphEdge> edges = {}; // edges connected to this node

  GraphNode({
    required this.id,
    required this.position,
  });

  void addEdge(String edgeId, GraphEdge edge) {
    edges[edgeId] = edge;
  }

  GraphEdge? getEdge(String edgeId) {
    return edges[edgeId];
  }

  List<GraphEdge> getAllEdges() {
    return edges.values.toList();
  }
}

/// Represents an edge in the road graph (a road segment between two nodes)
class GraphEdge {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final double distance; // in meters
  final bool isOneway;
  final int? speedLimit; // in km/h, null if not specified
  final String highwayType;
  double baseWeight; // base weight for routing calculation (lower = preferred)

  GraphEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.distance,
    required this.isOneway,
    this.speedLimit,
    required this.highwayType,
    double baseWeight = 1.0,
  }) : baseWeight = baseWeight;

  /// Get the weight/cost of traversing this edge
  /// Lower values are preferred by the routing algorithm
  double getWeight() {
    // Base weight modified by speed limit (higher speed = lower weight)
    double speedFactor = 1.0;
    if (speedLimit != null && speedLimit! > 0) {
      // Normalize speed factor: higher speed = lower weight
      speedFactor = 50.0 / (speedLimit! + 10.0); // 50 km/h as reference
      speedFactor = speedFactor.clamp(0.1, 2.0); // Prevent extreme values
    }

    return baseWeight * speedFactor * distance;
  }

  /// Reverse edge (for two-way roads)
  GraphEdge reverse() {
    return GraphEdge(
      id: '${id}_reverse',
      fromNodeId: toNodeId,
      toNodeId: fromNodeId,
      distance: distance,
      isOneway: false, // Reversing a one-way makes it two-way for the reverse direction
      speedLimit: speedLimit,
      highwayType: highwayType,
      baseWeight: baseWeight,
    );
  }
}

/// Service for constructing and managing a road graph from OSM data
class RoadGraph {
  final Map<String, GraphNode> _nodes = {};
  final Map<String, GraphEdge> _edges = {};

  Map<String, GraphNode> get nodes => Map.unmodifiable(_nodes);
  Map<String, GraphEdge> get edges => Map.unmodifiable(_edges);

  /// Build the road graph from OSM data
  void buildFromOsmData(OsmData osmData) {
    _nodes.clear();
    _edges.clear();

    // Create nodes from OSM nodes
    for (final osmNode in osmData.nodes) {
      final String nodeId = 'node_${osmNode.id}';
      _nodes[nodeId] = GraphNode(
        id: nodeId,
        position: LatLng(osmNode.latitude, osmNode.longitude),
      );
    }

    // Create edges from OSM ways
    for (final osmWay in osmData.ways) {
      if (!osmWay.isDrivable || osmWay.nodes.length < 2) continue;

      // Create edges between consecutive nodes in the way
      for (int i = 0; i < osmWay.nodes.length - 1; i++) {
        final OsmNode fromNode = osmWay.nodes[i];
        final OsmNode toNode = osmWay.nodes[i + 1];

        final String fromNodeId = 'node_${fromNode.id}';
        final String toNodeId = 'node_${toNode.id}';

        if (!_nodes.containsKey(fromNodeId) || !_nodes.containsKey(toNodeId)) {
          continue; // Skip if nodes don't exist
        }

        // Calculate distance between nodes
        final double distance = _calculateDistance(
          fromNode.latitude,
          fromNode.longitude,
          toNode.latitude,
          toNode.longitude,
        );

        // Skip if distance is too small (avoid zero-length edges)
        if (distance < 1.0) continue;

        final String edgeId = 'way_${osmWay.id}_segment_$i';
        final GraphEdge edge = GraphEdge(
          id: edgeId,
          fromNodeId: fromNodeId,
          toNodeId: toNodeId,
          distance: distance,
          isOneway: osmWay.isOneway,
          speedLimit: osmWay.speedLimit,
          highwayType: osmWay.tags['highway'] ?? 'unknown',
          baseWeight: _calculateBaseWeight(osmWay.tags['highway']),
        );

        _edges[edgeId] = edge;
        _nodes[fromNodeId]!.addEdge(edgeId, edge);

        // Add reverse edge for two-way roads
        if (!osmWay.isOneway) {
          final String reverseEdgeId = '${edgeId}_reverse';
          final GraphEdge reverseEdge = edge.reverse();
          _edges[reverseEdgeId] = reverseEdge;
          _nodes[toNodeId]!.addEdge(reverseEdgeId, reverseEdge);
        }
      }
    }
  }

  /// Calculate base weight based on highway type (prefer major roads)
  double _calculateBaseWeight(String? highwayType) {
    switch (highwayType) {
      case 'motorway':
      case 'trunk':
        return 0.8; // Prefer highways
      case 'primary':
        return 0.9;
      case 'secondary':
        return 1.0;
      case 'tertiary':
        return 1.1;
      case 'residential':
        return 1.2;
      case 'service':
      case 'unclassified':
        return 1.3;
      case 'road':
        return 1.1;
      default:
        return 1.5; // Less preferred for unknown types
    }
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

  /// Find the nearest graph node to a given position
  GraphNode? getNearestNode(LatLng position, {double maxDistance = 50.0}) {
    GraphNode? nearest;
    double minDistance = maxDistance;

    for (final node in _nodes.values) {
      final double distance = _calculateDistance(
        position.latitude,
        position.longitude,
        node.position.latitude,
        node.position.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearest = node;
      }
    }

    return nearest;
  }

  /// Get all edges connected to a node
  List<GraphEdge> getEdgesForNode(String nodeId) {
    final GraphNode? node = _nodes[nodeId];
    return node != null ? node.getAllEdges() : [];
  }

  /// Get edge by ID
  GraphEdge? getEdge(String edgeId) {
    return _edges[edgeId];
  }

  /// Clear the graph
  void clear() {
    _nodes.clear();
    _edges.clear();
  }
}