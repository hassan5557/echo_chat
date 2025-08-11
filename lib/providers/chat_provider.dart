import 'package:flutter/material.dart';
import 'dart:io';
import '../services/supabase_service.dart';
import '../services/local_message_service.dart';
import '../services/simple_offline_storage.dart';
import '../models/message.dart';
import '../providers/conversation_provider.dart';


class ChatProvider extends ChangeNotifier {
  static final ChatProvider _instance = ChatProvider._internal();
  factory ChatProvider() => _instance;
  ChatProvider._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final LocalMessageService _localMessageService = LocalMessageService();
  final SimpleOfflineStorage _simpleStorage = SimpleOfflineStorage();
  
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;
  String? _currentChatId;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentChatId => _currentChatId;

  Future<void> loadMessages(String userId1, String userId2) async {
    _isLoading = true;
    _error = null;
    _currentChatId = _generateChatId(userId1, userId2);
    
    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    final chatId = _generateChatId(userId1, userId2);
    
    // First, try to load cached messages immediately for faster response
    try {
      final cachedMessages = await _simpleStorage.getMessages(chatId);
      if (cachedMessages.isNotEmpty) {
        _messages = cachedMessages;
        _isLoading = false;
        notifyListeners();
        print('📱 Showing ${cachedMessages.length} cached messages immediately');
      }
    } catch (e) {
      print('Error loading cached messages: $e');
    }

    // Then try to load fresh messages from Supabase in background
    try {
      final supabaseMessages = await _supabaseService.getMessages(userId1, userId2);
      
      print('🌐 Loaded ${supabaseMessages.length} messages from Supabase');
      
      // Save messages to both storage systems
      if (supabaseMessages.isNotEmpty) {
        // Save to simple storage (more reliable)
        await _simpleStorage.saveMessages(chatId, supabaseMessages);
        
        // Also try to save to Isar database
        try {
          await _localMessageService.saveMessages(supabaseMessages);
          print('💾 Saved ${supabaseMessages.length} messages to Isar database');
        } catch (saveError) {
          print('Error saving messages to Isar database: $saveError');
        }
      }
      
      // Update messages if we got fresh data
      if (supabaseMessages.isNotEmpty) {
        _messages = supabaseMessages;
        _error = null; // Clear any previous error
        notifyListeners();
      }
      
    } catch (e) {
      print('❌ Failed to load messages from Supabase: $e');
      
      // If we don't have cached messages and Supabase fails, show error
      if (_messages.isEmpty) {
        // Try Isar database as last resort
        try {
          final localMessages = await _localMessageService.getLocalMessages(userId1, userId2);
          print('🗄️ Loaded ${localMessages.length} messages from Isar database');
          
          if (localMessages.isNotEmpty) {
            _messages = localMessages;
            _error = 'Showing cached messages. No internet connection.';
          } else {
            _error = 'No internet connection and no cached messages available.';
          }
        } catch (localError) {
          print('Error loading from Isar database: $localError');
          _error = 'Failed to load messages: $e';
        }
      } else {
        // We have cached messages, just show offline indicator
        _error = 'Showing cached messages. No internet connection.';
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markMessagesAsRead(String currentUserId, String otherUserId) async {
    try {
      await _supabaseService.markMessagesAsRead(currentUserId, otherUserId);
      
      // Update local messages to mark them as read
      for (final message in _messages) {
        if (message.senderId == otherUserId && message.receiverId == currentUserId) {
          message.isRead = true;
          message.status = MessageStatus.read;
        }
      }
      
      // Update local database
      await _localMessageService.markMessagesAsRead(currentUserId, otherUserId);
      
      notifyListeners();
    } catch (e) {
      print('Error marking messages as read: $e');
      // Even if Supabase fails, update local database
      try {
        await _localMessageService.markMessagesAsRead(currentUserId, otherUserId);
      } catch (localError) {
        print('Error updating local messages as read: $localError');
      }
    }
  }

  // Update status of messages sent by current user when they are read by the other user
  void updateSentMessageStatus(String messageId, MessageStatus status) {
    final messageIndex = _messages.indexWhere((msg) => msg.uuid == messageId);
    if (messageIndex != -1) {
      _messages[messageIndex].status = status;
      notifyListeners();
    }
  }

  void updateMessageStatus(String messageId, MessageStatus status) {
    final messageIndex = _messages.indexWhere((msg) => msg.uuid == messageId);
    if (messageIndex != -1) {
      _messages[messageIndex].status = status;
      // Update local database
      _localMessageService.updateMessageStatus(messageId, status);
      notifyListeners();
    }
  }

  // Handle real-time status updates from Supabase
  void handleMessageStatusUpdate(Map<String, dynamic> messageData) {
    final messageId = messageData['id'];
    final status = messageData['status'];
    
    if (messageId != null && status != null) {
      MessageStatus newStatus;
      switch (status) {
        case 'sent':
          newStatus = MessageStatus.sent;
          break;
        case 'delivered':
          newStatus = MessageStatus.delivered;
          break;
        case 'read':
          newStatus = MessageStatus.read;
          break;
        case 'failed':
          newStatus = MessageStatus.failed;
          break;
        default:
          newStatus = MessageStatus.sent;
      }
      
      updateMessageStatus(messageId, newStatus);
    }
  }

  // Simulate message delivery for testing
  Future<void> simulateMessageDelivery(String messageId) async {
    // Simulate network delay (1-3 seconds)
    await Future.delayed(Duration(seconds: 1 + (DateTime.now().millisecond % 3)));
    updateMessageStatus(messageId, MessageStatus.delivered);
    
    // Simulate message being read after a longer delay (3-8 seconds)
    await Future.delayed(Duration(seconds: 3 + (DateTime.now().millisecond % 6)));
    updateMessageStatus(messageId, MessageStatus.read);
  }

  // Manually mark a message as read for testing
  void markMessageAsRead(String messageId) {
    updateMessageStatus(messageId, MessageStatus.read);
  }

  Future<bool> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    if (content.trim().isEmpty) return false;
    
    // Prevent sending messages to yourself
    if (senderId == receiverId) {
      _error = 'You cannot send messages to yourself';
      notifyListeners();
      return false;
    }
    
    try {
      // Create local message object with sending status
      // Don't set UUID initially - let the server assign it
      final newMessage = Message(
        senderId: senderId,
        receiverId: receiverId,
        content: content.trim(),
        timestamp: DateTime.now(),
        chatId: _generateChatId(senderId, receiverId),
        status: MessageStatus.sending,
        uuid: null, // Let server assign UUID
        type: MessageType.text,
      );
      
      // Add message to local list immediately for instant UI feedback
      _messages.add(newMessage);
      notifyListeners();
      
      // Save message to local storage immediately
      final chatId = _generateChatId(senderId, receiverId);
      try {
        await _simpleStorage.saveMessage(chatId, newMessage);
      } catch (e) {
        print('Error saving to simple storage: $e');
      }
      
      try {
        await _localMessageService.saveMessage(newMessage);
      } catch (e) {
        print('Error saving to Isar database: $e');
        // Continue without failing the message send
      }
      
      // Update conversation list immediately
      ConversationProvider().addMessage(newMessage, senderId);
      
      // Send the message to server in background
      _sendMessageToServer(senderId, receiverId, content.trim(), newMessage);
      
      // Ensure contact relationship exists in background
      _ensureContactRelationship(senderId, receiverId);
      
      return true;
      
    } catch (e) {
      // Mark message as failed if local operations fail
      if (_messages.isNotEmpty) {
        final lastMessage = _messages.last;
        if (lastMessage.content == content.trim()) {
          lastMessage.status = MessageStatus.failed;
          notifyListeners();
        }
      }
      _error = 'Failed to send message: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendMessageWithAttachment({
    required String senderId,
    required String receiverId,
    required String content,
    required File file,
    required MessageType type,
  }) async {
    if (senderId == receiverId) {
      _error = 'You cannot send messages to yourself';
      notifyListeners();
      return false;
    }
    
    try {
      // Create local message object with sending status
      final newMessage = Message(
        senderId: senderId,
        receiverId: receiverId,
        content: content.trim(),
        timestamp: DateTime.now(),
        chatId: _generateChatId(senderId, receiverId),
        status: MessageStatus.sending,
        uuid: null,
        type: type,
        attachmentName: file.path.split('/').last,
        attachmentSize: file.lengthSync().toString(),
      );
      
      // Add message to local list immediately for instant UI feedback
      _messages.add(newMessage);
      notifyListeners();
      
      // Save message to local storage immediately
      final chatId = _generateChatId(senderId, receiverId);
      try {
        await _simpleStorage.saveMessage(chatId, newMessage);
      } catch (e) {
        print('Error saving to simple storage: $e');
      }
      
      try {
        await _localMessageService.saveMessage(newMessage);
      } catch (e) {
        print('Error saving to Isar database: $e');
        // Continue without failing the message send
      }
      
      // Update conversation list immediately
      ConversationProvider().addMessage(newMessage, senderId);
      
      // Send the message with attachment to server in background
      _sendMessageWithAttachmentToServer(senderId, receiverId, content.trim(), file, type, newMessage);
      
      // Ensure contact relationship exists in background
      _ensureContactRelationship(senderId, receiverId);
      
      return true;
      
    } catch (e) {
      // Mark message as failed if local operations fail
      if (_messages.isNotEmpty) {
        final lastMessage = _messages.last;
        if (lastMessage.content == content.trim() && lastMessage.type == type) {
          lastMessage.status = MessageStatus.failed;
          notifyListeners();
        }
      }
      _error = 'Failed to send attachment: $e';
      notifyListeners();
      return false;
    }
  }

  // Send message to server in background
  Future<void> _sendMessageToServer(String senderId, String receiverId, String content, Message message) async {
    try {
      await _supabaseService.sendMessage(
        senderId: senderId,
        receiverId: receiverId,
        content: content,
      );
      
      // Update message status to sent
      message.status = MessageStatus.sent;
      await _localMessageService.updateMessageStatus(message.uuid!, MessageStatus.sent);
      notifyListeners();
      
      // Simulate message delivery for testing (remove this in production)
      if (message.uuid != null) {
        simulateMessageDelivery(message.uuid!);
      }
      
    } catch (e) {
      // Mark message as failed if server send fails
      message.status = MessageStatus.failed;
      notifyListeners();
      print('Failed to send message to server: $e');
    }
  }

  // Send message with attachment to server in background
  Future<void> _sendMessageWithAttachmentToServer(
    String senderId, 
    String receiverId, 
    String content, 
    File file, 
    MessageType type, 
    Message message
  ) async {
    try {
      await _supabaseService.sendMessageWithAttachment(
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        file: file,
        type: type,
      );
      
      // Update message status to sent
      message.status = MessageStatus.sent;
      await _localMessageService.updateMessageStatus(message.uuid!, MessageStatus.sent);
      notifyListeners();
      
      // Simulate message delivery for testing (remove this in production)
      if (message.uuid != null) {
        simulateMessageDelivery(message.uuid!);
      }
      
    } catch (e) {
      // Mark message as failed if server send fails
      message.status = MessageStatus.failed;
      notifyListeners();
      print('Failed to send attachment to server: $e');
    }
  }

  Future<bool> _ensureContactRelationship(String userId1, String userId2) async {
    try {
      bool wasContactAdded = false;
      
      // Prevent adding yourself as a contact
      if (userId1 == userId2) {
        print('Cannot add yourself as a contact');
        return false;
      }
      
      // Check if user1 has user2 as contact
      final user1Contacts = await _supabaseService.getContacts(userId1);
      final hasUser2AsContact = user1Contacts.any((contact) => contact.uuid == userId2);
      
      if (!hasUser2AsContact) {
        try {
          // Add user2 as contact for user1 (only the first time)
          await _supabaseService.addContact(userId1, userId2);
          print('Added $userId2 as contact for $userId1 (first message)');
          wasContactAdded = true;
        } catch (e) {
          // Handle duplicate key error silently
          final errorString = e.toString().toLowerCase();
          if (errorString.contains('duplicate key value') || 
              errorString.contains('dublicate key value') ||
              errorString.contains('23505') ||
              errorString.contains('contact_user_id_contact_id_key') ||
              errorString.contains('unique constraint') ||
              errorString.contains('violates unique constraint')) {
            print('Contact already exists: $userId2 for $userId1');
          } else {
            print('Error adding contact: $e');
          }
        }
      }
      
      // Check if user2 has user1 as contact
      final user2Contacts = await _supabaseService.getContacts(userId2);
      final hasUser1AsContact = user2Contacts.any((contact) => contact.uuid == userId1);
      
      if (!hasUser1AsContact) {
        try {
          // Add user1 as contact for user2 (only the first time)
          await _supabaseService.addContact(userId2, userId1);
          print('Added $userId1 as contact for $userId2 (first message)');
          wasContactAdded = true;
        } catch (e) {
          // Handle duplicate key error silently
          final errorString = e.toString().toLowerCase();
          if (errorString.contains('duplicate key value') || 
              errorString.contains('dublicate key value') ||
              errorString.contains('23505') ||
              errorString.contains('contact_user_id_contact_id_key') ||
              errorString.contains('unique constraint') ||
              errorString.contains('violates unique constraint')) {
            print('Contact already exists: $userId1 for $userId2');
          } else {
            print('Error adding contact: $e');
          }
        }
      }
      
      return wasContactAdded;
    } catch (e) {
      print('Error ensuring contact relationship: $e');
      // Don't fail the message sending if contact creation fails
      return false;
    }
  }

  void _notifyMessageSent(Message message, String currentUserId) {
    // This method is no longer needed since we directly call ConversationProvider
    // Keeping it for backward compatibility
  }

  String _generateChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  // Public method to generate chat ID for external use
  String generateChatId(String userId1, String userId2) {
    return _generateChatId(userId1, userId2);
  }

  // Add a new message to the current chat
  void addMessageToChat(Message message) {
    print('📨 Adding message to chat: ${message.content} (UUID: ${message.uuid})');
    
    // Check if message already exists to avoid duplicates
    // Check by UUID first, then by content and timestamp if UUID is null
    bool isDuplicate = false;
    
    if (message.uuid != null) {
      // Check by UUID
      isDuplicate = _messages.any((msg) => msg.uuid == message.uuid);
    } else {
      // Check by content, sender, receiver, and timestamp (within 5 seconds)
      final now = DateTime.now();
      isDuplicate = _messages.any((msg) => 
        msg.content == message.content &&
        msg.senderId == message.senderId &&
        msg.receiverId == message.receiverId &&
        msg.timestamp != null &&
        message.timestamp != null &&
        now.difference(msg.timestamp!).inSeconds < 5
      );
    }
    
    if (isDuplicate) {
      print('🚫 Duplicate message detected, skipping');
    }
    
    if (!isDuplicate) {
      // If this is a server message and we have a local message with same content,
      // update the local message with the server UUID instead of adding a duplicate
      if (message.uuid != null) {
        final localMessageIndex = _messages.indexWhere((msg) => 
          msg.uuid == null && // Local message without UUID
          msg.content == message.content &&
          msg.senderId == message.senderId &&
          msg.receiverId == message.receiverId &&
          msg.timestamp != null &&
          message.timestamp != null &&
          DateTime.now().difference(msg.timestamp!).inSeconds < 5
        );
        
        if (localMessageIndex != -1) {
          print('🔄 Updating local message with server UUID: ${message.uuid}');
          // Update the local message with server data
          final localMessage = _messages[localMessageIndex];
          localMessage.uuid = message.uuid;
          localMessage.status = message.status;
          localMessage.isRead = message.isRead;
          
          // Update local storage
          final chatId = _generateChatId(message.senderId ?? '', message.receiverId ?? '');
          _simpleStorage.saveMessage(chatId, localMessage);
          
          try {
            _localMessageService.saveMessage(localMessage);
          } catch (e) {
            print('Error updating message in Isar: $e');
          }
          
          notifyListeners();
          return;
        }
      }
      
      // Add new message if no duplicate found
      print('✅ Adding new message to chat');
      _messages.add(message);
      
      // Save to local storage in background
      final chatId = _generateChatId(message.senderId ?? '', message.receiverId ?? '');
      try {
        _simpleStorage.saveMessage(chatId, message);
      } catch (e) {
        print('Error saving to simple storage: $e');
      }
      
      try {
        _localMessageService.saveMessage(message);
      } catch (e) {
        print('Error saving new message to Isar: $e');
        // Continue without failing the UI update
      }
      
      // Update conversation list
      ConversationProvider().addMessage(message, message.senderId ?? '');
      
      // Notify listeners immediately for instant UI update
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearMessages() {
    _messages = [];
    _currentChatId = null;
    notifyListeners();
  }

  // Clear local messages for a specific chat
  Future<void> clearLocalMessages(String userId1, String userId2) async {
    await _localMessageService.deleteChatMessages(userId1, userId2);
  }

  // Clear all local messages
  Future<void> clearAllLocalMessages() async {
    await _localMessageService.clearAllMessages();
  }

  // Test method to manually save a message to local database
  Future<void> testLocalStorage(String userId1, String userId2) async {
    try {
      final chatId = _generateChatId(userId1, userId2);
      final testMessage = Message(
        uuid: 'test-${DateTime.now().millisecondsSinceEpoch}',
        chatId: chatId,
        senderId: userId1,
        receiverId: userId2,
        content: 'Test message for offline storage',
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );
      
      // Save to simple storage
      await _simpleStorage.saveMessage(chatId, testMessage);
      print('✅ Test message saved to simple storage');
      
      // Also try to save to Isar
      try {
        await _localMessageService.saveMessage(testMessage);
        print('✅ Test message saved to Isar database');
      } catch (e) {
        print('❌ Error saving test message to Isar: $e');
      }
      
      // Test retrieval from simple storage
      final simpleMessages = await _simpleStorage.getMessages(chatId);
      print('📱 Retrieved ${simpleMessages.length} messages from simple storage');
      
      // Test retrieval from Isar
      try {
        final isarMessages = await _localMessageService.getLocalMessages(userId1, userId2);
        print('🗄️ Retrieved ${isarMessages.length} messages from Isar database');
      } catch (e) {
        print('❌ Error retrieving from Isar: $e');
      }
      
    } catch (e) {
      print('❌ Error testing local storage: $e');
    }
  }

  // Public method to get local messages for testing
  Future<List<Message>> getLocalMessages(String userId1, String userId2) async {
    final chatId = _generateChatId(userId1, userId2);
    
    // Try simple storage first
    try {
      final simpleMessages = await _simpleStorage.getMessages(chatId);
      if (simpleMessages.isNotEmpty) {
        return simpleMessages;
      }
    } catch (e) {
      print('Error getting messages from simple storage: $e');
    }
    
    // Fallback to Isar
    try {
      return await _localMessageService.getLocalMessages(userId1, userId2);
    } catch (e) {
      print('Error getting messages from Isar: $e');
      return [];
    }
  }

  // Force cache current messages for offline use
  Future<void> forceCacheMessages(String userId1, String userId2) async {
    if (_messages.isNotEmpty) {
      final chatId = _generateChatId(userId1, userId2);
      await _simpleStorage.saveMessages(chatId, _messages);
      print('✅ Force cached ${_messages.length} messages for offline use');
    }
  }
} 