import 'package:isar/isar.dart';

part 'message.g.dart';

enum MessageStatus {
  sending,    // Message is being sent
  sent,       // Message has been sent to server (single checkmark)
  delivered,  // Message has been delivered to recipient (double checkmark)
  read,       // Message has been read by recipient (double blue checkmark)
  failed      // Message failed to send
}

enum MessageType {
  text,       // Text message
  image,      // Image attachment
  video,      // Video attachment
  file,       // File attachment
  audio,      // Audio attachment
}

@collection
class Message {
  Id id = Isar.autoIncrement;

  @Index()
  String? uuid;

  @Index()
  String? chatId;

  @Index()
  String? senderId;

  @Index()
  String? receiverId;

  String? content;

  DateTime? timestamp;

  bool isRead = false;

  // New status field for tracking message delivery
  @enumerated
  MessageStatus status = MessageStatus.sending;

  // Message type and attachment fields
  @enumerated
  MessageType type = MessageType.text;

  String? attachmentUrl;  // URL to the uploaded file
  String? attachmentName; // Original filename
  String? attachmentSize; // File size in bytes
  String? attachmentType; // MIME type

  Message({
    this.uuid,
    this.chatId,
    this.senderId,
    this.receiverId,
    this.content,
    this.timestamp,
    this.isRead = false,
    this.status = MessageStatus.sending,
    this.type = MessageType.text,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentType,
  });

  Message copyWith({
    String? uuid,
    String? chatId,
    String? senderId,
    String? receiverId,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    MessageStatus? status,
    MessageType? type,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentSize,
    String? attachmentType,
  }) {
    return Message(
      uuid: uuid ?? this.uuid,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      type: type ?? this.type,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentSize: attachmentSize ?? this.attachmentSize,
      attachmentType: attachmentType ?? this.attachmentType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': uuid,
      'chat_id': chatId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'timestamp': timestamp?.toIso8601String(),
      'is_read': isRead,
      'status': status.name,
      'type': type.name,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
      'attachment_size': attachmentSize,
      'attachment_type': attachmentType,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      uuid: json['id'],
      chatId: json['chat_id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      content: json['content'],
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : null,
      isRead: json['is_read'] ?? false,
      status: json['status'] != null 
          ? MessageStatus.values.firstWhere(
              (e) => e.name == json['status'],
              orElse: () => MessageStatus.sending,
            )
          : MessageStatus.sending,
      type: json['type'] != null 
          ? MessageType.values.firstWhere(
              (e) => e.name == json['type'],
              orElse: () => MessageType.text,
            )
          : MessageType.text,
      attachmentUrl: json['attachment_url'],
      attachmentName: json['attachment_name'],
      attachmentSize: json['attachment_size'],
      attachmentType: json['attachment_type'],
    );
  }
} 