import 'dart:async';

import 'package:flutter/material.dart';
import 'package:route_guard/services/database_service.dart';
import 'package:route_guard/models/hazard.dart';
import 'package:route_guard/models/user.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final MapController _mapController = MapController();

  // Tab management
  int _selectedIndex = 0;

  // Data for different tabs
  List<UserProfile> _pendingRequests = [];
  List<Hazard> _hazardsForModeration = [];
  List<Map<String, dynamic>> _officialAdvisories = [];
  List<Hazard> _allHazards = [];

  bool _isLoading = true;
  String? _error;

  // Statistics
  int _totalHazards = 0;
  int _pendingHazards = 0;
  int _confirmedHazards = 0;
  int _rejectedHazards = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load data for all tabs in parallel
      await Future.wait([
        _getPendingAgencyRequests(),
        _getHazardsForModeration(),
        _getOfficialAdvisories(),
        _getAllHazards(),
        _getHazardStatistics(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getPendingAgencyRequests() async {
    final requests = await _databaseService.getPendingAgencyRequests();
    if (mounted) {
      setState(() {
        _pendingRequests = requests;
      });
    }
  }

  Future<void> _getHazardsForModeration() async {
    final hazards = await _databaseService.getHazardsForModeration();
    if (mounted) {
      setState(() {
        _hazardsForModeration = hazards;
      });
    }
  }

  Future<void> _getOfficialAdvisories() async {
    final advisories = await _databaseService.getOfficialAdvisories();
    if (mounted) {
      setState(() {
        _officialAdvisories = advisories;
      });
    }
  }

  Future<void> _getAllHazards() async {
    final hazards = await _databaseService.getHazards();
    if (mounted) {
      setState(() {
        _allHazards = hazards;
      });
    }
  }

  Future<void> _getHazardStatistics() async {
    final hazards = await _databaseService.getHazards();
    if (mounted) {
      setState(() {
        _totalHazards = hazards.length;
        _pendingHazards = hazards.where((h) => h.status == HazardStatus.uncertain).length;
        _confirmedHazards = hazards.where((h) => h.status == HazardStatus.clear).length;
        _rejectedHazards = hazards.where((h) => h.status == HazardStatus.impassable).length;
      });
    }
  }

  Future<void> _approveAgencyRequest(String userId) async {
    await _databaseService.approveAgencyRequest(userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agency request approved!')),
      );
      await _loadDashboardData();
    }
  }

  Future<void> _rejectAgencyRequest(String userId) async {
    await _databaseService.rejectAgencyRequest(userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agency request rejected.')),
      );
      await _loadDashboardData();
    }
  }

  Future<void> _createOfficialAdvisory() async {
    // TODO: Implement advisory creation dialog
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Advisory creation feature coming soon!')),
    );
  }

  Future<void> _moderateHazard(String hazardId, String outcome) async {
    await _databaseService.reviewModerationQueue(
      hazardId,
      'agency_official', // TODO: Get actual agency official ID from auth
      outcome
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hazard marked as $outcome')),
      );
      await _loadDashboardData();
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
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Account',
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('My Profile'),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
            onSelected: (value) async {
              if (value == 'logout') {
                // TODO: Implement logout
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logout feature coming soon!')),
                );
              }
            },
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Requests'),
            Tab(text: 'Advisories'),
            Tab(text: 'Moderation'),
            Tab(text: 'Analytics'),
          ],
        ),
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
              : const TabBarView(
                  children: [
                    _PendingRequestsTab(),
                    _AdvisoriesTab(),
                    _ModerationTab(),
                    _AnalyticsTab(),
                  ],
                ),
    );
  }
}

class _PendingRequestsTab extends StatefulWidget {
  const _PendingRequestsTab();

  @override
  State<_PendingRequestsTab> createState() => _PendingRequestsTabState();
}

