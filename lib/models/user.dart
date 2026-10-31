import 'user_profile.dart';

class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String status;
  final UserProfile? profile;

  const User({
    required this.id, required this.name, required this.email,
    required this.role, required this.status, this.profile,
  });

  bool get isBuyer   => role == 'buyer';
  bool get isSeller  => role == 'seller';
  bool get isCourier => role == 'courier';
  bool get isApproved => status == 'approved';

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  factory User.fromJson(Map<String, dynamic> j) => User(
    id:      j['id'] ?? 0,
    name:    j['name'] ?? '',
    email:   j['email'] ?? '',
    role:    j['role'] ?? '',
    status:  j['status'] ?? '',
    profile: j['profile'] != null
        ? UserProfile.fromJson(j['profile'] as Map<String, dynamic>)
        : null,
  );

  User copyWith({UserProfile? profile, String? name}) => User(
    id: id, name: name ?? this.name, email: email,
    role: role, status: status, profile: profile ?? this.profile,
  );
}
