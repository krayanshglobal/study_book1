class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role; // "student", "admin", "superadmin"
  final String? classLevel;
  final String? referralCode;
  final String? referredBy;
  final bool subscriptionActive;
  final String? subscriptionExpiresAt;
  final int totalPoints;
  final String? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.classLevel,
    this.referralCode,
    this.referredBy,
    this.subscriptionActive = false,
    this.subscriptionExpiresAt,
    this.totalPoints = 0,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin' || role == 'superadmin';
  bool get isSuperAdmin => role == 'superadmin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'student',
      classLevel: json['class_level']?.toString(),
      referralCode: json['referral_code']?.toString(),
      referredBy: json['referred_by']?.toString(),
      subscriptionActive: json['subscription_active'] == true,
      subscriptionExpiresAt: json['subscription_expires_at']?.toString(),
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'class_level': classLevel,
      'referral_code': referralCode,
      'referred_by': referredBy,
      'subscription_active': subscriptionActive,
      'subscription_expires_at': subscriptionExpiresAt,
      'total_points': totalPoints,
      'created_at': createdAt,
    };
  }
}
