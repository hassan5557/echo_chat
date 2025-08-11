import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/message.dart';

class LocalMessageService {
  static final LocalMessageService _instance = LocalMessageService._internal();
  factory LocalMessageService() => _instance;
  LocalMessageService._internal();

  Isar? _isar;

  Future<Isar> get isar async {
    if (_isar != null) return _isar!;
    
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [MessageSchema],
      directory: dir.path,
    );
    return _isar!;
  }

  // Save a single message to local database
  Future<void> saveMessage(Message message) async {
    try {
      final isarInstance = await isar;
      await isarInstance.writeTxn(() async {
        // Check if message already exists to avoid duplicates
        if (message.uuid != null) {
          final existingMessage = await isarInstance.messages
              .filter()
              .uuidEqualTo(message.uuid!)
              .findFirst();
          
          if (existingMessage == null) {
            await isarInstance.messages.put(message);
            print('Message saved to Isar: ${message.content}');
          } else {
            print('Message already exists in Isar, skipping: ${message.content}');
          }
        } else {
          // For messages without UUID, just save them
          await isarInstance.messages.put(message);
          print('Message saved to Isar: ${message.content}');
        }
      });
    } catch (e) {
      print('Error saving message to Isar: $e');
      // Don't rethrow - let the app continue working
      // The message is already saved to simple storage
    }
  }

  // Save multiple messages to local database
  Future<void> saveMessages(List<Message> messages) async {
    try {
      final isarInstance = await isar;
      await isarInstance.writeTxn(() async {
        await isarInstance.messages.putAll(messages);
      });
      print('Successfully saved ${messages.length} messages to local database');
    } catch (e) {
      print('Error saving messages to local database: $e');
      rethrow;
    }
  }

  // Get messages for a specific chat from local database
  Future<List<Message>> getLocalMessages(String userId1, String userId2) async {
    try {
      final isarInstance = await isar;
      final chatId = _generateChatId(userId1, userId2);
      print('Looking for messages with chatId: $chatId');
      
      final messages = await isarInstance.messages
          .filter()
          .chatIdEqualTo(chatId)
          .sortByTimestamp()
          .findAll();
      
      print('Found ${messages.length} messages in local database for chatId: $chatId');
      return messages;
    } catch (e) {
      print('Error getting local messages: $e');
      rethrow;
    }
  }

  // Get all messages from local database
  Future<List<Message>> getAllLocalMessages() async {
    final isarInstance = await isar;
    return await isarInstance.messages.where().findAll();
  }

  // Update message status in local database
  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    final isarInstance = await isar;
    await isarInstance.writeTxn(() async {
      final message = await isarInstance.messages
          .filter()
          .uuidEqualTo(messageId)
          .findFirst();
      
      if (message != null) {
        message.status = status;
        await isarInstance.messages.put(message);
      }
    });
  }

  // Mark messages as read in local database
  Future<void> markMessagesAsRead(String currentUserId, String otherUserId) async {
    final isarInstance = await isar;
    await isarInstance.writeTxn(() async {
      final messages = await isarInstance.messages
          .filter()
          .senderIdEqualTo(otherUserId)
          .and()
          .receiverIdEqualTo(currentUserId)
          .findAll();
      
      for (final message in messages) {
        message.isRead = true;
        message.status = MessageStatus.read;
      }
      
      await isarInstance.messages.putAll(messages);
    });
  }

  // Delete messages for a specific chat
  Future<void> deleteChatMessages(String userId1, String userId2) async {
    final isarInstance = await isar;
    final chatId = _generateChatId(userId1, userId2);
    
    await isarInstance.writeTxn(() async {
      await isarInstance.messages
          .filter()
          .chatIdEqualTo(chatId)
          .deleteAll();
    });
  }

  // Clear all local messages
  Future<void> clearAllMessages() async {
    final isarInstance = await isar;
    await isarInstance.writeTxn(() async {
      await isarInstance.messages.clear();
    });
  }

  // Check if we have cached messages for a chat
  Future<bool> hasCachedMessages(String userId1, String userId2) async {
    final isarInstance = await isar;
    final chatId = _generateChatId(userId1, userId2);
    
    final count = await isarInstance.messages
        .filter()
        .chatIdEqualTo(chatId)
        .count();
    
    return count > 0;
  }

  // Get the latest message timestamp for a chat
  Future<DateTime?> getLatestMessageTime(String userId1, String userId2) async {
    final isarInstance = await isar;
    final chatId = _generateChatId(userId1, userId2);
    
    final latestMessage = await isarInstance.messages
        .filter()
        .chatIdEqualTo(chatId)
        .sortByTimestampDesc()
        .findFirst();
    
    return latestMessage?.timestamp;
  }

  // Generate chat ID for consistent storage
  String _generateChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  // Close the database
  Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }

  // Debug method to check database status
  Future<void> debugDatabase() async {
    try {
      final isarInstance = await isar;
      final totalMessages = await isarInstance.messages.count();
      print('Total messages in local database: $totalMessages');
      
      if (totalMessages > 0) {
        final sampleMessages = await isarInstance.messages.where().limit(3).findAll();
        for (final msg in sampleMessages) {
          print('Sample message: ${msg.content} (chatId: ${msg.chatId})');
        }
      }
    } catch (e) {
      print('Error debugging database: $e');
    }
  }
}
