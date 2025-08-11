import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/user.dart' as app_user;
import '../models/message.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Conversation {
  final app_user.User contact;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime? lastMessageTime;

  Conversation({
    required this.contact,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastMessageTime,
  });
}

class ConversationProvider extends ChangeNotifier {
  static final ConversationProvider _instance = ConversationProvider._internal();
  factory ConversationProvider() => _instance;
  ConversationProvider._internal();

  final SupabaseService _supabaseService = SupabaseService();
  
  List<Conversation> _conversations = [];
  bool _isLoading = false;
  bool _isLoaded = false; // Add flag to track if conversations are loaded
  String? _error;

  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded; // Add getter for the flag
  String? get error => _error;

  Future<void> loadConversations(String userId) async {
    // Prevent unnecessary reloads if already loaded and not forced
    if (_isLoaded && !_isLoading) {
      return;
    }
    
    _isLoading = true;
    _error = null;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      // Get all conversations where the user is involved
      final conversations = <Conversation>[];
      
      // First, get user's contacts
      List<app_user.User> contacts;
      try {
        contacts = await _supabaseService.getContacts(userId);
      } catch (e) {
        print('Failed to load contacts from Supabase: $e');
        // If we can't load contacts from Supabase, show existing conversations
        // This allows the app to work offline with cached data
        if (_conversations.isNotEmpty) {
          _isLoading = false;
          notifyListeners();
          return;
        }
        // If no cached conversations, show error
        _error = 'No internet connection. Please check your connection and try again.';
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      // For each contact, get the latest message
      for (final contact in contacts) {
        try {
          final messages = await _supabaseService.getMessages(userId, contact.uuid!);
          
          Message? lastMessage;
          int unreadCount = 0;
          
          if (messages.isNotEmpty) {
            lastMessage = messages.last;
            // Only count messages after the last time the user viewed this conversation
            final lastReadAt = await _getLastReadAt(userId, contact.uuid!);
            unreadCount = messages.where((msg) {
              final isIncoming = msg.senderId == contact.uuid && msg.receiverId == userId;
              final isNewSinceRead = lastReadAt == null || (msg.timestamp != null && msg.timestamp!.isAfter(lastReadAt));
              return isIncoming && isNewSinceRead;
            }).length;
          }
          
          conversations.add(Conversation(
            contact: contact,
            lastMessage: lastMessage,
            unreadCount: unreadCount,
            lastMessageTime: lastMessage?.timestamp,
          ));
        } catch (e) {
          print('Error loading conversation for ${contact.name}: $e');
          // Add conversation without last message
          conversations.add(Conversation(contact: contact));
        }
      }
      
      // Also get conversations with users who messaged you but aren't in your contacts
      try {
        final allMessages = await _supabaseService.getAllMessagesForUser(userId);
        final usersYouMessaged = <String>{};
        final usersWhoMessagedYou = <String>{};
        
        for (final message in allMessages) {
          if (message.senderId == userId && message.receiverId != null) {
            usersYouMessaged.add(message.receiverId!);
          } else if (message.receiverId == userId && message.senderId != null) {
            usersWhoMessagedYou.add(message.senderId!);
          }
        }
        
        // Get all unique users you've interacted with
        final allUserIds = {...usersYouMessaged, ...usersWhoMessagedYou};
        
        // Remove users who are already in your contacts
        final contactIds = contacts.map((c) => c.uuid).where((id) => id != null).cast<String>().toSet();
        final nonContactUserIds = allUserIds.difference(contactIds);
        
        // Get user details for non-contacts
        for (final nonContactUserId in nonContactUserIds) {
          // Skip if this is the current user
          if (nonContactUserId == userId) continue;
          
          try {
            final user = await _supabaseService.getUserById(nonContactUserId);
            if (user != null) {
              final messages = await _supabaseService.getMessages(userId, nonContactUserId);
              
              Message? lastMessage;
              int unreadCount = 0;
              
              if (messages.isNotEmpty) {
                lastMessage = messages.last;
                final lastReadAt = await _getLastReadAt(userId, nonContactUserId);
                unreadCount = messages.where((msg) {
                  final isIncoming = msg.senderId == nonContactUserId && msg.receiverId == userId;
                  final isNewSinceRead = lastReadAt == null || (msg.timestamp != null && msg.timestamp!.isAfter(lastReadAt));
                  return isIncoming && isNewSinceRead;
                }).length;
              }
              
              conversations.add(Conversation(
                contact: user,
                lastMessage: lastMessage,
                unreadCount: unreadCount,
                lastMessageTime: lastMessage?.timestamp,
              ));
            }
          } catch (e) {
            print('Error loading conversation for non-contact user $nonContactUserId: $e');
          }
        }
      } catch (e) {
        print('Error loading non-contact conversations: $e');
      }
      
      // Sort by last message time (most recent first)
      conversations.sort((a, b) {
        if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });
      
      _conversations = conversations;
      _isLoading = false;
      _isLoaded = true; // Mark as loaded
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load conversations: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add method to force reload
  Future<void> forceReloadConversations(String userId) async {
    _isLoaded = false; // Reset the flag to force reload
    _error = null; // Clear any previous errors
    await loadConversations(userId);
  }

  void addMessage(Message message, String currentUserId) {
    // Find the conversation for this message
    final contactId = message.senderId == currentUserId 
        ? message.receiverId 
        : message.senderId;
    
    final conversationIndex = _conversations.indexWhere(
      (conv) => conv.contact.uuid == contactId
    );
    
    if (conversationIndex != -1) {
      // Update existing conversation
      final conversation = _conversations[conversationIndex];
      
      // Calculate new unread count
      int newUnreadCount = conversation.unreadCount;
      if (message.senderId == currentUserId) {
        // Message sent by current user - no change to unread count
        newUnreadCount = conversation.unreadCount;
      } else {
        // Message received by current user - increment unread count
        newUnreadCount = conversation.unreadCount + 1;
      }
      
      final updatedConversation = Conversation(
        contact: conversation.contact,
        lastMessage: message,
        unreadCount: newUnreadCount,
        lastMessageTime: message.timestamp,
      );
      
      _conversations[conversationIndex] = updatedConversation;
    } else {
      // Create new conversation - we need to get the contact details
      // This will be handled when the conversation list is reloaded
      print('New conversation created for contact: $contactId');
      // Force reload conversations to get the new contact
      // This will be called from the UI when needed
    }
    
    // Re-sort conversations
    _conversations.sort((a, b) {
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });
    
    notifyListeners();
  }

  void markConversationAsRead(String contactId) {
    final conversationIndex = _conversations.indexWhere(
      (conv) => conv.contact.uuid == contactId
    );
    
    if (conversationIndex != -1) {
      final conversation = _conversations[conversationIndex];
      final updatedConversation = Conversation(
        contact: conversation.contact,
        lastMessage: conversation.lastMessage,
        unreadCount: 0, // Reset unread count for this conversation only
        lastMessageTime: conversation.lastMessageTime,
      );
      
      _conversations[conversationIndex] = updatedConversation;
      // Persist last read timestamp so future reloads don't show past messages as unread
      _setLastReadAt(conversation.contact.uuid!);
      notifyListeners();
    }
  }

  // Persist and read last read timestamps per conversation
  Future<void> _setLastReadAt(String contactId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_read_at_$contactId', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<DateTime?> _getLastReadAt(String currentUserId, String contactId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString('last_read_at_$contactId');
      if (value == null) return null;
      return DateTime.tryParse(value);
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearConversations() {
    _conversations = [];
    _isLoaded = false; // Reset the loaded flag
    notifyListeners();
  }

  void deleteConversation(String contactId) {
    _conversations.removeWhere((conv) => conv.contact.uuid == contactId);
    notifyListeners();
  }

  // Add method to create a conversation when a contact is added
  Future<void> addConversationForContact(app_user.User contact) async {
    // Check if conversation already exists
    final existingIndex = _conversations.indexWhere(
      (conv) => conv.contact.uuid == contact.uuid
    );
    
    if (existingIndex == -1) {
      // Create new conversation without any messages
      final newConversation = Conversation(
        contact: contact,
        lastMessage: null,
        unreadCount: 0,
        lastMessageTime: null,
      );
      
      _conversations.add(newConversation);
      
      // Sort conversations (new ones without messages go to the bottom)
      _conversations.sort((a, b) {
        if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });
      
      notifyListeners();
    }
  }
} 