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
  bool _isLoading = true;
  String? _agencyOfficialId; // To store the agency official's user ID

  @override
  void initState() {
    super.initState();
    _fetchAgencyOfficialId();
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

    if (_hazardsForModeration.isEmpty) {
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
                'No hazards pending moderation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'All hazard reports have been reviewed',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24.0),
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemCount: _hazardsForModeration.length,
      itemBuilder: (context, index) {
        final hazardData = _hazardsForModeration[index];
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
    );
  }
}