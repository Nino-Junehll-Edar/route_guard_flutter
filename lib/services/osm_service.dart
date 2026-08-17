import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:route_guard/services/local_cache_service.dart';
import 'package:xml/xml.dart';

/// Service for fetching and caching OpenStreetMap data
class OsmService {
  final LocalCacheService _localCacheService;
  static const _overpassApiUrl = 'https://overpass-api.de/api/interpreter';
  static const _cacheKeyPrefix = 'osm_data_';
  static const _cacheDurationHours = 6; // Cache OSM data for 6 hours

  OsmService(this._localCacheService);

  /// Fetches OSM data for the bounding box that contains start and end points
  /// with some buffer around them
  Future<OsmData> fetchOsmDataForBounds({
    required LatLng start,
    required LatLng end,
    double bufferDegrees = 0.05, // Approximately 5km buffer
  }) async {
    // Calculate bounding box with buffer
    final double minLat = min(start.latitude, end.latitude) - bufferDegrees;
    final double maxLat = max(start.latitude, end.latitude) + bufferDegrees;
    final double minLng = min(start.longitude, end.longitude) - bufferDegrees;
    final double maxLng = max(start.longitude, end.longitude) + bufferDegrees;

    final String cacheKey =
        '${_cacheKeyPrefix}${minLat.toStringAsFixed(4)}_${maxLat.toStringAsFixed(4)}_${minLng.toStringAsFixed(4)}_${maxLng.toStringAsFixed(4)}';

    // Try to get cached data first
    final cachedData = await _getCachedOsmData(cacheKey);
    if (cachedData != null) {
      return cachedData;
    }

    // Fetch fresh data from Overpass API
    final OsmData osmData = await _fetchOsmDataFromOverpass(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );

    // Cache the data
    await _cacheOsmData(cacheKey, osmData);

    return osmData;
  }

