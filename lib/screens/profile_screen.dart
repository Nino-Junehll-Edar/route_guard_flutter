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
  bool _isEditMode = false;
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _databaseService = ServiceLocator().synchronizedDatabaseService;
    _loadUserProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current user ID from Supabase
      final userId =
          _databaseService.databaseService.supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _error = 'User not authenticated';
        });
        return;
      }

      // Load user profile
      final profile = await _databaseService.databaseService.getUserProfile(userId);
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
          if (profile != null && profile.displayName != null) {
            _displayNameController.text = profile.displayName!;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_userProfile == null) return;

    setState(() => _isLoading = true);

    try {
      final updatedProfile = UserProfile(
        id: _userProfile!.id,
        reputation: _userProfile!.reputation,
        email: _userProfile!.email,
        displayName: _displayNameController.text.trim().isEmpty
            ? null
            : _displayNameController.text.trim(),
        agency: _userProfile!.agency,
        role: _userProfile!.role,
        approvalStatus: _userProfile!.approvalStatus,
        approvedAt: _userProfile!.approvedAt,
        approvedBy: _userProfile!.approvedBy,
        createdAt: _userProfile!.createdAt,
        platform: _userProfile!.platform,
      );

      await _databaseService.updateUserProfile(updatedProfile);
      if (mounted) {
        setState(() {
          _userProfile = updatedProfile;
          _isLoading = false;
          _isEditMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    }
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

  double _getReputationProgress(int reputation) {
    // Progress within current 100-point block (0.0 to 1.0)
    return (reputation % 100) / 100.0;
  }

  int _getReputationLevelNumber(int reputation) {
    return (reputation / 100).floor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditMode ? Icons.save : Icons.edit),
            onPressed: _isEditMode ? _updateProfile : () {
              setState(() => _isEditMode = true);
            },
          ),
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
                                CircleAvatar(
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
                                  _userProfile!.displayName ??
                                      _userProfile!.email.split('@')[0],
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _userProfile!.email,
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
                          if (!_isEditMode)
                            _buildInfoRowReadOnly(
                                'Email', _userProfile!.email)
                          else
                            _buildInfoRowEditable(
                                'Email', _userProfile!.email, false),
                          _buildInfoRowReadOnly(
                              'Member Since',
                              '${_userProfile!.createdAt.day}/${_userProfile!.createdAt.month}/${_userProfile!.createdAt.year}'),
                          if (!_isEditMode)
                            _buildInfoRowReadOnly(
                                'Agency', _userProfile!.agency ?? 'Not set')
                          else
                            _buildInfoRowEditable(
                                'Agency', _userProfile!.agency ?? '', true),
                          if (!_isEditMode)
                            _buildInfoRowReadOnly(
                                'Role', _userProfile!.role ?? 'Not set')
                          else
                            _buildInfoRowEditable(
                                'Role', _userProfile!.role ?? '', true),

                          const SizedBox(height: 24),

                          // Edit Profile Section (only visible in edit mode)
                          if (_isEditMode) ...[
                            _buildSectionTitle('Edit Profile'),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _displayNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Display Name',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value != null &&
                                          value.length > 50) {
                                        return 'Display name must be less than 50 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _updateProfile,
                                    child: const Text('Save Profile'),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
    final reputation = _userProfile!.reputation;
    final reputationLevel = _getReputationLevel(reputation);
    final reputationColor = _getReputationColor(reputation);
    final levelNumber = _getReputationLevelNumber(reputation);
    final progress = _getReputationProgress(reputation);

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
            // Reputation progress bar
            SizedBox(
              width: double.infinity,
              height: 8,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(reputationColor),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Level $levelNumber • ${(progress * 100).toInt()}/100 to next level',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRowReadOnly(String label, String value) {
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

  Widget _buildInfoRowEditable(
      String label, String value, bool isMultiline) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: value,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: isMultiline ? 3 : 1,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a value';
              }
              if (label == 'Display Name' && value.length > 50) {
                return 'Display name must be less than 50 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}