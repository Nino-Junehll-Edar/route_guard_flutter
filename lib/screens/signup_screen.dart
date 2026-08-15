import 'package:flutter/material.dart';
import 'package:route_guard/models/user.dart';
import 'package:route_guard/services/auth_service.dart';
import 'package:route_guard/services/service_locator.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.signUpWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // Check if widget is still mounted
      if (!mounted) return;

      if (user != null) {
        // First, check if a profile already exists for this user
        final existingProfile = await ServiceLocator()
            .databaseService
            .getUserProfile(user.id);

        UserProfile userProfile;
        if (existingProfile == null) {
          // Create a default profile for new users (regular users)
          final defaultProfile = UserProfile(
            id: user.id,
            reputation: 0,
            email: user.email ?? _emailController.text.trim(),
            displayName: null,
            agency: null,
            role: null,
            approvalStatus: null,
            approvedAt: null,
            approvedBy: null,
            createdAt: DateTime.now(),
          );
          await ServiceLocator().databaseService.updateUserProfile(defaultProfile);
          userProfile = defaultProfile;
        } else {
          userProfile = existingProfile;
        }

        // Check if widget is still mounted after the async profile operations
        if (!mounted) return;

        // Determine navigation based on profile
        if (userProfile.agency != null &&
            userProfile.agency!.isNotEmpty &&
            userProfile.approvalStatus == 'approved' &&
            (userProfile.role == 'agency_official' || userProfile.role == 'admin')) {
          // Go to agency dashboard for approved agency officials
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/agency/dashboard');
          }
        } else {
          // Go to home screen for regular users or unapproved agency requests
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        }
      }
    } catch (e) {
      // Check if widget is still mounted before using context
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign up for RouteGuard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red[100],
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _signUp,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Sign Up'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/login');
              },
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}