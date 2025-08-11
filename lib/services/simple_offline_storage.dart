import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';

class SimpleOfflineStorage {
  static final SimpleOfflineStorage _instance = SimpleOfflineStorage._internal();
  factory SimpleOfflineStorage() => _instance;
  SimpleOfflineStorage._internal();

  static const String _messagesKey = 'cached_messages';

  // Save messages to simple storage
  Future<void> saveMessages(String chatId, List<Message> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = messages.map((msg) => msg.toJson()).toList();
      final data = jsonEncode(messagesJson);
      await prefs.setString('${_messagesKey}_$chatId', data);
      print('✅ Saved ${messages.length} messages to simple storage for chat: $chatId');
    } catch (e) {
      print('❌ Error saving messages to simple storage: $e');
    }
  }

  // Get messages from simple storage
  Future<List<Message>> getMessages(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('${_messagesKey}_$chatId');
      
      if (data != null) {
        final messagesJson = jsonDecode(data) as List;
        final messages = messagesJson.map((json) => Message.fromJson(json)).toList();
        print('✅ Loaded ${messages.length} messages from simple storage for chat: $chatId');
        return messages;
      } else {
        print('ℹ️ No cached messages found for chat: $chatId');
        return [];
      }
    } catch (e) {
      print('❌ Error loading messages from simple storage: $e');
      return [];
    }
  }

  // Save a single message
  Future<void> saveMessage(String chatId, Message message) async {
    try {
      final existingMessages = await getMessages(chatId);
      existingMessages.add(message);
      await saveMessages(chatId, existingMessages);
    } catch (e) {
      print('❌ Error saving single message: $e');
    }
  }

  // Check if we have cached messages
  Future<bool> hasCachedMessages(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('${_messagesKey}_$chatId');
    } catch (e) {
      return false;
    }
  }

  // Clear cached messages for a chat
  Future<void> clearChatMessages(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_messagesKey}_$chatId');
      print('🗑️ Cleared cached messages for chat: $chatId');
    } catch (e) {
      print('❌ Error clearing cached messages: $e');
    }
  }

  // Clear all cached messages
  Future<void> clearAllMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_messagesKey));
      for (final key in keys) {
        await prefs.remove(key);
      }
      print('🗑️ Cleared all cached messages');
    } catch (e) {
      print('❌ Error clearing all cached messages: $e');
    }
  }

  // Debug: List all cached chats
  Future<void> debugCachedChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_messagesKey));
      print('📱 Cached chats: ${keys.length}');
      for (final key in keys) {
        final chatId = key.replaceFirst('${_messagesKey}_', '');
        final messages = await getMessages(chatId);
        print('  - Chat $chatId: ${messages.length} messages');
      }
    } catch (e) {
      print('❌ Error debugging cached chats: $e');
    }
  }
}
