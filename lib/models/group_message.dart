import 'package:isar/isar.dart';

part 'group_message.g.dart';

@collection
class GroupMessage {
  Id id = Isar.autoIncrement;

  @Index()
  String? uuid;

  @Index()
  String? groupId;

  @Index()
  String? senderId;

  String? content;

  DateTime? timestamp;

  bool isRead = false;

  String? senderName;

  GroupMessage({
    this.uuid,
    this.groupId,
    this.senderId,
    this.content,
    this.timestamp,
    this.isRead = false,
    this.senderName,
  });

  GroupMessage copyWith({
    String? uuid,
    String? groupId,
    String? senderId,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    String? senderName,
  }) {
    return GroupMessage(
      uuid: uuid ?? this.uuid,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      senderName: senderName ?? this.senderName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': uuid,
      'group_id': groupId,
      'sender_id': senderId,
      'content': content,
      'timestamp': timestamp?.toIso8601String(),
      'is_read': isRead,
      'sender_name': senderName,
    };
  }

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    return GroupMessage(
      uuid: json['id'],
      groupId: json['group_id'],
      senderId: json['sender_id'],
      content: json['content'],
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : null,
      isRead: json['is_read'] ?? false,
      senderName: json['sender_name'],
    );
  }
} 