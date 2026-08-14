import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:route_guard/services/performance_monitoring_service.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final PerformanceMonitoringService _perfService = PerformanceMonitoringService();

  Future<String> uploadHazardPhoto(File file, String fileName) async {
    return _perfService.logDurationWithResult<String>('UploadHazardPhoto', () async {
      try {
        await _supabase.storage
            .from('hazard-photos')
            .upload(fileName, file);

        // Get public URL
        final url = _supabase.storage
            .from('hazard-photos')
            .getPublicUrl(fileName);

        return url;
      } catch (e) {
        rethrow;
      }
    });
  }

  Future<void> deleteHazardPhoto(String fileName) async {
    await _perfService.logDuration('DeleteHazardPhoto', () async {
      await _supabase.storage
          .from('hazard-photos')
          .remove([fileName]);
    });
  }
}