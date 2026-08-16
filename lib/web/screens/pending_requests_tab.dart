import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:route_guard/services/database_service.dart';
import 'package:route_guard/models/user.dart';
import 'package:route_guard/web/theme.dart';

class PendingRequestsTab extends StatefulWidget {
  const PendingRequestsTab({super.key});

  @override
  State<PendingRequestsTab> createState() => _PendingRequestsTabState();
}

class _PendingRequestsTabState extends State<PendingRequestsTab> {
  final DatabaseService _databaseService = DatabaseService();
  List<UserProfile> _pendingRequests = [];
  List<UserProfile> _filteredRequests = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _selectedAgencyFilter = 'All';
  String _selectedRoleFilter = 'All';
  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  String _selectedSortOption = 'Newest First';
  final List<String> _agencies = [];
  final List<String> _roles = [];
  final List<String> _sortOptions = [
    'Newest First',
    'Oldest First',
    'Agency (A-Z)',
    'Agency (Z-A)',
    'Role (A-Z)',
    'Role (Z-A)',
    'Email (A-Z)',
    'Email (Z-A)'
  ];

  @override
  void initState() {
    super.initState();
    _loadRequests();
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
          _applyFilters();
        });
      }
    });
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _databaseService.getPendingAgencyRequests();
      if (mounted) {
        setState(() {
          _pendingRequests = requests;
          // Extract unique agencies and roles for filter dropdowns
          _agencies.clear();
          _roles.clear();
          _agencies.add('All');
          _roles.add('All');

          for (final request in requests) {
            if (request.agency != null && request.agency!.isNotEmpty) {
              if (!_agencies.contains(request.agency)) {
                _agencies.add(request.agency!);
              }
            }
            if (request.role != null && request.role!.isNotEmpty) {
              if (!_roles.contains(request.role)) {
                _roles.add(request.role!);
              }
            }
          }

          _applyFilters();
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

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    var filtered = _pendingRequests.where((request) {
      // Text search
      final matchesSearch = query.isEmpty ||
          request.email.toLowerCase().contains(query) ||
          (request.agency != null && request.agency!.toLowerCase().contains(query)) ||
          (request.role != null && request.role!.toLowerCase().contains(query));

      // Agency filter
      final matchesAgency = _selectedAgencyFilter == 'All' ||
          request.agency == _selectedAgencyFilter;

      // Role filter
      final matchesRole = _selectedRoleFilter == 'All' ||
          request.role == _selectedRoleFilter;

      // Date range filter
      final matchesDate = (_startDateFilter == null ||
          request.createdAt.isAfter(_startDateFilter!)) &&
          (_endDateFilter == null ||
              request.createdAt.isBefore(_endDateFilter!.add(const Duration(days: 1))));

      return matchesSearch && matchesAgency && matchesRole && matchesDate;
    }).toList();

    // Apply sorting
    filtered = _applySort(filtered);

    setState(() {
      _filteredRequests = filtered;
    });
  }

  List<UserProfile> _applySort(List<UserProfile> requests) {
    switch (_selectedSortOption) {
      case 'Newest First':
        return requests.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case 'Oldest First':
        return requests.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case 'Agency (A-Z)':
        return requests.toList()
          ..sort((a, b) => (a.agency ?? '').compareTo(b.agency ?? ''));
      case 'Agency (Z-A)':
        return requests.toList()
          ..sort((a, b) => (b.agency ?? '').compareTo(a.agency ?? ''));
      case 'Role (A-Z)':
        return requests.toList()
          ..sort((a, b) => (a.role ?? '').compareTo(b.role ?? ''));
      case 'Role (Z-A)':
        return requests.toList()
          ..sort((a, b) => (b.role ?? '').compareTo(a.role ?? ''));
      case 'Email (A-Z)':
        return requests.toList()..sort((a, b) => a.email.compareTo(b.email));
      case 'Email (Z-A)':
        return requests.toList()..sort((a, b) => b.email.compareTo(a.email));
      default:
        return requests;
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

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedAgencyFilter = 'All';
      _selectedRoleFilter = 'All';
      _selectedSortOption = 'Newest First';
      _startDateFilter = null;
      _endDateFilter = null;
      _applyFilters();
    });
  }

  Widget _buildRequestCard(UserProfile request) {
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
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.email,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (request.agency != null && request.agency!.isNotEmpty) ...[
                    Text(
                      'Agency: ${request.agency}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                  if (request.role != null && request.role!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Role: ${request.role}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _rejectRequest(request.id),
                        icon: const Icon(Icons.cancel, size: 20),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: BorderSide(color: AppTheme.errorColor, width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _approveRequest(request.id),
                        icon: const Icon(Icons.check_circle, size: 20),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    // Use filtered requests for display
    final displayRequests = _filteredRequests.isNotEmpty ? _filteredRequests : _pendingRequests;

    if (displayRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.list_alt,
                size: 64,
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                _searchController.text.isNotEmpty ||
                    _selectedAgencyFilter != 'All' ||
                    _selectedRoleFilter != 'All' ||
                    _startDateFilter != null ||
                    _endDateFilter != null
                    ? 'No requests match your filters'
                    : 'No pending agency requests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _searchController.text.isNotEmpty ||
                    _selectedAgencyFilter != 'All' ||
                    _selectedRoleFilter != 'All' ||
                    _startDateFilter != null ||
                    _endDateFilter != null
                    ? 'Try adjusting your search and filters'
                    : 'All agency access requests have been processed',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_searchController.text.isNotEmpty ||
                  _selectedAgencyFilter != 'All' ||
                  _selectedRoleFilter != 'All' ||
                  _startDateFilter != null ||
                  _endDateFilter != null)
                ElevatedButton(
                  onPressed: _clearFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Clear Filters'),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Search and Filter Bar
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Search Field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search requests by email, agency, or role...',
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
                    borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Filter Controls
              Wrap(
                spacing: 16.0,
                runSpacing: 12.0,
                children: [
                  // Agency Filter Dropdown
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedAgencyFilter,
                      decoration: InputDecoration(
                        labelText: 'Agency',
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
                          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      items: _agencies.map((agency) {
                        return DropdownMenuItem<String>(
                          value: agency,
                          child: Text(agency),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedAgencyFilter = value;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),

                  // Role Filter Dropdown
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedRoleFilter,
                      decoration: InputDecoration(
                        labelText: 'Role',
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
                          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      items: _roles.map((role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedRoleFilter = value;
                            _applyFilters();
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
                          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
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
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),

                  // Date Range Filters
                  SizedBox(
                    width: 120,
                    child: TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'From Date',
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
                          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        suffixIcon: _startDateFilter != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _startDateFilter = null;
                                    _applyFilters();
                                  });
                                },
                              )
                            : const Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            _startDateFilter = picked;
                            _applyFilters();
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
                        labelText: 'To Date',
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
                          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        suffixIcon: _endDateFilter != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _endDateFilter = null;
                                    _applyFilters();
                                  });
                                },
                              )
                            : const Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            _endDateFilter = picked;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemCount: displayRequests.length,
            itemBuilder: (context, index) {
              final request = displayRequests[index];
              return _buildRequestCard(request);
            },
          ),
        ),
      ],
    );
  }
}