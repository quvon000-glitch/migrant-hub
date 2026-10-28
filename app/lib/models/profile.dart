class MyProfile {
  final String id;
  final String phone;
  final String displayName;
  final String? lastName;
  final String? username;
  final String? avatarUrl;
  final String? about;
  final bool phoneVisible;
  final DateTime? birthDate;
  final String? birthPlace;
  final String? citizenship;
  final String? currentCity;
  final String? recoveryEmail;
  final String? chatCity;
  final String role;
  final DateTime? resetRequestedAt;
  final DateTime createdAt;

  const MyProfile({
    required this.id, required this.phone, required this.displayName, this.lastName, this.username, this.avatarUrl,
    this.about, required this.phoneVisible, this.birthDate, this.birthPlace, this.citizenship, this.currentCity,
    this.recoveryEmail, this.chatCity, required this.role, this.resetRequestedAt, required this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  String get fullName => [displayName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');
  String get initial => displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  factory MyProfile.fromJson(Map<String, dynamic> j) => MyProfile(
        id: j['id'] as String,
        phone: j['phone'] as String,
        displayName: j['display_name'] as String,
        lastName: j['last_name'] as String?,
        username: j['username'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        about: j['about'] as String?,
        phoneVisible: j['phone_visible'] as bool? ?? false,
        birthDate: j['birth_date'] == null ? null : DateTime.parse(j['birth_date'] as String),
        birthPlace: j['birth_place'] as String?,
        citizenship: j['citizenship'] as String?,
        currentCity: j['current_city'] as String?,
        recoveryEmail: j['recovery_email'] as String?,
        chatCity: j['chat_city'] as String?,
        role: j['role'] as String? ?? 'user',
        resetRequestedAt: j['reset_requested_at'] == null ? null : DateTime.parse(j['reset_requested_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// What other members can see.
class PublicProfile {
  final String id;
  final String displayName;
  final String? lastName;
  final String? username;
  final String? avatarUrl;
  final String? about;
  final String? phone;
  final bool isAdmin;
  final DateTime? lastSeenAt;

  const PublicProfile({required this.id, required this.displayName, this.lastName, this.username, this.avatarUrl, this.about, this.phone, this.isAdmin = false, this.lastSeenAt});

  String get fullName => [displayName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');

  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
        id: j['id'] as String,
        displayName: j['display_name'] as String? ?? 'Foydalanuvchi',
        lastName: j['last_name'] as String?,
        username: j['username'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        about: j['about'] as String?,
        phone: j['phone'] as String?,
        isAdmin: j['is_admin'] as bool? ?? false,
        lastSeenAt: j['last_seen_at'] == null ? null : DateTime.parse(j['last_seen_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'display_name': displayName, 'last_name': lastName, 'username': username, 'avatar_url': avatarUrl,
        'about': about, 'phone': phone, 'is_admin': isAdmin, 'last_seen_at': lastSeenAt?.toIso8601String(),
      };

  static const unknown = PublicProfile(id: '', displayName: 'Foydalanuvchi');
}
