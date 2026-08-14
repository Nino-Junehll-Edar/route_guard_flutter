import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:route_guard/models/hazard.dart';
import 'package:route_guard/services/performance_monitoring_service.dart';

class RealtimeHazardService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final PerformanceMonitoringService _perfService = PerformanceMonitoringService();

  RealtimeHazardService();

  Stream<List<Hazard>> getHazardStream({String? status}) {
    return _perfService.logDurationSync<Stream<List<Hazard>>>('GetHazardStream', () {
      // We'll use the realtime subscription
      return _supabase.from('hazards').stream(primaryKey: ['id']).map((List<dynamic> rows) {
        // If status filter is provided, we filter here
        if (status != null) {
          return rows
              .where((row) => row['status'] == status)
              .map((json) => Hazard.fromJson(json))
              .toList();
        }
        return rows.map((json) => Hazard.fromJson(json)).toList();
      });
    });
  }
}