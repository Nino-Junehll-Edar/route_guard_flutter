import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:route_guard/models/hazard.dart';
import 'package:route_guard/services/performance_monitoring_service.dart';
import 'dart:async';

class RealtimeHazardService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final PerformanceMonitoringService _perfService = PerformanceMonitoringService();

  RealtimeHazardService();

  Stream<List<Hazard>> getHazardStream({String? status}) {
    return _perfService.logDurationSync<Stream<List<Hazard>>>('GetHazardStream', () {
      // Controller for the stream
      final controller = StreamController<List<Hazard>>();

      // Set up real-time channel for hazards table
      final channel = _supabase.channel('realtime:public:hazards');

      // Listen to Postgres changes on the hazards table
      channel.on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(
          schema: 'public',
          table: 'hazards',
        ),
        (payload, [ref]) => _fetchAndAddHazards(controller, _supabase, status),
      );

      // Subscribe to the channel
      channel.subscribe();

      // When the stream is closed, unsubscribe from the channel
      controller.onCancel = () {
        _supabase.removeChannel(channel);
      };

      // Initial load
      _fetchAndAddHazards(controller, _supabase, status);

      return controller.stream;
    });
  }

  Future<void> _fetchAndAddHazards(
      StreamController<List<Hazard>> controller,
      SupabaseClient supabase,
      String? status) async {
    final query = supabase.from('hazards_with_geom').select('*');
    final filteredQuery = status != null ? query.eq('status', status) : query;

    try {
      final response = await filteredQuery;
      final List<dynamic> data = response;
      final List<Hazard> hazards = data
          .whereType<Map<String, dynamic>>()
          .map((json) => Hazard.fromJson(json))
          .toList();
      controller.add(hazards);
    } catch (error) {
      controller.addError(error);
    }
  }
}