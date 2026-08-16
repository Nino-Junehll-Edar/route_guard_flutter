import 'package:flutter/material.dart';
import 'package:route_guard/services/database_service.dart';
import 'package:route_guard/models/hazard.dart';
import 'package:route_guard/web/theme.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
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

    final recentHazards = _allHazards.length > 5 ? _allHazards.sublist(_allHazards.length - 5) : _allHazards;

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // Stats Cards Section
        Padding(
          padding: const EdgeInsets.only(bottom: 32.0),
          child: Wrap(
            spacing: 24.0,
            runSpacing: 24.0,
            children: [
              _buildEnhancedStatCard('Total Hazards', _totalHazards.toString(), Icons.warning_outlined, AppTheme.primaryColor),
              _buildEnhancedStatCard('Pending Review', _pendingHazards.toString(), Icons.pending_actions_outlined, AppTheme.warningColor),
              _buildEnhancedStatCard('Confirmed', _confirmedHazards.toString(), Icons.check_circle_outlined, AppTheme.successColor),
              _buildEnhancedStatCard('Marked as False', _rejectedHazards.toString(), Icons.error_outlined, AppTheme.errorColor),
            ],
          ),
        ),

        // Hazard Trends Section
        _buildSectionHeader('Hazard Trends'),
        Container(
          height: 220,
          margin: const EdgeInsets.only(bottom: 24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
            child: const Center(
              child: Text(
                'Charts and visualizations coming soon\n(Hazard trends over time, type distribution, etc.)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),

        // Recent Activity Section
        _buildSectionHeader('Recent Activity'),
        if (recentHazards.isEmpty)
          const _EmptyState(
            icon: Icons.timeline,
            title: 'No hazard activity yet',
            subtitle: 'All hazard reports will appear here once submitted',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemCount: recentHazards.length,
            itemBuilder: (context, index) {
              final hazard = recentHazards.reversed.elementAt(index);
              return _buildHazardItem(hazard);
            },
          ),
      ],
    );
  }

  Widget _buildEnhancedStatCard(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildHazardItem(Hazard hazard) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(20.0),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getHazardColor(hazard.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getHazardIcon(hazard.hazardType),
              color: _getHazardColor(hazard.status),
              size: 24,
            ),
          ),
          title: Text(
            hazard.hazardType,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${hazard.status.toString().split('.').last} | ${hazard.confidence}% confidence',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
          trailing: Text(
            hazard.timestamp.toLocal().toString().split('.')[0],
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
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