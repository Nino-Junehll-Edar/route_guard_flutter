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

  // Google sign-in would require additional setup and packages
  // For now, we'll focus on email/password which is the core requirement
  Future<User?> signInWithGoogle() async {
    // TODO: Implement Google sign-in when needed
    // This would require additional configuration and possibly
    // the google_sign_in package
    throw UnimplementedError('Google sign-in not yet implemented');
  }

  Future<void> signOut() async {
    return _perfService.logDuration('SignOut', () async {
      await _supabase.auth.signOut();
    });
  }

  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;
}