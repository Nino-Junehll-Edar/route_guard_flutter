import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:route_guard/services/database_service.dart';
import 'package:route_guard/models/hazard.dart';
import 'package:route_guard/web/theme.dart';
import 'package:flutter/services.dart' show HapticFeedback;

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  int _totalHazards = 0;
  int _pendingHazards = 0;
  int _confirmedHazards = 0;
  int _rejectedHazards = 0;
  List<Hazard> _allHazards = [];
  bool _isLoading = true;
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
    _loadStatistics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
          _showErrorSnackBar('Failed to load statistics: $e');
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
      return const _AnalyticsSkeletonLoader();
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
            child: _allHazards.isEmpty
                ? const Center(
                    child: Text(
                      'No hazard data available',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 16,
                      ),
                    ),
                  )
                : SizedBox(
                    height: 300,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              // Handle touch events for interactive pie chart
                            },
                          ),
                          borderData: FlBorderData(
                            show: false,
                          ),
                          sectionsSpace: 4,
                          centerSpaceRadius: 40,
                          sections: _buildHazardTypeSections(),
                        ),
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
      child: MouseRegion(
        onEnter: (_) => _animationController.forward(from: 0.0),
        onExit: (_) => _animationController.reverse(),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                // Add haptic feedback or visual feedback on tap
                HapticFeedback.lightImpact();
              },
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  color: color.withValues(alpha: 0.02),
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
    return MouseRegion(
      onEnter: (_) => HapticFeedback.lightImpact(),
      child: Container(
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
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.mediumImpact();
            },
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
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildHazardTypeSections() {
    // Count hazards by type
    Map<String, int> hazardTypeCounts = {};
    for (var hazard in _allHazards) {
      String type = hazard.hazardType;
      hazardTypeCounts[type] = (hazardTypeCounts[type] ?? 0) + 1;
    }

    // Convert to sections
    List<PieChartSectionData> sections = [];
    int total = _allHazards.length;

    hazardTypeCounts.forEach((type, count) {
      double percentage = (count / total) * 100;
      return sections.add(
        PieChartSectionData(
          value: count.toDouble(),
          title: '$type\n${percentage.toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          color: _getHazardTypeColor(type),
          badgeWidget: Container(
            alignment: Alignment.center,
            child: Text(
              '${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          badgePositionPercentageOffset: 1.4,
        ),
      );
    });

    return sections;
  }

  Color _getHazardTypeColor(String hazardType) {
    switch (hazardType.toLowerCase()) {
      case 'flood':
        return Colors.blue;
      case 'landslide':
        return Colors.brown;
      case 'earthquake':
        return Colors.grey;
      case 'fire':
        return Colors.red;
      case 'accident':
        return Colors.orange;
      case 'debris':
        return Colors.grey;
      default:
        return Colors.purple;
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

}

class _AnalyticsSkeletonLoader extends StatelessWidget {
  const _AnalyticsSkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // Stats Cards Section - Skeleton
        Padding(
          padding: const EdgeInsets.only(bottom: 32.0),
          child: Wrap(
            spacing: 24.0,
            runSpacing: 24.0,
            children: List.generate(4, (_) => _buildSkeletonStatCard()),
          ),
        ),

        // Hazard Trends Section - Skeleton
        _buildSkeletonSectionHeader('Hazard Trends'),
        Container(
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: AspectRatio(
                aspectRatio: 1.5,
                child: _buildSkeletonChart(),
              ),
            ),
          ),
        ),

        // Recent Activity Section - Skeleton
        _buildSkeletonSectionHeader('Recent Activity'),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemCount: 3,
          itemBuilder: (context, index) => _buildSkeletonHazardItem(),
        ),
      ],
    );
  }

  Widget _buildSkeletonStatCard() {
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
              color: AppTheme.borderColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.textPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        width: double.infinity,
        height: 20,
        decoration: BoxDecoration(
          color: AppTheme.textPrimaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildSkeletonChart() {
    return SizedBox(
      height: 200,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.textPrimaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildSkeletonHazardItem() {
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
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          title: Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: AppTheme.textPrimaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          subtitle: Container(
            width: double.infinity,
            height: 12,
            decoration: BoxDecoration(
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          trailing: Container(
            width: 40,
            height: 12,
            decoration: BoxDecoration(
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
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