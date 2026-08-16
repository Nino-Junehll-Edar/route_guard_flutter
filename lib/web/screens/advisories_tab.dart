import 'dart:async';
import 'package:flutter/material.dart';
import 'package:route_guard/services/database_service.dart';
import 'package:route_guard/web/theme.dart';

class AdvisoriesTab extends StatefulWidget {
  const AdvisoriesTab({super.key});

  @override
  State<AdvisoriesTab> createState() => _AdvisoriesTabState();
}

class _AdvisoriesTabState extends State<AdvisoriesTab> {
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
                TextField(
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
                TextField(
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
                TextField(
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text('Valid From:'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: validFrom == null
                          ? const Text('Not selected')
                          : Text(validFrom!.toLocal().toString().split('T')[0]),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Valid Until:'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: validUntil == null
                          ? const Text('Not selected')
                          : Text(validUntil!.toLocal().toString().split('T')[0]),
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
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
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)));
    }

    if (_officialAdvisories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.announcement_outlined,
                size: 64,
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'No official advisories yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Advisories will appear here when created by agency officials',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _createAdvisory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text('Create First Advisory'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24.0),
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemCount: _officialAdvisories.length,
      itemBuilder: (context, index) {
        final advisory = _officialAdvisories[index];
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
        );
      },
    );
  }
}