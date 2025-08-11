import 'package:isar/isar.dart';

part 'contact.g.dart';

@collection
class Contact {
  Id id = Isar.autoIncrement;

  @Index()
  String? userId;

  @Index()
  String? contactId;

  DateTime? createdAt;

  Contact({
    this.userId,
    this.contactId,
    this.createdAt,
  });

  Contact copyWith({
    String? userId,
    String? contactId,
    DateTime? createdAt,
  }) {
    return Contact(
      userId: userId ?? this.userId,
      contactId: contactId ?? this.contactId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'contact_id': contactId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      userId: json['user_id'],
      contactId: json['contact_id'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }
} 