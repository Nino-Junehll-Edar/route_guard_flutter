import 'dart:async';
import 'package:flutter/material.dart';
import 'package:route_guard/services/database_service.dart';
import 'package:route_guard/web/theme.dart';
import 'package:flutter/services.dart' show HapticFeedback;

class AdvisoriesTab extends StatefulWidget {
  const AdvisoriesTab({super.key});

  @override
  State<AdvisoriesTab> createState() => _AdvisoriesTabState();
}

class _AdvisoriesTabState extends State<AdvisoriesTab> with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _officialAdvisories = [];
  List<Map<String, dynamic>> _filteredAdvisories = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _selectedHazardTypeFilter = 'All';
  String _selectedStatusFilter = 'All';
  int _minConfidenceFilter = 0;
  int _maxConfidenceFilter = 100;
  DateTime? _validFromFilter;
  DateTime? _validUntilFilter;
  String _selectedSortOption = 'Newest First';
  final List<String> _hazardTypes = [];
  final List<String> _statusOptions = ['All', 'impassable', 'partial', 'clear', 'uncertain'];
  final List<String> _sortOptions = [
    'Newest First',
    'Oldest First',
    'Hazard Type (A-Z)',
    'Hazard Type (Z-A)',
    'Valid From (Soonest)',
    'Valid From (Latest)',
    'Created By (A-Z)',
    'Created By (Z-A)'
  ];
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();
    _loadAdvisories();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    _animationController.dispose();
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

  void _applyFiltersAndSort() {
    var filtered = _officialAdvisories;

    // Text search
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((advisory) {
        return (advisory['hazard_type']?.toString().toLowerCase().contains(query) ?? false) ||
            (advisory['description']?.toString().toLowerCase().contains(query) ?? false) ||
            (advisory['valid_from']?.toString().toLowerCase().contains(query) ?? false) ||
            (advisory['valid_until']?.toString().toLowerCase().contains(query) ?? false) ||
            (advisory['created_by']?.toString().toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Hazard type filter
    if (_selectedHazardTypeFilter != 'All') {
      filtered = filtered.where((advisory) {
        return (advisory['hazard_type']?.toString() ?? '') == _selectedHazardTypeFilter;
      }).toList();
    }

    // Valid from filter
    if (_validFromFilter != null) {
      filtered = filtered.where((advisory) {
        final validFromStr = advisory['valid_from']?.toString();
        if (validFromStr == null) return false;
        try {
          final validFrom = DateTime.parse(validFromStr.split('T')[0]);
          return !validFrom.isBefore(_validFromFilter!);
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Valid until filter
    if (_validUntilFilter != null) {
      filtered = filtered.where((advisory) {
        final validUntilStr = advisory['valid_until']?.toString();
        if (validUntilStr == null) return false;
        try {
          final validUntil = DateTime.parse(validUntilStr.split('T')[0]);
          return !validUntil.isAfter(_validUntilFilter!);
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Apply sorting
    filtered = _applySort(filtered);

    setState(() {
      _filteredAdvisories = filtered;
    });
  }

  List<Map<String, dynamic>> _applySort(List<Map<String, dynamic>> advisories) {
    switch (_selectedSortOption) {
      case 'Newest First':
        return advisories.toList()
          ..sort((a, b) => DateTime.parse(b['created_at'] ?? '')
              .compareTo(DateTime.parse(a['created_at'] ?? '')));
      case 'Oldest First':
        return advisories.toList()
          ..sort((a, b) => DateTime.parse(a['created_at'] ?? '')
              .compareTo(DateTime.parse(b['created_at'] ?? '')));
      case 'Hazard Type (A-Z)':
        return advisories.toList()
          ..sort((a, b) => (a['hazard_type'] ?? '')
              .compareTo(b['hazard_type'] ?? ''));
      case 'Hazard Type (Z-A)':
        return advisories.toList()
          ..sort((a, b) => (b['hazard_type'] ?? '')
              .compareTo(a['hazard_type'] ?? ''));
      case 'Valid From (Soonest)':
        return advisories.toList()
          ..sort((a, b) => DateTime.parse(a['valid_from'] ?? '').compareTo(DateTime.parse(b['valid_from'] ?? '')));
      case 'Valid From (Latest)':
        return advisories.toList()
          ..sort((a, b) => DateTime.parse(b['valid_from'] ?? '').compareTo(DateTime.parse(a['valid_from'] ?? '')));
      case 'Created By (A-Z)':
        return advisories.toList()
          ..sort((a, b) => (a['created_by'] ?? '')
              .compareTo(b['created_by'] ?? ''));
      case 'Created By (Z-A)':
        return advisories.toList()
          ..sort((a, b) => (b['created_by'] ?? '')
              .compareTo(a['created_by'] ?? ''));
      default:
        return advisories;
    }
  }

  Future<void> _loadAdvisories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final advisories = await _databaseService.getOfficialAdvisories();
        if (mounted) {
          setState(() {
            _officialAdvisories = advisories;
            // Extract unique hazard types for filter dropdown
            _hazardTypes.clear();
            _hazardTypes.add('All');
            for (final advisory in advisories) {
              final hazardType = advisory['hazard_type']?.toString() ?? '';
              if (hazardType.isNotEmpty && !_hazardTypes.contains(hazardType)) {
                _hazardTypes.add(hazardType);
              }
            }
            _filteredAdvisories = List.from(_officialAdvisories); // Initially show all
            _isLoading = false;
          });
        }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
        _showErrorSnackBar('Failed to load advisories: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _createAdvisory() async {
    if (!mounted) return;

    final TextEditingController locationController = TextEditingController();
    final TextEditingController hazardTypeController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    DateTime? validFrom;
    DateTime? validUntil;
    final user = _databaseService.supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not authenticated')),
        );
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Official Advisory'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MouseRegion(
                  onEnter: (_) => HapticFeedback.lightImpact(),
                  child: TextField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: 'Location',
                      hintText: 'Enter location (e.g., Manila, Philippines)',
                      prefixIcon: Icon(
                        Icons.location_on_outlined,
                        color: AppTheme.textSecondaryColor,
                      ),
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
                        borderSide: BorderSide(
                            color: Color(0xFF1E3A8A), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                MouseRegion(
                  onEnter: (_) => HapticFeedback.lightImpact(),
                  child: TextField(
                    controller: hazardTypeController,
                    decoration: InputDecoration(
                      labelText: 'Hazard Type',
                      hintText: 'Enter hazard type (e.g., Flood, Typhoon)',
                      prefixIcon: Icon(
                        Icons.cloud_outlined,
                        color: AppTheme.textSecondaryColor,
                      ),
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
                        borderSide: BorderSide(
                            color: Color(0xFF1E3A8A), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                MouseRegion(
                  onEnter: (_) => HapticFeedback.lightImpact(),
                  child: TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'Enter advisory description',
                      prefixIcon: Icon(
                        Icons.description_outlined,
                        color: AppTheme.textSecondaryColor,
                      ),
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
                        borderSide: BorderSide(
                            color: Color(0xFF1E3A8A), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    maxLines: 4,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 20),
                MouseRegion(
                  onEnter: (_) => HapticFeedback.lightImpact(),
                  child: Row(
                    children: [
                      const Text('Valid From:'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.borderColor,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            validFrom == null
                                ? 'Not selected'
                                : validFrom!.toLocal().toString().split('T')[0],
                            style: const TextStyle(
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null && mounted) {
                            setState(() {
                              validFrom = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                MouseRegion(
                  onEnter: (_) => HapticFeedback.lightImpact(),
                  child: Row(
                    children: [
                      const Text('Valid Until:'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.borderColor,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            validUntil == null
                                ? 'Not selected'
                                : validUntil!.toLocal().toString().split('T')[0],
                            style: const TextStyle(
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: validFrom ?? DateTime.now(),
                            firstDate: validFrom ?? DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null && mounted) {
                            setState(() {
                              validUntil = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            MouseRegion(
              onEnter: (_) => HapticFeedback.lightImpact(),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            MouseRegion(
              onEnter: (_) => HapticFeedback.lightImpact(),
              child: ElevatedButton(
                onPressed: () async {
                  if (locationController.text.isEmpty ||
                      hazardTypeController.text.isEmpty ||
                      descriptionController.text.isEmpty ||
                      validFrom == null ||
                      validUntil == null) {
                    if (!mounted) return;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in all fields')),
                      );
                    }
                    return;
                  }

                  if (validFrom!.isAfter(validUntil!)) {
                    if (!mounted) return;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Valid From must be before Valid Until')),
                      );
                    }
                    return;
                  }

                  try {
                    await _databaseService.createOfficialAdvisory(
                      location: locationController.text.trim(),
                      hazardType: hazardTypeController.text.trim(),
                      description: descriptionController.text.trim(),
                      validFrom: validFrom!,
                      validUntil: validUntil!,
                      createdBy: user.id,
                    );
                    if (!mounted) return;
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Advisory created successfully!')),
                      );
                    }
                    await _loadAdvisories();
                  } catch (e) {
                    if (!mounted) return;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to create advisory: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: InkWell(
                  onTap: () => HapticFeedback.mediumImpact(),
                  child: const Text('Create'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _AdvisoriesSkeletonLoader();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'Error: $_error',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadAdvisories,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Use filtered advisories for display
    final displayAdvisories = _filteredAdvisories.isNotEmpty ? _filteredAdvisories : _officialAdvisories;

    if (displayAdvisories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EmptyState(
              icon: Icons.announcement_outlined,
              title: _searchController.text.isNotEmpty
                  ? 'No advisories match your search'
                  : 'No official advisories yet',
              subtitle: _searchController.text.isNotEmpty
                  ? 'Try adjusting your search terms'
                  : 'Advisories will appear here when created by agency officials',
            ),
            const SizedBox(height: 24),
            if (_searchController.text.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  _searchController.clear();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Clear Search'),
              ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search advisories by hazard type, description, dates, or creator...',
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
                // Add Advisory Button
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Create Advisory',
                    onPressed: _createAdvisory,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(24.0),
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemCount: displayAdvisories.length,
              itemBuilder: (context, index) {
                final advisory = displayAdvisories[index];
                return MouseRegion(
                  onEnter: (_) => HapticFeedback.lightImpact(),
                  child: Container(
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
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(24.0),
                          leading: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.announcement,
                              color: AppTheme.warningColor,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            advisory['hazard_type'] ?? 'Unknown Hazard',
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
                                advisory['description'] ?? 'No description',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppTheme.textPrimaryColor,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Valid: ${advisory['valid_from']?.toString().split('T')[0] ?? 'N/A'} to ${advisory['valid_until']?.toString().split('T')[0] ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.warningColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'By: ${advisory['created_by'] ?? 'Unknown'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Skeleton loader for Advisories tab
class _AdvisoriesSkeletonLoader extends StatelessWidget {
  const _AdvisoriesSkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // Search Bar - Skeleton
        Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.2)),
            ),
          ),
        ),

        // Filter Controls - Skeleton
        Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Wrap(
            spacing: 16.0,
            runSpacing: 12.0,
            children: List.generate(4, (_) => _buildSkeletonFilterControl()),
          ),
        ),

        // Advisory Cards - Skeleton
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemCount: 3,
          itemBuilder: (context, index) => _buildSkeletonAdvisoryCard(),
        ),
      ],
    );
  }

  Widget _buildSkeletonFilterControl() {
    return SizedBox(
      width: 120,
      child: TextField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Filter',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF1E3A8A).withValues(alpha: 0.2), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSkeletonAdvisoryCard() {
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
        child: ListTile(
          contentPadding: const EdgeInsets.all(24.0),
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          title: Container(
            width: double.infinity,
            height: 18,
            decoration: BoxDecoration(
              color: AppTheme.textPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 15,
                decoration: BoxDecoration(
                  color: AppTheme.textPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  width: 80,
                  height: 13,
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  width: 60,
                  height: 13,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    this.subtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}