  /// Fetches OSM data from Overpass API
  Future<OsmData> _fetchOsmDataFromOverpass({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    // Overpass QL query to get highways and their nodes
    final String query = '''
[out:json][timeout:25];
(
  way["highway"~"motorway|trunk|primary|secondary|tertiary|residential|service|unclassified|road"](${minLat},${minLng},${maxLat},${maxLng});
  way["highway"~"motorway_link|trunk_link|primary_link|secondary_link|tertiary_link"](${minLat},${minLng},${maxLat},${maxLng});
);
out body;
>;
out skel qt;
''';

    try {
      final http.Response response = await http.post(
        Uri.parse(_overpassApiUrl),
        body: query,
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return _parseOsmJson(response.body);
      } else {
        throw Exception('Failed to fetch OSM data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching OSM data: $e');
    }
  }

  /// Parses OSM JSON response into OsmData structure
  OsmData _parseOsmJson(String jsonBody) {
    final Map<String, dynamic> jsonData = json.decode(jsonBody);
    final List<dynamic> elements = jsonData['elements'] ?? [];

    final Map<int, OsmNode> nodes = {};
    final List<OsmWay> ways = [];

    // First pass: collect all nodes
    for (final element in elements) {
      if (element['type'] == 'node' && element.containsKey('lat') && element.containsKey('lon')) {
        final OsmNode node = OsmNode(
          id: element['id'],
          latitude: element['lat'].toDouble(),
          longitude: element['lon'].toDouble(),
        );
        nodes[node.id] = node;
      }
    }

    // Second pass: collect ways (roads)
    for (final element in elements) {
      if (element['type'] == 'way' && element.containsKey('nodes') && element['nodes'] is List) {
        final List<dynamic> nodeIds = element['nodes'];
        final Map<String, dynamic> tags = Map<String, dynamic>.from(element['tags'] ?? {});

        final List<OsmNode> wayNodes = [];
        for (final nodeId in nodeIds) {
          final int nodeIdInt = nodeId is int ? nodeId : int.tryParse(nodeId.toString()) ?? 0;
          if (nodes.containsKey(nodeIdInt)) {
            wayNodes.add(nodes[nodeIdInt]!);
          }
        }

        if (wayNodes.isNotEmpty) {
          final OsmWay way = OsmWay(
            id: element['id'],
            nodes: wayNodes,
            tags: tags,
          );
          ways.add(way);
        }
      }
    }

    return OsmData(nodes: nodes.values.toList(), ways: ways);
  }

  /// Gets cached OSM data if it exists and is not expired
  Future<OsmData?> _getCachedOsmData(String cacheKey) async {
    try {
      final String? cachedJson = await _localCacheService.getString(cacheKey);
      if (cachedJson == null) return null;

      final Map<String, dynamic> cachedMap = json.decode(cachedJson);
      final int cachedTime = cachedMap['_cachedAt'] ?? 0;
      final int now = DateTime.now().millisecondsSinceEpoch;

      // Check if cache is expired
      if (now - cachedTime > _cacheDurationHours * 60 * 60 * 1000) {
        await _localCacheService.remove(cacheKey);
        return null;
      }

      // Remove cache metadata and parse OSM data
      cachedMap.remove('_cachedAt');
      return _parseOsmJson(json.encode(cachedMap));
    } catch (e) {
      debugPrint('Error reading cached OSM data: $e');
      return null;
    }
  }

  /// Caches OSM data with timestamp
  Future<void> _cacheOsmData(String cacheKey, OsmData data) async {
    try {
      final Map<String, dynamic> cacheMap = {
        '_cachedAt': DateTime.now().millisecondsSinceEpoch,
        ...json.decode(jsonEncode(data.toJson())),
      };
      await _localCacheService.setString(cacheKey, json.encode(cacheMap));
    } catch (e) {
      debugPrint('Error caching OSM data: $e');
    }
  }
}

/// Represents OpenStreetMap data structure
class OsmData {
  final List<OsmNode> nodes;
  final List<OsmWay> ways;

  OsmData({required this.nodes, required this.ways});

  Map<String, dynamic> toJson() => {
        'nodes': nodes.map((node) => node.toJson()).toList(),
        'ways': ways.map((way) => way.toJson()).toList(),
      };

  factory OsmData.fromJson(Map<String, dynamic> json) {
    final List<OsmNode> nodes = [];
    if (json['nodes'] != null) {
      for (final nodeJson in json['nodes'] as List) {
        nodes.add(OsmNode.fromJson(nodeJson));
      }
    }

    final List<OsmWay> ways = [];
    if (json['ways'] != null) {
      for (final wayJson in json['ways'] as List) {
        ways.add(OsmWay.fromJson(wayJson));
      }
    }

    return OsmData(nodes: nodes, ways: ways);
  }
}

/// Represents an OpenStreetMap node (point)
class OsmNode {
  final int id;
  final double latitude;
  final double longitude;

  OsmNode({
    required this.id,
    required this.latitude,
    required this.longitude,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory OsmNode.fromJson(Map<String, dynamic> json) => OsmNode(
        id: json['id'] as int,
        latitude: json['latitude'] as double,
        longitude: json['longitude'] as double,
      );
}

/// Represents an OpenStreetMap way (road/path)
class OsmWay {
  final int id;
  final List<OsmNode> nodes;
  final Map<String, dynamic> tags;

  OsmWay({
    required this.id,
    required this.nodes,
    required this.tags,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nodes': nodes.map((node) => node.toJson()).toList(),
        'tags': tags,
      };

  factory OsmWay.fromJson(Map<String, dynamic> json) => OsmWay(
        id: json['id'] as int,
        nodes: (json['nodes'] as List)
            .map((nodeJson) => OsmNode.fromJson(nodeJson))
            .toList(),
        tags: Map<String, dynamic>.from(json['tags'] ?? {}),
      );

  /// Check if this way is drivable based on highway type
  bool get isDrivable {
    final String? highway = tags['highway'] as String?;
    if (highway == null) return false;

    // List of highway types that are generally drivable
    final Set<String> drivableHighways = {
      'motorway',
      'trunk',
      'primary',
      'secondary',
      'tertiary',
      'residential',
      'unclassified',
      'service',
      'road',
      'motorway_link',
      'trunk_link',
      'primary_link',
      'secondary_link',
      'tertiary_link',
      'living_street',
      'pedestrian', // Some pedestrian ways might be drivable in emergencies
    };

    return drivableHighways.contains(highway);
  }

  /// Get speed limit from tags, returns null if not specified
  int? get speedLimit {
    final String? maxspeed = tags['maxspeed'] as String?;
    if (maxspeed == null) return null;

    // Try to parse as integer (assuming km/h)
    final int? speed = int.tryParse(maxspeed);
    return speed;
  }

  /// Check if it's a one-way road
  bool get isOneway {
    final String? oneway = tags['oneway'] as String?;
    return oneway == 'yes' || oneway == 'true' || oneway == '1';
  }
}