import 'package:flutter/material.dart';
import 'package:route_guard/services/auth_service.dart';
import 'package:route_guard/services/database_service.dart';
import 'package:route_guard/models/user.dart';
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
  late final TabController _tabController;

  UserProfile? _userProfile;
  bool _isLoading = true;
  String? _error;
  bool _isAgencyOfficial = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
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
      if (mounted) {
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
      }

      // Load dashboard data only if user is agency official
      if (_isAgencyOfficial && mounted) {
        await Future.wait([
          _databaseService.getPendingAgencyRequests(),
          _databaseService.getHazardsForModeration(),
          _databaseService.getOfficialAdvisories(),
          _databaseService.getHazards(),
        ]);
        if (mounted) {
          setState(() => _isLoading = false);
        }
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
  bool _canManageAgencyRequests() {
    return _userProfile?.role?.toLowerCase() == 'admin' ||
        _userProfile?.role?.toLowerCase() == 'administrator';
  }

  // Helper method to determine if user can create/edit advisories
  bool _canManageAdvisories() {
    final role = _userProfile?.role?.toLowerCase();
    return role == 'admin' ||
        role == 'administrator' ||
        role == 'moderator';
  }

  // Helper method to determine if user can moderate hazards
  bool _canModerateHazards() {
    final role = _userProfile?.role?.toLowerCase();
    return role == 'admin' ||
        role == 'administrator' ||
        role == 'moderator';
  }

  @override
  Widget build(BuildContext context) {
    // If not authenticated, redirect to login
    if (_databaseService.supabase.auth.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If not agency official, show access denied message
    if (!_isAgencyOfficial) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          automaticallyImplyLeading: false,
          backgroundColor: Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.security,
                  size: 64,
                  color: Colors.red,
                ),
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
                Text(
                  'You do not have permission to access the agency dashboard.\n'
                  'Please contact your agency administrator to request access.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1E3A8A),
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Agency Dashboard'),
        backgroundColor: Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: Color(0xFF6B7280).withValues(alpha: 0.2),
                height: 4.0,
              ),
              TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white,
                      width: 3,
                    ),
                  ),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                indicatorSize: TabBarIndicatorSize.label,
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 12.0),
                dividerColor: Colors.transparent,
                tabs: [
                  if (_canManageAgencyRequests())
                    const Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.list_alt, size: 18, color: Color(0xFF93C5FD)),
                          SizedBox(width: 6),
                          Text('Requests', style: TextStyle(color: Color(0xFFDBEAFE))),
                        ],
                      ),
                    ),
                  if (_canManageAdvisories())
                    const Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.announcement, size: 18, color: Color(0xFFFDE68A)),
                          SizedBox(width: 6),
                          Text('Advisories', style: TextStyle(color: Color(0xFFFEF3C7))),
                        ],
                      ),
                    ),
                  if (_canModerateHazards())
                    const Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield, size: 18, color: Color(0xFF86EFAC)),
                          SizedBox(width: 6),
                          Text('Moderation', style: TextStyle(color: Color(0xFFDCFCE7))),
                        ],
                      ),
                    ),
                  const Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.analytics, size: 18, color: Color(0xFFC4B5FD)),
                        SizedBox(width: 6),
                        Text('Analytics', style: TextStyle(color: Color(0xFFEDE9FE))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // Display agency info
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
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
            color: Colors.white,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Account',
            color: Colors.white,
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
                await _logout();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
          : _error != null
              ? Center(
                  child: Text(
                    'Error: $_error',
                    style: TextStyle(color: Colors.red),
                  ),
                )
              : _userProfile == null
                  ? const Center(child: Text('Profile not found'))
                  : RefreshIndicator(
                      onRefresh: _loadDashboardData,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Only show tabs that the user has access to
                          if (_canManageAgencyRequests())
                            const PendingRequestsTab(),
                          if (_canManageAdvisories())
                            const AdvisoriesTab(),
                          if (_canModerateHazards())
                            const ModerationTab(),
                          const AnalyticsTab(),
                        ],
                      ),
                    ),
    );
  }
}