class UserProfile {
  final String id;
  final int reputation;
  final String email;
  final String? displayName;
  final String? agency;
  final String? role;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.reputation,
    required this.email,
    this.displayName,
    this.agency,
    this.role,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      reputation: json['reputation'] as int,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      agency: json['agency'] as String?,
      role: json['role'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
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
      'created_at': createdAt.toIso8601String(),
    };
  }
}