import 'package:isar/isar.dart';

part 'group_member.g.dart';

@collection
class GroupMember {
  Id id = Isar.autoIncrement;

  @Index()
  String? groupId;

  @Index()
  String? userId;

  DateTime? joinedAt;

  GroupMember({
    this.groupId,
    this.userId,
    this.joinedAt,
  });

  GroupMember copyWith({
    String? groupId,
    String? userId,
    DateTime? joinedAt,
  }) {
    return GroupMember(
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'user_id': userId,
      'joined_at': joinedAt?.toIso8601String(),
    };
  }

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      groupId: json['group_id'],
      userId: json['user_id'],
      joinedAt: json['joined_at'] != null 
          ? DateTime.parse(json['joined_at']) 
          : null,
    );
  }
} 