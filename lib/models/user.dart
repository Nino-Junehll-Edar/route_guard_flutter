class UserProfile {
  final String id;
  final int reputation;
  final String email;
  final String? displayName;
  final String? agency;
  final String? role;
  final String? approvalStatus;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime createdAt;
  final String platform; // 'mobile' or 'web' to distinguish account origins

  UserProfile({
    required this.id,
    required this.reputation,
    required this.email,
    this.displayName,
    this.agency,
    this.role,
    this.approvalStatus,
    this.approvedAt,
    this.approvedBy,
    required this.createdAt,
    required this.platform, // 'mobile' or 'web'
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      reputation: json['reputation'] as int,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      agency: json['agency'] as String?,
      role: json['role'] as String?,
      approvalStatus: json['approval_status'] as String?,
      approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at'] as String) : null,
      approvedBy: json['approved_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      platform: json['platform'] as String? ?? 'mobile', // Default to mobile for backward compatibility
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reputation': reputation,
      'email': email,
      'display_name': displayName,
      'agency': agency,
      'role': role,
      'approval_status': approvalStatus,
      'approved_at': approvedAt?.toIso8601String(),
      'approved_by': approvedBy,
      'created_at': createdAt.toIso8601String(),
      'platform': platform,
    };
  }
}