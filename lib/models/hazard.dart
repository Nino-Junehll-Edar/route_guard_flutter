import 'package:latlong2/latlong.dart';

enum HazardStatus { impassable, partial, clear, uncertain }

class Hazard {
  final String id;
  final String reporterUid;
  final String? agencyTag;
  final LatLng location;
  final String hazardType;
  final String? description;
  final String? photoUrl;
  final DateTime timestamp;
  final int confidence;
  final double weightedConfirms;
  final double weightedDenies;
  final DateTime createdAt;
  final DateTime updatedAt;

  Hazard({
    required this.id,
    required this.reporterUid,
    this.agencyTag,
    required this.location,
    required this.hazardType,
    this.description,
    this.photoUrl,
    required this.timestamp,
    this.confidence = 50,
    this.weightedConfirms = 0,
    this.weightedDenies = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Hazard.fromJson(Map<String, dynamic> json) {
    return Hazard(
      id: json['id'] as String,
      reporterUid: json['reporter_uid'] as String,
      agencyTag: json['agency_tag'] as String?,
      location: LatLng(
        (json['location'] as Map<String, dynamic>)['coordinates'][1] as double,
        (json['location'] as Map<String, dynamic>)['coordinates'][0] as double,
      ),
      hazardType: json['hazard_type'] as String,
      description: json['description'] as String?,
      photoUrl: json['photo_url'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      confidence: json['confidence'] as int,
      weightedConfirms: (json['weighted_confirms'] as num).toDouble(),
      weightedDenies: (json['weighted_denies'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  HazardStatus get status {
    final net = weightedConfirms - weightedDenies;
    if (confidence >= 80 && net >= 20) {
      return HazardStatus.impassable;
    } else if (confidence >= 60 && confidence < 80) {
      return HazardStatus.partial;
    } else if (confidence < 60 && net <= -20) {
      return HazardStatus.clear;
    }
    return HazardStatus.uncertain;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_uid': reporterUid,
      'agency_tag': agencyTag,
      'location': {
        'type': 'Point',
        'coordinates': [location.longitude, latitude]
      },
      'hazard_type': hazardType,
      'description': description,
      'photo_url': photoUrl,
      'timestamp': timestamp.toIso8601String(),
      'confidence': confidence,
      'weighted_confirms': weightedConfirms,
      'weighted_denies': weightedDenies,
      'status': _hazardStatusToString(status),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static String _hazardStatusToString(HazardStatus status) {
    switch (status) {
      case HazardStatus.impassable:
        return 'impassable';
      case HazardStatus.partial:
        return 'partial';
      case HazardStatus.clear:
        return 'clear';
      case HazardStatus.uncertain:
        return 'uncertain';
    }
  }

  double get latitude => location.latitude;
  double get longitude => location.longitude;
}