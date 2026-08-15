import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:route_guard/models/hazard.dart';
import 'package:route_guard/services/service_locator.dart';
import 'package:route_guard/services/location_service.dart';
import 'package:route_guard/services/notification_service.dart';
import 'package:route_guard/services/proximity_notification_service.dart';
import 'package:route_guard/services/synchronized_database_service.dart';
import 'package:route_guard/routing/route_calculator.dart';
import 'package:geolocator/geolocator.dart';
import 'package:route_guard/screens/profile_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final LocationService _locationService;
  late final SynchronizedDatabaseService _databaseService;
  late final NotificationService _notificationService;
  late final ProximityNotificationService _proximityService;
  late final RouteCalculator _routeCalculator;
  final MapController _mapController = MapController();

  LatLng? _currentLocation;
  List<Marker> _hazardMarkers = [];
  List<LatLng> _routePoints = [];
  LatLng? _destination;
  bool _isLoading = true;
  bool _isDestinationSet = false;
  StreamSubscription<Position>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      // Get services from locator
      final locator = ServiceLocator();
      _locationService = locator.locationService;
      _databaseService = locator.synchronizedDatabaseService;
      _notificationService = locator.notificationService;
      _proximityService = locator.proximityNotificationService;
      _routeCalculator = locator.routeCalculator;

      // Initialize services that need it
      await _notificationService.initialize();
      await _proximityService.initialize();

      // Get initial location
      final position = await _locationService.getCurrentPosition();
      _currentLocation = LatLng(position.latitude, position.longitude);

      // Start listening to location updates
      _locationSubscription = _locationService.positionStream().listen(
        (Position position) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
          // Check for proximity-based notifications
          _proximityService.checkCurrentPositionForHazards();
        },
        onError: (error) {
          // Location error: $error
        },
      );

      // Load hazards from database
      await _loadHazards();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // Error initializing map: $e
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHazards() async {
    try {
      final hazards = await _databaseService.getHazards();
      setState(() {
        _hazardMarkers = hazards.map((hazard) {
          return Marker(
            point: hazard.location,
            child: Icon(
              _getHazardIcon(hazard.hazardType),
              color: _getHazardColor(hazard.status),
              size: 30.0,
            ),
          );
        }).toList();
      });
    } catch (e) {
      // Error loading hazards: $e
    }
  }

  IconData _getHazardIcon(String hazardType) {
    switch (hazardType.toLowerCase()) {
      case 'flood':
        return Icons.water_drop;
      case 'landslide':
        return Icons.terrain;
      case 'earthquake':
        return Icons.landscape;
      case 'fire':
        return Icons.fire_truck;
      case 'accident':
        return Icons.car_crash;
      case 'debris':
        return Icons.construction;
      default:
        return Icons.warning;
    }
  }

  Color _getHazardColor(HazardStatus status) {
    switch (status) {
      case HazardStatus.impassable:
        return Colors.red;
      case HazardStatus.partial:
        return Colors.orange;
      case HazardStatus.clear:
        return Colors.green;
      case HazardStatus.uncertain:
        return Colors.grey;
    }
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _destination = latLng;
      _isDestinationSet = true;
      _calculateRoute();
    });
  }

  Future<void> _calculateRoute() async {
    if (_currentLocation == null || _destination == null) return;

    try {
      final route = await _routeCalculator.calculateRouteBetweenPoints(
        start: _currentLocation!,
        end: _destination!,
      );
      setState(() {
        _routePoints = route;
      });
    } catch (e) {
      // Error calculating route: $e
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentLocation == null) {
      return const Scaffold(
        body: Center(child: Text('Unable to get location')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('RouteGuard Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ProfileScreen(),
              ));
            },
          ),
          if (_isDestinationSet)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _destination = null;
                  _isDestinationSet = false;
                  _routePoints = [];
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation!,
              initialZoom: 15.0,
              onTap: (tapPosition, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              MarkerLayer(
                markers: [
                  // Current location marker
                  Marker(
                    point: _currentLocation!,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 30.0,
                    ),
                  ),
                  // Destination marker
                  if (_destination != null)
                    Marker(
                      point: _destination!,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 30.0,
                      ),
                    ),
                  // Hazard markers
                  ..._hazardMarkers,
                ],
              ),
              PolylineLayer(
                polylines: [
                  if (_routePoints.isNotEmpty)
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue.withValues(alpha: 0.7),
                      strokeWidth: 5.0,
                    ),
                ],
              ),
            ],
          ),
          // Loading indicator for route calculation
          if (_isDestinationSet && _routePoints.isEmpty)
            const Positioned(
              top: 70.0,
              left: 16.0,
              right: 16.0,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16.0),
                      Expanded(
                        child: Text(
                          'Calculating route avoiding hazards...',
                          style: TextStyle(fontSize: 16.0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Instructions
          Positioned(
            top: 16.0,
            left: 16.0,
            right: 16.0,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _isDestinationSet
                      ? 'Tap on the map to set a new destination'
                      : 'Tap on the map to set your destination',
                  style: const TextStyle(fontSize: 16.0),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}