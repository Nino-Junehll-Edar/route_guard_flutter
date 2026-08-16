import 'package:flutter/material.dart';
import 'package:route_guard/services/auth_service.dart';
import 'package:route_guard/services/database_service.dart';
import 'package:route_guard/models/user.dart';
import 'package:route_guard/web/widgets/responsive_grid.dart';
import 'package:route_guard/web/theme.dart';
import 'pending_requests_tab.dart';
import 'advisories_tab.dart';
import 'moderation_tab.dart';
import 'analytics_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();

  UserProfile? _userProfile;
  bool _isAgencyOfficial = false;
  bool _isLoading = true;
  String? _error;

  // Dashboard overview metrics
  int _pendingRequestsCount = 0;
  int _hazardsForModerationCount = 0;
  int _activeAdvisoriesCount = 0;
  int _totalHazardsCount = 0;

  // Selected drawer item index
  int _selectedIndex = 0;

  // Fixed drawer items data (label, icon, visibility condition)
  final List<_DrawerItemData> _drawerItemsData = [
    _DrawerItemData(
      label: 'Dashboard / Overview',
      icon: Icons.dashboard,
      isVisible: (_) => true,
    ),
    _DrawerItemData(
      label: 'Pending Requests',
      icon: Icons.pending_actions,
      isVisible: (userProfile) => _canManageAgencyRequestsStatic(userProfile),
    ),
    _DrawerItemData(
      label: 'Advisories',
      icon: Icons.announcement,
      isVisible: (userProfile) => _canManageAdvisoriesStatic(userProfile),
    ),
    _DrawerItemData(
      label: 'Moderation',
      icon: Icons.shield,
      isVisible: (userProfile) => _canModerateHazardsStatic(userProfile),
    ),
    _DrawerItemData(
      label: 'Analytics',
      icon: Icons.analytics,
      isVisible: (_) => true,
    ),
  ];

  // Fixed pages corresponding to drawer items
  final List<Widget> _pages = [
    // DashboardOverviewPage will be built with the overview data
    const Placeholder(), // Will be replaced in build method
    const PendingRequestsTab(),
    const AdvisoriesTab(),
    const ModerationTab(),
    const AnalyticsTab(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current user ID from Supabase
      final userId = _databaseService.supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _error = 'User not authenticated';
        });
        return;
      }

      // Load user profile to check agency status
      final profile = await _databaseService.getUserProfile(userId);
      if (!mounted) return;

      setState(() {
        _userProfile = profile;
        _isAgencyOfficial = profile != null &&
            profile.agency != null &&
            profile.agency!.isNotEmpty &&
            profile.role != null &&
            profile.role!.isNotEmpty &&
            profile.approvalStatus == 'approved';
        _isLoading = false;
      });

      // Load overview data only if user is agency official
      if (_isAgencyOfficial && mounted) {
        _loadOverviewData();
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

  Future<void> _loadOverviewData() async {
    try {
      final results = await Future.wait([
        _databaseService.getPendingAgencyRequests(),
        _databaseService.getHazardsForModeration(),
        _databaseService.getOfficialAdvisories(),
        _databaseService.getHazards(),
      ]);

      if (mounted) {
        setState(() {
          _pendingRequestsCount = results[0].length;
          _hazardsForModerationCount = results[1].length;
          _activeAdvisoriesCount = results[2].length;
          _totalHazardsCount = results[3].length;
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

  Future<void> _logout() async {
    final authService = AuthService();
    try {
      await authService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  // Helper method to determine if user can manage agency requests (admin role)
  static bool _canManageAgencyRequestsStatic(UserProfile? profile) {
    return profile?.role?.toLowerCase() == 'admin' ||
        profile?.role?.toLowerCase() == 'administrator';
  }

  // Helper method to determine if user can create/edit advisories
  static bool _canManageAdvisoriesStatic(UserProfile? profile) {
    final role = profile?.role?.toLowerCase();
    return role == 'admin' ||
        role == 'administrator' ||
        role == 'moderator';
  }

  // Helper method to determine if user can moderate hazards
  static bool _canModerateHazardsStatic(UserProfile? profile) {
    final role = profile?.role?.toLowerCase();
    return role == 'admin' ||
        role == 'administrator' ||
        role == 'moderator';
  }

  @override
  Widget build(BuildContext context) {
    if (_databaseService.supabase.auth.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAgencyOfficial) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security, size: 64, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You do not have permission to access the agency dashboard.\n'
                  'Please contact your agency administrator to request access.',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_userProfile == null) {
      return const Scaffold(
        body: Center(child: Text('Profile not found')),
      );
    }

    // Update the first page to be DashboardOverviewPage with current data
    _pages[0] = DashboardOverviewPage(
      pendingRequestsCount: _pendingRequestsCount,
      hazardsForModerationCount: _hazardsForModerationCount,
      activeAdvisoriesCount: _activeAdvisoriesCount,
      totalHazardsCount: _totalHazardsCount,
      onRefresh: _loadOverviewData,
    );

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        title: Text(
          _drawerItemsData[_selectedIndex].label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                '${_userProfile?.agency ?? 'Unknown Agency'} • ${_userProfile?.role ?? 'Unknown Role'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOverviewData,
            tooltip: 'Refresh Data',
            color: Colors.white,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Account',
            color: Colors.white,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('My Profile')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
            onSelected: (value) async {
              if (value == 'logout') {
                await _logout();
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF1E3A8A),
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            for (int i = 0; i < _drawerItemsData.length; i++)
              if (_drawerItemsData[i].isVisible(_userProfile))
                ListTile(
                  leading: Icon(_drawerItemsData[i].icon),
                  title: Text(_drawerItemsData[i].label),
                  selected: _selectedIndex == i,
                  onTap: () {
                    setState(() => _selectedIndex = i);
                    Navigator.of(context).pop(); // Close the drawer
                  },
                ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
          : _error != null
              ? Center(
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
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadOverviewData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : IndexedStack(
                  index: _selectedIndex,
                  children: _pages,
                ),
    );
  }
}

// Data class for drawer items
class _DrawerItemData {
  final String label;
  final IconData icon;
  final bool Function(UserProfile?) isVisible;

  _DrawerItemData({
    required this.label,
    required this.icon,
    required this.isVisible,
  });
}

// Dashboard Overview Page
class DashboardOverviewPage extends StatelessWidget {
  final int pendingRequestsCount;
  final int hazardsForModerationCount;
  final int activeAdvisoriesCount;
  final int totalHazardsCount;
  final Future<void> Function()? onRefresh;

  const DashboardOverviewPage({
    super.key,
    required this.pendingRequestsCount,
    required this.hazardsForModerationCount,
    required this.activeAdvisoriesCount,
    required this.totalHazardsCount,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 16),
              ResponsiveGrid(
                children: [
                  _buildOverviewCard(
                    'Pending Requests',
                    pendingRequestsCount.toString(),
                    Icons.pending_actions,
                    AppTheme.warningColor,
                  ),
                  _buildOverviewCard(
                    'Hazards for Review',
                    hazardsForModerationCount.toString(),
                    Icons.shield,
                    AppTheme.errorColor,
                  ),
                  _buildOverviewCard(
                    'Active Advisories',
                    activeAdvisoriesCount.toString(),
                    Icons.announcement,
                    AppTheme.primaryColor,
                  ),
                  _buildOverviewCard(
                    'Total Hazards',
                    totalHazardsCount.toString(),
                    Icons.warning,
                    AppTheme.textSecondaryColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(String title, String count, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              count,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}