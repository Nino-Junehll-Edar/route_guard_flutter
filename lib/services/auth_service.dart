import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:route_guard/services/performance_monitoring_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final PerformanceMonitoringService _perfService = PerformanceMonitoringService();

  Future<User?> signInWithEmailPassword(String email, String password) async {
    return _perfService.logDurationWithResult<User?>('SignInWithEmailPassword', () async {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.user;
    });
  }

  Future<User?> signUpWithEmailPassword(String email, String password) async {
    return _perfService.logDurationWithResult<User?>('SignUpWithEmailPassword', () async {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      return response.user;
    });
  }

  Future<User?> signInWithGoogle() async {
    return _perfService.logDurationWithResult<User?>('SignInWithGoogle', () async {
      await _supabase.auth.signInWithOAuth(
        Provider.google,
      );
      // signInWithOAuth initiates the OAuth flow and doesn't return a session directly
      // The actual user will be available via authStateChanges after redirect
      // Return null here and rely on authStateChanges listener to get the user
      return null;
    });
  }

  Future<void> signOut() async {
    return _perfService.logDuration('SignOut', () async {
      await _supabase.auth.signOut();
    });
  }

  Future<void> signOutAndRedirect(BuildContext context) async {
    try {
      await signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;
}