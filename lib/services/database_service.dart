import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:route_guard/models/user.dart';
import 'package:route_guard/models/hazard.dart';
import 'package:route_guard/services/performance_monitoring_service.dart';

class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final PerformanceMonitoringService _perfService = PerformanceMonitoringService();

  SupabaseClient get supabase => _supabase;

  // User profile operations
  Future<UserProfile?> getUserProfile(String userId) async {
    return _perfService.logDurationWithResult<UserProfile?>('GetUserProfile', () async {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();

      return UserProfile.fromJson(response);
    });
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    await _perfService.logDuration('UpdateUserProfile', () async {
      await _supabase
          .from('user_profiles')
          .update(profile.toJson())
          .eq('id', profile.id);
    });
  }

  // Hazard operations
  Future<List<Hazard>> getHazards({String? status, double? limit}) async {
    return _perfService.logDurationWithResult<List<Hazard>>('GetHazards', () async {
      final query = _supabase.from('hazards').select();

      final filteredQuery = status != null ? query.eq('status', status) : query;
      final limitedQuery = limit != null ? filteredQuery.limit(limit.toInt()) : filteredQuery;

      final response = await limitedQuery;
      return (response as List)
          .map((json) => Hazard.fromJson(json))
          .toList();
    });
  }

  Future<Hazard> createHazard(Hazard hazard) async {
    return _perfService.logDurationWithResult<Hazard>('CreateHazard', () async {
      final response = await _supabase
          .from('hazards')
          .insert(hazard.toJson())
          .select()
          .single();

      return Hazard.fromJson(response);
    });
  }

  Future<void> updateHazard(Hazard hazard) async {
    await _perfService.logDuration('UpdateHazard', () async {
      await _supabase
          .from('hazards')
          .update(hazard.toJson())
          .eq('id', hazard.id);
    });
  }

  // Moderation queue operations
  Future<void> addToModerationQueue(String hazardId, String reason) async {
    await _supabase.from('moderation_queue').insert({
      'hazard_id': hazardId,
      'reason': reason,
    });
  }

  Future<void> reviewModerationQueue(
      String moderationId,
      String reviewedBy,
      String outcome) async {
    await _supabase.from('moderation_queue').update({
      'reviewed_by': reviewedBy,
      'reviewed_at': DateTime.now().toIso8601String(),
      'outcome': outcome,
    }).eq('id', moderationId);
  }

  // Official advisories operations
  Future<void> createOfficialAdvisory({
    required String location,
    required String hazardType,
    required String description,
    required DateTime validFrom,
    required DateTime validUntil,
    required String createdBy,
  }) async {
    await _supabase.from('official_advisories').insert({
      'location': location,
      'hazard_type': hazardType,
      'description': description,
      'valid_from': validFrom.toIso8601String(),
      'valid_until': validUntil.toIso8601String(),
      'created_by': createdBy,
    });
  }

  Future<List<Map<String, dynamic>>> getOfficialAdvisories() async {
    final response = await _supabase.from('official_advisories').select();
    return response as List<Map<String, dynamic>>;
  }
}