class _PendingRequestsTabState extends State<_PendingRequestsTab> {
  final DatabaseService _databaseService = DatabaseService();
  List<UserProfile> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _databaseService.getPendingAgencyRequests();
      if (mounted) {
        setState(() {
          _pendingRequests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveRequest(String userId) async {
    await _databaseService.approveAgencyRequest(userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agency request approved!')),
      );
      await _loadRequests();
    }
  }

  Future<void> _rejectRequest(String userId) async {
    await _databaseService.rejectAgencyRequest(userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agency request rejected.')),
      );
      await _loadRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingRequests.isEmpty) {
      return const Center(
        child: Text('No pending agency requests'),
      );
    }

    return ListView.builder(
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _pendingRequests[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            leading: const Icon(Icons.person_add, color: Colors.blue),
            title: Text(request.email ?? 'No email'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (request.agency != null && request.agency!.isNotEmpty)
                  Text('Agency: ${request.agency}', style: const TextStyle(fontSize: 12)),
                if (request.role != null && request.role!.isNotEmpty)
                  Text('Role: ${request.role}', style: const TextStyle(fontSize: 12)),
                Text('Requested: ${request.createdAt?.toLocal().toString().split('.')[0] ?? 'Unknown'}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _approveRequest(request.id!),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: () => _rejectRequest(request.id!),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdvisoriesTab extends StatefulWidget {
  const _AdvisoriesTab();

  @override
  State<_AdvisoriesTab> createState() => _AdvisoriesTabState();
}

class _AdvisoriesTabState extends State<_AdvisoriesTab> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _officialAdvisories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdvisories();
  }

  Future<void> _loadAdvisories() async {
    setState(() => _isLoading = true);
    try {
      final advisories = await _databaseService.getOfficialAdvisories();
      if (mounted) {
        setState(() {
          _officialAdvisories = advisories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createAdvisory() async {
    // TODO: Implement advisory creation dialog
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Advisory creation feature coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_officialAdvisories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No official advisories yet'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _createAdvisory,
              child: const Text('Create First Advisory'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _officialAdvisories.length,
      itemBuilder: (context, index) {
        final advisory = _officialAdvisories[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            leading: const Icon(Icons.announcement, color: Colors.orange),
            title: Text(
              advisory['hazard_type'] ?? 'Unknown Hazard',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(advisory['description'] ?? 'No description'),
                const SizedBox(height: 4),
                Text(
                  'Valid: ${advisory['valid_from']?.toString().split('T')[0] ?? 'N/A'} to ${advisory['valid_until']?.toString().split('T')[0] ?? 'N/A'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  'By: ${advisory['created_by'] ?? 'Unknown'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit Advisory'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Advisory'),
                ),
              ],
              onSelected: (value) async {
                if (value == 'edit') {
                  // TODO: Implement edit advisory
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit advisory coming soon!')),
                  );
                } else if (value == 'delete') {
                  // TODO: Implement delete advisory
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delete advisory coming soon!')),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class _ModerationTab extends StatefulWidget {
  const _ModerationTab();

  @override
  State<_ModerationTab> createState() => _ModerationTabState();
}

class _ModerationTabState extends State<_ModerationTab> {
  final DatabaseService _databaseService = DatabaseService();
  List<Hazard> _hazardsForModeration = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHazards();
  }

  Future<void> _loadHazards() async {
    setState(() => _isLoading = true);
    try {
      final hazards = await _databaseService.getHazardsForModeration();
      if (mounted) {
        setState(() {
          _hazardsForModeration = hazards;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _moderateHazard(String hazardId, String outcome) async {
    await _databaseService.reviewModerationQueue(
      hazardId,
      'agency_official', // TODO: Get actual agency official ID from auth
      outcome
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hazard marked as $outcome')),
      );
      await _loadHazards();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hazardsForModeration.isEmpty) {
      return const Center(
        child: Text('No hazards pending moderation'),
      );
    }

    return ListView.builder(
      itemCount: _hazardsForModeration.length,
      itemBuilder: (context, index) {
        final hazard = _hazardsForModeration[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ExpansionTile(
            leading: Icon(
              _getHazardIcon(hazard.hazardType),
              color: _getHazardColor(hazard.status),
              size: 32,
            ),
            title: Text(hazard.hazardType),
            subtitle: Text(
              'Status: ${hazard.status.toString().split('.').last} | Confidence: ${hazard.confidence}%',
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hazard.description != null && hazard.description!.isNotEmpty)
                      Text(
                        'Description:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    if (hazard.description != null && hazard.description!.isNotEmpty)
                      Text(hazard.description!),
                    const SizedBox(height: 12),
                    Text(
                      'Location: ${hazard.location.latitude.toStringAsFixed(6)}, ${hazard.location.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (hazard.photo_url != null && hazard.photo_url!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            'Photo:',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Image.network(
                            hazard.photo_url!,
                            width: 200,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 100),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _moderateHazard(hazard.id!, 'confirmed'),
                          icon: const Icon(Icons.check_circle, size: 20),
                          label: const Text('Confirm'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _moderateHazard(hazard.id!, 'false'),
                          icon: const Icon(Icons.cancel, size: 20),
                          label: const Text('Mark as False'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _moderateHazard(hazard.id!, 'inconclusive'),
                          icon: const Icon(Icons.help_outline, size: 20),
                          label: const Text('Inconclusive'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  final DatabaseService _databaseService = DatabaseService();
  int _totalHazards = 0;
  int _pendingHazards = 0;
  int _confirmedHazards = 0;
  int _rejectedHazards = 0;
  List<Hazard> _allHazards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    try {
      final hazards = await _databaseService.getHazards();
      if (mounted) {
        setState(() {
          _totalHazards = hazards.length;
          _pendingHazards = hazards.where((h) => h.status == HazardStatus.uncertain).length;
          _confirmedHazards = hazards.where((h) => h.status == HazardStatus.clear).length;
          _rejectedHazards = hazards.where((h) => h.status == HazardStatus.impassable).length;
          _allHazards = hazards;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: Colors.blue),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Cards
          Row(
            children: [
              _buildStatCard('Total Hazards', _totalHazards.toString(), Icons.warning),
              const SizedBox(width: 16),
              _buildStatCard('Pending Review', _pendingHazards.toString(), Icons.pending_actions),
              const SizedBox(width: 16),
              _buildStatCard('Confirmed', _confirmedHazards.toString(), Icons.check_circle),
            ],
          ),
          const SizedBox(height: 24),
          _buildStatCard('Marked as False/Impassable', _rejectedHazards.toString(), Icons.error),

          const SizedBox(height: 32),

          // Charts would go here in a real implementation
          const Text(
            'Hazard Trends',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'Charts and visualizations coming soon\n(Hazard trends over time, type distribution, etc.)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Recent Activity
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _allHazards.isEmpty
              ? const Text('No hazard activity yet')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _allHazards.length > 5 ? 5 : _allHazards.length,
                  itemBuilder: (context, index) {
                    final hazard = _allHazards[_allHazards.length - 1 - index]; // Reverse order for newest first
                    return ListTile(
                      leading: Icon(
                        _getHazardIcon(hazard.hazardType),
                        color: _getHazardColor(hazard.status),
                      ),
                      title: Text(hazard.hazardType),
                      subtitle: Text(
                        '${hazard.status.toString().split('.').last} | ${hazard.confidence}% confidence',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        hazard.timestamp?.toLocal().toString().split('.')[0] ?? 'Unknown',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

