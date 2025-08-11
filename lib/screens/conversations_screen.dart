import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/contact_provider.dart';
import '../models/user.dart' as app_user;

import '../services/supabase_service.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConversations();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only load conversations if they haven't been loaded yet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConversationsIfNeeded();
    });
  }

  Future<void> _loadConversations() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    
    if (authProvider.currentUser?.uuid != null) {
      await conversationProvider.loadConversations(authProvider.currentUser!.uuid!);
    }
  }

  Future<void> _loadConversationsIfNeeded() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    
    // Only load if conversations are empty and not currently loading
    if (authProvider.currentUser?.uuid != null && 
        !conversationProvider.isLoaded && 
        !conversationProvider.isLoading) {
      await conversationProvider.loadConversations(authProvider.currentUser!.uuid!);
    }
  }

  Future<void> _refreshConversations() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    
    if (authProvider.currentUser?.uuid != null && !conversationProvider.isLoading) {
      // Force reload conversations to get updated unread counts
      await conversationProvider.forceReloadConversations(authProvider.currentUser!.uuid!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 600 || screenWidth < 400;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Consumer<ConversationProvider>(
        builder: (context, conversationProvider, child) {
          if (conversationProvider.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
                strokeWidth: 3,
              ),
            );
          }

          if (conversationProvider.error != null) {
            return _buildErrorView(conversationProvider.error!, isSmallScreen, theme);
          }

          final conversations = conversationProvider.conversations;

          if (conversations.isEmpty) {
            return _buildEmptyView(isSmallScreen, theme);
          }

          return RefreshIndicator(
            color: theme.colorScheme.primary,
            onRefresh: _refreshConversations,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 8 : 12,
                horizontal: isSmallScreen ? 12 : 20,
              ),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                return _buildConversationTile(conversation, isSmallScreen, theme);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorView(String error, bool isSmallScreen, ThemeData theme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 20 : 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 70, color: theme.colorScheme.errorContainer),
            SizedBox(height: isSmallScreen ? 18 : 28),
            Text(
              'No Internet Connection',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 28 : 40),
            FilledButton.icon(
              onPressed: _refreshConversations,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 24 : 32,
                  vertical: isSmallScreen ? 14 : 18,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(bool isSmallScreen, ThemeData theme) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 24 : 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: isSmallScreen ? 72 : 90,
                color: theme.colorScheme.outline),
            SizedBox(height: isSmallScreen ? 18 : 28),
            Text(
              'No conversations yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.outline,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              'Start chatting with your contacts',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 28 : 40),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/contacts'),
              icon: const Icon(Icons.person_add),
              label: const Text('Add Contacts'),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 24 : 32,
                  vertical: isSmallScreen ? 14 : 18,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(Conversation conversation, bool isSmallScreen, ThemeData theme) {
    final contact = conversation.contact;
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.uuid;
    final overriddenName = currentUserId != null
        ? Provider.of<ContactProvider>(context, listen: false)
            .displayNameFor(currentUserId: currentUserId, contact: contact)
        : (contact.name ?? 'Unknown User');
    final lastMessage = conversation.lastMessage;
    final unreadCount = conversation.unreadCount;
    final hasUnread = unreadCount > 0;
    final isCurrentUserSender = lastMessage?.senderId ==
        Provider.of<AuthProvider>(context, listen: false).currentUser?.uuid;

    final isContact = Provider.of<ContactProvider>(context, listen: false)
        .contacts
        .any((c) => c.uuid == contact.uuid);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openChat(contact),
      onLongPress: () => _showDeleteConversationDialog(contact),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 10 : 14,
          horizontal: isSmallScreen ? 12 : 16,
        ),
        decoration: BoxDecoration(
          color: hasUnread
              ? theme.colorScheme.primary.withOpacity(0.08)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: isSmallScreen ? 24 : 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(
                    contact.name?.substring(0, 1).toUpperCase() ?? 'U',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 18 : 22,
                    ),
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 3,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: isSmallScreen ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                  child: Text(
                    overriddenName,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (lastMessage != null)
                        Text(
                          _formatTime(lastMessage.timestamp),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 13,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (lastMessage != null)
                    Row(
                      children: [
                        if (isCurrentUserSender)
                          Icon(
                            Icons.done_all,
                            size: isSmallScreen ? 14 : 16,
                            color: hasUnread ? theme.colorScheme.primary : theme.colorScheme.outline,
                          ),
                        if (isCurrentUserSender) const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            lastMessage.content ?? '',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              color: hasUnread
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'No messages yet',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: theme.colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            if (!isContact && lastMessage != null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 10,
                  vertical: isSmallScreen ? 3 : 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 14),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.tertiary.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'New',
                  style: TextStyle(
                    color: theme.colorScheme.onTertiary,
                    fontSize: isSmallScreen ? 11 : 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openChat(app_user.User contact) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Prevent opening chat with yourself
    if (authProvider.currentUser?.uuid == contact.uuid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You cannot chat with yourself'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Mark conversation as read when opening chat
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    conversationProvider.markConversationAsRead(contact.uuid!);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(contact: contact),
      ),
    );
  }

  void _showDeleteConversationDialog(app_user.User contact) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.person_add_alt_1,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Title
                Text(
                  'Conversation Options',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  'What would you like to do with ${contact.name}?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Action buttons
                Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Add Contact button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _addContact(contact);
                        },
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Add Contact'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Delete button (full width)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _deleteConversation(contact);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete Conversation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addContact(app_user.User contact) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);

    if (authProvider.currentUser?.uuid == null) return;

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('Adding ${contact.name} to contacts...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

         try {
       final success = await contactProvider.addContact(
         authProvider.currentUser!.uuid!,
         contact.uuid!,
       );

       if (success) {
         // Add conversation for the new contact
         final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
         await conversationProvider.addConversationForContact(contact);
         
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('${contact.name} added to contacts successfully!'),
             backgroundColor: Colors.green,
             duration: const Duration(seconds: 3),
           ),
         );
       } else {
         // Check if there's an error message in the provider
         final errorMessage = contactProvider.error;
         if (errorMessage != null) {
           final errorString = errorMessage.toLowerCase();
           if (errorString.contains('duplicate key value') || 
               errorString.contains('dublicate key value') ||
               errorString.contains('23505') ||
               errorString.contains('contact_user_id_contact_id_key') ||
               errorString.contains('unique constraint') ||
               errorString.contains('violates unique constraint')) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text('${contact.name} is already in your contacts'),
                 backgroundColor: Colors.orange,
                 duration: const Duration(seconds: 3),
               ),
             );
           } else {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text(errorMessage),
                 backgroundColor: Colors.red,
                 duration: const Duration(seconds: 3),
               ),
             );
           }
         } else {
           // No error message but method returned false - likely duplicate contact
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text('${contact.name} is already in your contacts'),
               backgroundColor: Colors.orange,
               duration: const Duration(seconds: 3),
             ),
           );
         }
       }
           } catch (e) {
        // Check if it's a duplicate key error - handle multiple variations
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('duplicate key value') || 
            errorString.contains('dublicate key value') ||
            errorString.contains('23505') ||
            errorString.contains('contact_user_id_contact_id_key') ||
            errorString.contains('unique constraint') ||
            errorString.contains('violates unique constraint')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${contact.name} is already in your contacts'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding contact: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
  }

  Future<void> _deleteConversation(app_user.User contact) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    final supabaseService = SupabaseService();

    if (authProvider.currentUser?.uuid == null) return;

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('Deleting conversation with ${contact.name}...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      // Delete messages from database
      await supabaseService.deleteMessages(
        authProvider.currentUser!.uuid!,
        contact.uuid!,
      );

      // Remove conversation from local state
      conversationProvider.deleteConversation(contact.uuid!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Conversation with ${contact.name} deleted'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete conversation: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    // Format time with AM/PM
    final hour = timestamp.hour;
    final minute = timestamp.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final timeString = '$displayHour:${minute.toString().padLeft(2, '0')} $period';
    
    if (messageDate == today) {
      return timeString;
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday $timeString';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year} $timeString';
    }
  }
} 