import 'package:isar/isar.dart';

part 'user.g.dart';

@collection
class User {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String? uuid;

  @Index()
  String? email;

  String? name;

  String? avatarUrl;

  DateTime? lastActive;

  // Track when this contact was first added (for showing "NEW" indicator)
  DateTime? contactCreatedAt;

  User({
    this.uuid,
    this.email,
    this.name,
    this.avatarUrl,
    this.lastActive,
    this.contactCreatedAt,
  });

  User copyWith({
    String? uuid,
    String? email,
    String? name,
    String? avatarUrl,
    DateTime? lastActive,
    DateTime? contactCreatedAt,
  }) {
    return User(
      uuid: uuid ?? this.uuid,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastActive: lastActive ?? this.lastActive,
      contactCreatedAt: contactCreatedAt ?? this.contactCreatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': uuid,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'last_active': lastActive?.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uuid: json['id'] ?? json['uuid'],
      email: json['email'],
      name: json['name'],
      avatarUrl: json['avatar_url'],
      lastActive: json['last_active'] != null 
          ? DateTime.parse(json['last_active']) 
          : null,
    );
  }
} 