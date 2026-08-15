import 'package:flutter/material.dart';
import 'package:route_guard/models/user.dart';
import 'package:route_guard/services/auth_service.dart';
import 'package:route_guard/services/synchronized_database_service.dart';
import 'package:route_guard/services/service_locator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final SynchronizedDatabaseService _databaseService;
  UserProfile? _userProfile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _databaseService = ServiceLocator().synchronizedDatabaseService;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current user ID from Supabase
      final userId = _databaseService.databaseService.supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _error = 'User not authenticated';
        });
        return;
      }

      // Load user profile
      final profile = await _databaseService.databaseService.getUserProfile(userId);
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserProfile,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => AuthService().signOutAndRedirect(context),
          ),
        ],
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
              : _userProfile == null
                  ? const Center(child: Text('Profile not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Header
                          Center(
                            child: Column(
                              children: [
                                const CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.deepPurple,
                                  child: Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _userProfile?.displayName ?? _userProfile?.email ?? 'Anonymous',
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _userProfile?.email ?? '',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Reputation Section
                          _buildSectionTitle('Your Reputation'),
                          _buildReputationCard(),

                          const SizedBox(height: 24),

                          // Account Info Section
                          _buildSectionTitle('Account Information'),
                          _buildInfoRow('Email', _userProfile?.email ?? ''),
                          _buildInfoRow('Display Name',
                              _userProfile?.displayName ?? 'Not set'),
                          _buildInfoRow('Agency',
                              _userProfile?.agency ?? 'Not set'),
                          _buildInfoRow('Role',
                              _userProfile?.role ?? 'Not set'),
                          _buildInfoRow('Member Since',
                              _userProfile?.createdAt != null
                                  ? '${_userProfile!.createdAt.day}/${_userProfile!.createdAt.month}/${_userProfile!.createdAt.year}'
                                  : 'Not set'),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.deepPurple,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildReputationCard() {
    final reputation = _userProfile?.reputation ?? 0;
    final reputationLevel = _getReputationLevel(reputation);
    final reputationColor = _getReputationColor(reputation);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Reputation Score',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              '$reputation',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: reputationColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              reputationLevel,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: reputationColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 16),
            // Reputation progress bar (example)
            SizedBox(
              width: double.infinity,
              height: 8,
              child: LinearProgressIndicator(
                value: (reputation % 100) / 100.0, // Progress within current 100-point block
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(reputationColor),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Level ${(reputation / 100).floor()} • ${reputation % 100}/100 to next level',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _getReputationLevel(int reputation) {
    if (reputation >= 1000) return 'Elite Reporter';
    if (reputation >= 500) return 'Trusted Contributor';
    if (reputation >= 100) return 'Active Participant';
    if (reputation >= 50) return 'Getting Involved';
    return 'New Member';
  }

  Color _getReputationColor(int reputation) {
    if (reputation >= 1000) return Colors.amber;
    if (reputation >= 500) return Colors.orange;
    if (reputation >= 100) return Colors.lightGreen;
    if (reputation >= 50) return Colors.blueAccent;
    return Colors.grey;
  }
}