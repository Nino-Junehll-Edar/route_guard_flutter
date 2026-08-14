import 'dart:async';

import 'package:flutter/material.dart';
import 'package:route_guard/services/service_locator.dart';
import 'package:route_guard/services/synchronized_database_service.dart';
import 'package:route_guard/models/hazard.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final SynchronizedDatabaseService _databaseService;
  final MapController _mapController = MapController();
  List<Hazard> _hazards = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _databaseService = ServiceLocator().synchronizedDatabaseService;
    _loadHazards();
  }

  Future<void> _loadHazards() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final hazards = await _databaseService.getHazards();
      setState(() {
        _hazards = hazards;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agency Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHazards,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    'Error: $_error',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : _hazards.isEmpty
                  ? const Center(child: Text('No hazards reported yet.'))
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: _hazards.length,
                            itemBuilder: (context, index) {
                              final hazard = _hazards[index];
                              return ListTile(
                                leading: Icon(
                                  _getHazardIcon(hazard.hazardType),
                                  color: _getHazardColor(hazard.status),
                                ),
                                title: Text(hazard.hazardType),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Reporter: ${hazard.reporterUid}'),
                                    Text(
                                        'Status: ${hazard.status.toString().split('.').last}'),
                                    Text(
                                        'Confidence: ${hazard.confidence}%'),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    // TODO: Implement hazard verification actions
                                    // For now, just refresh
                                    await _loadHazards();
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'confirm',
                                      child: Text('Mark as Confirmed'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'false',
                                      child: Text('Mark as False'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'inconclusive',
                                      child: Text('Mark as Inconclusive'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        // Map view of hazards
                        Expanded(
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _hazards.isEmpty
                                  ? LatLng(11.2448, 125.0047) // Tacloban City coordinates
                                  : LatLng(
                                      _hazards.first.location.latitude,
                                      _hazards.first.location.longitude,
                                    ),
                              initialZoom: 13.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                subdomains: const ['a', 'b', 'c'],
                              ),
                              MarkerLayer(
                                markers: _hazards.map((hazard) {
                                  return Marker(
                                    point: hazard.location,
                                    child: Icon(
                                      _getHazardIcon(hazard.hazardType),
                                      color: _getHazardColor(hazard.status),
                                      size: 30.0,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
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
}