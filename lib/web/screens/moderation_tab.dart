import 'dart:async';
import 'package:flutter/material.dart';
import 'package:route_guard/services/database_service.dart';
import 'package:route_guard/models/hazard.dart';
import 'package:route_guard/web/theme.dart';

class ModerationTab extends StatefulWidget {
  const ModerationTab({super.key});

  @override
  State<ModerationTab> createState() => _ModerationTabState();
}

class _ModerationTabState extends State<ModerationTab> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _hazardsForModeration = []; // Contains hazard + moderation_queue data
  List<Map<String, dynamic>> _filteredHazardsForModeration = []; // Contains hazard + moderation_queue data
  bool _isLoading = true;
  String? _agencyOfficialId; // To store the agency official's user ID
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Filter variables
  String _selectedHazardTypeFilter = 'All';
  String _selectedStatusFilter = 'All';
  int _minConfidenceFilter = 0;
  int _maxConfidenceFilter = 100;
  String _selectedSortOption = 'Newest First';

  // Lists for filter dropdowns
  final List<String> _hazardTypes = [];
  final List<String> _statusOptions = ['All', 'impassable', 'partial', 'clear', 'uncertain'];
  final List<String> _sortOptions = [
    'Newest First',
    'Oldest First',
    'Hazard Type (A-Z)',
    'Hazard Type (Z-A)',
    'Status (A-Z)',
    'Status (Z-A)',
    'Confidence (Low-High)',
    'Confidence (High-Low)'
  ];

  @override
  void initState() {
    super.initState();
    _fetchAgencyOfficialId();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _applyFiltersAndSort();
        });
      }
    });
  }

  Future<void> _fetchAgencyOfficialId() async {
    try {
      final user = _databaseService.supabase.auth.currentUser;
      if (user != null && mounted) {
        setState(() {
          _agencyOfficialId = user.id;
        });
        await _loadHazards();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadHazards() async {
    setState(() => _isLoading = true);
    try {
      final hazards = await _databaseService.getHazardsForModeration();
      if (mounted) {
        setState(() {
          _hazardsForModeration = hazards;

          // Extract unique hazard types for filter dropdown
          _hazardTypes.clear();
          _hazardTypes.add('All');
          for (final hazardData in hazards) {
            // Extract hazard data (excluding the moderation_queue field)
            final hazardJson = Map<String, dynamic>.from(hazardData);
            hazardJson.remove('moderation_queue');
            final hazard = Hazard.fromJson(hazardJson);
            final hazardType = hazard.hazardType;
            if (hazardType.isNotEmpty && !_hazardTypes.contains(hazardType)) {
              _hazardTypes.add(hazardType);
            }
          }

          _filteredHazardsForModeration = List.from(_hazardsForModeration); // Initially show all
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

  void _applyFiltersAndSort() {
    var filtered = _hazardsForModeration;

    // Text search
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((hazardData) {
        // Extract hazard data for searching (excluding the moderation_queue field)
        final hazardJson = Map<String, dynamic>.from(hazardData);
        hazardJson.remove('moderation_queue');
        final hazard = Hazard.fromJson(hazardJson);
        return hazard.hazardType.toLowerCase().contains(query) ||
            (hazard.description != null && hazard.description!.toLowerCase().contains(query)) ||
            hazard.status.toString().split('.').last.toLowerCase().contains(query) ||
            hazard.confidence.toString().contains(query) ||
            '${hazard.location.latitude.toStringAsFixed(6)}, ${hazard.location.longitude.toStringAsFixed(6)}'.toLowerCase().contains(query) ||
            (hazard.photoUrl != null && hazard.photoUrl!.toLowerCase().contains(query));
      }).toList();
    }

    // Hazard type filter
    if (_selectedHazardTypeFilter != 'All') {
      filtered = filtered.where((hazardData) {
        final hazardJson = Map<String, dynamic>.from(hazardData);
        hazardJson.remove('moderation_queue');
        final hazard = Hazard.fromJson(hazardJson);
        return hazard.hazardType == _selectedHazardTypeFilter;
      }).toList();
    }

    // Status filter
    if (_selectedStatusFilter != 'All') {
      filtered = filtered.where((hazardData) {
        final hazardJson = Map<String, dynamic>.from(hazardData);
        hazardJson.remove('moderation_queue');
        final hazard = Hazard.fromJson(hazardJson);
        return hazard.status.toString().split('.').last == _selectedStatusFilter;
      }).toList();
    }

    // Confidence range filter
    filtered = filtered.where((hazardData) {
      final hazardJson = Map<String, dynamic>.from(hazardData);
      hazardJson.remove('moderation_queue');
      final hazard = Hazard.fromJson(hazardJson);
      return hazard.confidence >= _minConfidenceFilter && hazard.confidence <= _maxConfidenceFilter;
    }).toList();

    // Apply sorting
    filtered = _applySort(filtered);

    setState(() {
      _filteredHazardsForModeration = filtered;
    });
  }

  List<Map<String, dynamic>> _applySort(List<Map<String, dynamic>> hazardsData) {
    final sorted = hazardsData.toList();
    switch (_selectedSortOption) {
      case 'Newest First':
        sorted.sort((a, b) {
          final hazardA = Hazard.fromJson(Map<String, dynamic>.from(a)..remove('moderation_queue'));
          final hazardB = Hazard.fromJson(Map<String, dynamic>.from(b)..remove('moderation_queue'));
          return hazardB.timestamp.compareTo(hazardA.timestamp);
        });
        return sorted;
      case 'Oldest First':
        sorted.sort((a, b) {
          final hazardA = Hazard.fromJson(Map<String, dynamic>.from(a)..remove('moderation_queue'));
          final hazardB = Hazard.fromJson(Map<String, dynamic>.from(b)..remove('moderation_queue'));
          return hazardA.timestamp.compareTo(hazardB.timestamp);
        });
        return sorted;
      case 'Hazard Type (A-Z)':
        sorted.sort((a, b) {
          final hazardA = Hazard.fromJson(Map<String, dynamic>.from(a)..remove('moderation_queue'));
          final hazardB = Hazard.fromJson(Map<String, dynamic>.from(b)..remove('moderation_queue'));
          return hazardA.hazardType.compareTo(hazardB.hazardType);
        });
        return sorted;
      case 'Hazard Type (Z-A)':
        sorted.sort((a, b) {
          final hazardA = Hazard.fromJson(Map<String, dynamic>.from(a)..remove('moderation_queue'));
          final hazardB = Hazard.fromJson(Map<String, dynamic>.from(b)..remove('moderation_queue'));
          return hazardB.hazardType.compareTo(hazardA.hazardType);
        });
        return sorted;
      case 'Status (A-Z)':
        sorted.sort((a, b) {
          final hazardA = Hazard.fromJson(Map<String, dynamic>.from(a)..remove('moderation_queue'));
          final hazardB = Hazard.fromJson(Map<String, dynamic>.from(b)..remove('moderation_queue'));
          return hazardA.status.toString().split('.').last.compareTo(hazardB.status.toString().split('.').last);
        });
        return sorted;
      case 'Status (Z-A)':
        sorted.sort((a, b) {
          final hazardA = Hazard.fromJson(Map<String, dynamic>.from(a)..remove('moderation_queue'));
          final hazardB = Hazard.fromJson(Map<String, dynamic>.from(b)..remove('moderation_queue'));
          return hazardB.status.toString().split('.').last.compareTo(hazardA.status.toString().split('.').last);
        });
        return sorted;
      case 'Confidence (Low-High)':
        sorted.sort((a, b) {
          final hazardA = Hazard.fromJson(Map<String, dynamic>.from(a)..remove('moderation_queue'));
          final hazardB = Hazard.fromJson(Map<String, dynamic>.from(b)..remove('moderation_queue'));
          return hazardA.confidence.compareTo(hazardB.confidence);
        });
        return sorted;
      case 'Confidence (High-Low)':
        sorted.sort((a, b) {
          final hazardA = Hazard.fromJson(Map<String, dynamic>.from(a)..remove('moderation_queue'));
          final hazardB = Hazard.fromJson(Map<String, dynamic>.from(b)..remove('moderation_queue'));
          return hazardB.confidence.compareTo(hazardA.confidence);
        });
        return sorted;
      default:
        return sorted;
    }
  }

  Future<void> _moderateHazard(String moderationQueueId, String outcome) async {
    if (_agencyOfficialId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Agency official ID not available')),
        );
      }
      return;
    }
    try {
      await _databaseService.reviewModerationQueue(
        moderationQueueId,
        _agencyOfficialId!,
        outcome
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hazard marked as $outcome')),
        );
        await _loadHazards();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to moderate hazard: $e')),
        );
      }
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
        return AppTheme.impassableColor;
      case HazardStatus.partial:
        return AppTheme.partialColor;
      case HazardStatus.clear:
        return AppTheme.clearColor;
      case HazardStatus.uncertain:
        return AppTheme.uncertainColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    // Use filtered hazards for display
    final displayHazards = _filteredHazardsForModeration.isNotEmpty ? _filteredHazardsForModeration : _hazardsForModeration;

    if (displayHazards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 64,
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                _searchController.text.isNotEmpty
                    ? 'No hazards match your search'
                    : 'No hazards pending moderation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _searchController.text.isNotEmpty
                    ? 'Try adjusting your search terms'
                    : 'All hazard reports have been reviewed',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_searchController.text.isNotEmpty)
                ElevatedButton(
                  onPressed: () {
                    _searchController.clear();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Clear Search'),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search hazards by type, description, status, confidence, or location...',
              prefixIcon: Icon(Icons.search, color: AppTheme.textSecondaryColor),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF1E3A8A), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
            ),
          ),
        ),
        // Filter Controls
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Wrap(
            spacing: 16.0,
            runSpacing: 12.0,
            children: [
              // Hazard Type Filter Dropdown
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedHazardTypeFilter,
                  decoration: InputDecoration(
                    labelText: 'Hazard Type',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF1E3A8A), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  items: _hazardTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedHazardTypeFilter = value;
                        _applyFiltersAndSort();
                      });
                    }
                  },
                ),
              ),

              // Status Filter Dropdown
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStatusFilter,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF1E3A8A), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedStatusFilter = value;
                        _applyFiltersAndSort();
                      });
                    }
                  },
                ),
              ),

              // Confidence Range Filters
              SizedBox(
                width: 120,
                child: TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Min Confidence',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF1E3A8A), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    suffixIcon: _minConfidenceFilter != 0
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _minConfidenceFilter = 0;
                                _applyFiltersAndSort();
                              });
                            },
                          )
                        : const Icon(Icons.filter_list),
                  ),
                  onTap: () async {
                    await showDialog<String>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Select Minimum Confidence'),
                          content: StatefulBuilder(
                            builder: (BuildContext context, StateSetter setState) {
                              return SizedBox(
                                width: double.maxFinite,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: 11, // 0, 10, 20, ..., 100
                                  itemBuilder: (BuildContext context, int index) {
                                    final confidence = index * 10;
                                    return ListTile(
                                      title: Text('$confidence%'),
                                      onTap: () {
                                        setState(() {
                                          _minConfidenceFilter = confidence;
                                        });
                                        Navigator.of(context).pop();
                                      },
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                    if (mounted) {
                      setState(() {
                        _applyFiltersAndSort();
                      });
                    }
                  },
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Max Confidence',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF1E3A8A), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    suffixIcon: _maxConfidenceFilter != 100
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _maxConfidenceFilter = 100;
                                _applyFiltersAndSort();
                              });
                            },
                          )
                        : const Icon(Icons.filter_list),
                  ),
                  onTap: () async {
                    await showDialog<String>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Select Maximum Confidence'),
                          content: StatefulBuilder(
                            builder: (BuildContext context, StateSetter setState) {
                              return SizedBox(
                                width: double.maxFinite,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: 11, // 0, 10, 20, ..., 100
                                  itemBuilder: (BuildContext context, int index) {
                                    final confidence = index * 10;
                                    return ListTile(
                                      title: Text('$confidence%'),
                                      onTap: () {
                                        setState(() {
                                          _maxConfidenceFilter = confidence;
                                        });
                                        Navigator.of(context).pop();
                                      },
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                    if (mounted) {
                      setState(() {
                        _applyFiltersAndSort();
                      });
                    }
                  },
                ),
              ),

              // Sort Dropdown
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedSortOption,
                  decoration: InputDecoration(
                    labelText: 'Sort By',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF1E3A8A), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  items: _sortOptions.map((option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedSortOption = value;
                        _applyFiltersAndSort();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(24.0),
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemCount: displayHazards.length,
            itemBuilder: (context, index) {
              final hazardData = displayHazards[index];
              // Extract hazard data (excluding the moderation_queue field)
              final hazardJson = Map<String, dynamic>.from(hazardData);
              hazardJson.remove('moderation_queue');
              final hazard = Hazard.fromJson(hazardJson);
              final moderationQueueId = hazardData['moderation_queue']['id'] as String;

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ExpansionTile(
                    maintainState: true,
                    childrenPadding: const EdgeInsets.all(0),
                    expandedAlignment: Alignment.centerLeft,
                    leading: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _getHazardColor(hazard.status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getHazardIcon(hazard.hazardType),
                        color: _getHazardColor(hazard.status),
                        size: 28,
                      ),
                    ),
                    title: Text(
                      hazard.hazardType,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          '${hazard.status.toString().split('.').last} | ${hazard.confidence}% confidence',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (hazard.description != null && hazard.description!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            hazard.description!,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.textPrimaryColor,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hazard.description != null && hazard.description!.isNotEmpty) ...[
                              const Text(
                                'Description:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                hazard.description!,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppTheme.textPrimaryColor,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Text(
                                  'Location:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${hazard.location.latitude.toStringAsFixed(6)}, ${hazard.location.longitude.toStringAsFixed(6)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (hazard.photoUrl != null && hazard.photoUrl!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Photo:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  hazard.photoUrl!,
                                  width: double.infinity,
                                  height: 180,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: double.infinity,
                                        height: 180,
                                        color: AppTheme.textSecondaryColor.withValues(alpha: 0.1),
                                        child: const Icon(Icons.broken_image, size: 48),
                                      ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _moderateHazard(moderationQueueId, 'confirmed'),
                                  icon: const Icon(Icons.check_circle, size: 20),
                                  label: const Text('Confirm'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.successColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: () => _moderateHazard(moderationQueueId, 'false'),
                                  icon: const Icon(Icons.cancel, size: 20),
                                  label: const Text('Mark as False'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.errorColor,
                                    side: BorderSide(
                                        color: AppTheme.errorColor, width: 2),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: () => _moderateHazard(moderationQueueId, 'inconclusive'),
                                  icon: const Icon(Icons.help_outline, size: 20),
                                  label: const Text('Inconclusive'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.warningColor,
                                    side: BorderSide(
                                        color: AppTheme.warningColor, width: 2),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}