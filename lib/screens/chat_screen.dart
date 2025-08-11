import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/contact_provider.dart' as contact_provider;
import '../providers/conversation_provider.dart';
import '../models/user.dart' as app_user;
import '../models/message.dart';
import '../services/supabase_service.dart';
import '../utils/app_theme.dart';
// import '../utils/modern_ui_helpers.dart';
// import '../widgets/theme_toggle_button.dart';
import '../widgets/modern_chat_input.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final app_user.User contact;

  const ChatScreen({super.key, required this.contact});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  ChatProvider? _chatProvider;
  // final _listViewKey = GlobalKey();
  late String _displayName;

  @override
  void initState() {
    super.initState();
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.uuid;
    if (currentUserId != null) {
      _displayName = Provider.of<contact_provider.ContactProvider>(context, listen: false)
          .displayNameFor(currentUserId: currentUserId, contact: widget.contact);
    } else {
      _displayName = widget.contact.name ?? 'Unknown User';
    }
    
    // Reset scroll position to top when entering a new chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load messages and mark as read in parallel for faster response
      _loadMessages();
      _markMessagesAsRead();
      _subscribeToStatusUpdates();
      
      // Ensure scroll to bottom after initial load
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollToBottomImmediately();
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store chat provider reference and listen to changes
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _chatProvider?.addListener(_onChatProviderChanged);
    
    // Reset scroll position when dependencies change (new chat)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _chatProvider?.removeListener(_onChatProviderChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChatProviderChanged() {
    // Scroll to bottom when messages are updated
    if (mounted) {
      // Use a small delay to ensure the UI has updated
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _scrollToBottomImmediately();
        }
      });
    }
  }



  Future<void> _loadMessages() async {
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (authProvider.currentUser?.uuid != null) {
      // Load messages immediately without testing storage
      await chatProvider.loadMessages(
        authProvider.currentUser!.uuid!,
        widget.contact.uuid!,
      );
      if (mounted) {
        // Scroll to bottom immediately when messages are loaded
        _scrollToBottomImmediately();
        
        // Also try again after a short delay to ensure it works
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _scrollToBottomImmediately();
          }
        });
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    
    if (authProvider.currentUser?.uuid != null) {
      await chatProvider.markMessagesAsRead(
        authProvider.currentUser!.uuid!,
        widget.contact.uuid!,
      );
      
      if (mounted) {
        // Update the conversation list to reflect the read status
        conversationProvider.markConversationAsRead(widget.contact.uuid!);
      }
    }
  }

  void _scrollToBottom() {
    if (!mounted) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToBottomImmediately() {
    if (!mounted) return;
    
    // Try immediate scroll first
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
    
    // Also try after frame callback as backup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
    
    // Try multiple times with delays to ensure it works
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
    
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _subscribeToStatusUpdates() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (authProvider.currentUser?.uuid != null) {
      final supabaseService = SupabaseService();
      
      // Subscribe to new messages in real-time
      supabaseService.subscribeToMessages(
        authProvider.currentUser!.uuid!,
        (messageData) {
          // Convert the message data to a Message object
          final newMessage = Message.fromJson(messageData);
          
          // Only add the message if it's for the current chat
          final currentUserId = authProvider.currentUser!.uuid!;
          final contactId = widget.contact.uuid!;
          final messageChatId = chatProvider.generateChatId(
            newMessage.senderId ?? '',
            newMessage.receiverId ?? '',
          );
          final currentChatId = chatProvider.generateChatId(currentUserId, contactId);
          
          if (messageChatId == currentChatId) {
            // Add the new message to the chat (will handle duplicates)
            chatProvider.addMessageToChat(newMessage);
          }
        },
      );
      
      // Subscribe to status updates for messages sent by current user
      supabaseService.subscribeToMessageStatusUpdates(
        authProvider.currentUser!.uuid!,
        (messageData) {
          chatProvider.handleMessageStatusUpdate(messageData);
        },
      );
    }
  }

  void _showProfileImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              // Full screen image
              Center(
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.error,
                          size: 50,
                          color: Colors.grey,
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _promptRenameContact() async {
    final controller = TextEditingController(text: _displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename contact'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter a name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (newName != null && newName.isNotEmpty) {
      await Provider.of<contact_provider.ContactProvider>(context, listen: false)
          .setLocalDisplayName(
        currentUserId:
            Provider.of<AuthProvider>(context, listen: false).currentUser!.uuid!,
        contactId: widget.contact.uuid!,
        displayName: newName,
      );
      setState(() {
        _displayName = newName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surfaceVariant.withOpacity(0.2),
      appBar: _buildModernAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessagesList()),
            ModernChatInput(
              onSend: (text) {
                _messageController.text = text;
                _sendMessage();
              },
              onAttachmentSelected: (file) {
                _handleAttachmentSelected(file);
              },
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: context.colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black12,
      titleSpacing: 0,
      title: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: context.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          GestureDetector(
            onTap: widget.contact.avatarUrl != null && widget.contact.avatarUrl!.isNotEmpty
                ? () => _showProfileImage(widget.contact.avatarUrl!)
                : null,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: context.colorScheme.primary,
                  backgroundImage: widget.contact.avatarUrl != null && widget.contact.avatarUrl!.isNotEmpty
                      ? NetworkImage(widget.contact.avatarUrl!)
                      : null,
                  child: widget.contact.avatarUrl == null || widget.contact.avatarUrl!.isEmpty
                      ? Text(
                          (widget.contact.name ?? 'U').substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                // Show a subtle overlay when avatar has an image to indicate it's tappable
                if (widget.contact.avatarUrl != null && widget.contact.avatarUrl!.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: context.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.visibility,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _promptRenameContact,
                  child: Text(
                    _displayName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  widget.contact.email ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      // Removed theme toggle
    );
  }

  Widget _buildMessagesList() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final messages = chatProvider.messages;
        if (messages.isEmpty) {
          return Center(
            child: Text("No messages yet", style: TextStyle(color: context.colorScheme.onSurface)),
          );
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final previousMessage = index > 0 ? messages[index - 1] : null;
            bool showDateSeparator = false;
            final currTs = message.timestamp;
            if (previousMessage == null) {
              showDateSeparator = true;
            } else if (currTs != null && previousMessage.timestamp != null) {
              final prev = previousMessage.timestamp!;
              final curr = currTs;
              final prevDate = DateTime(prev.year, prev.month, prev.day);
              final currDate = DateTime(curr.year, curr.month, curr.day);
              showDateSeparator = currDate.isAfter(prevDate);
            }
            final isCurrentUser = message.senderId ==
                Provider.of<AuthProvider>(context, listen: false).currentUser?.uuid;
            return Column(
              children: [
                if (showDateSeparator) _buildDateSeparator(currTs),
                Align(
                  alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      gradient: isCurrentUser
                          ? LinearGradient(
                              colors: [
                                context.colorScheme.primary,
                                context.colorScheme.primary.withOpacity(0.85),
                              ],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            )
                          : null,
                      color: isCurrentUser ? null : context.colorScheme.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isCurrentUser ? 18 : 4),
                        bottomRight: Radius.circular(isCurrentUser ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Show attachment preview
                        if (message.type != MessageType.text) ...[
                          _buildAttachmentPreview(message, isCurrentUser),
                          if (message.content?.isNotEmpty == true) const SizedBox(height: 8),
                        ],
                        // Show text content
                        if (message.content?.isNotEmpty == true)
                          Text(
                            message.content ?? '',
                            style: TextStyle(
                              color: isCurrentUser
                                  ? Colors.white
                                  : context.colorScheme.onSurface,
                              fontSize: 15,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          _formatAmPm(message.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: isCurrentUser
                                ? Colors.white.withOpacity(0.9)
                                : context.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Deprecated: replaced by ModernChatInput
  
  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (authProvider.currentUser?.uuid != null) {
      chatProvider.sendMessage(
        senderId: authProvider.currentUser!.uuid!,
        receiverId: widget.contact.uuid!,
        content: content,
      );
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _handleAttachmentSelected(File file) {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (authProvider.currentUser?.uuid != null) {
      // Determine message type based on file extension
      MessageType messageType = MessageType.file;
      final extension = file.path.split('.').last.toLowerCase();
      
      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
        messageType = MessageType.image;
      } else if (['mp4', 'avi', 'mov', 'mkv', 'webm'].contains(extension)) {
        messageType = MessageType.video;
      } else if (['mp3', 'wav', 'aac', 'm4a'].contains(extension)) {
        messageType = MessageType.audio;
      }
      
      // Send message with attachment
      chatProvider.sendMessageWithAttachment(
        senderId: authProvider.currentUser!.uuid!,
        receiverId: widget.contact.uuid!,
        content: '', // Empty content for attachment-only messages
        file: file,
        type: messageType,
      );
      
      _scrollToBottom();
    }
  }

  String _formatAmPm(DateTime? timestamp) {
    if (timestamp == null) return '';
    final hour = timestamp.hour;
    final minute = timestamp.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = (hour % 12 == 0) ? 12 : (hour % 12);
    final mm = minute.toString().padLeft(2, '0');
    return '$displayHour:$mm $period';
  }

  Widget _buildAttachmentPreview(Message message, bool isCurrentUser) {
    final theme = Theme.of(context);
    
    switch (message.type) {
      case MessageType.image:
        return Container(
          width: 200,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrentUser ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: message.attachmentUrl != null
                ? Image.network(
                    message.attachmentUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, size: 40, color: Colors.grey),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, size: 40, color: Colors.grey),
                  ),
          ),
        );
        
      case MessageType.video:
        return Container(
          width: 200,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_outline, size: 40, color: Colors.white),
          ),
        );
        
      case MessageType.audio:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCurrentUser ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_arrow,
                color: isCurrentUser ? Colors.white : theme.primaryColor,
              ),
              const SizedBox(width: 8),
                                   Text(
                       'Audio Message',
                       style: TextStyle(
                         color: isCurrentUser ? Colors.white : theme.colorScheme.onSurface,
                       ),
                     ),
            ],
          ),
        );
        
      case MessageType.file:
      default:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCurrentUser ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.attach_file,
                color: isCurrentUser ? Colors.white : theme.primaryColor,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                                         Text(
                       message.attachmentName ?? 'File',
                       style: TextStyle(
                         color: isCurrentUser ? Colors.white : theme.colorScheme.onSurface,
                         fontWeight: FontWeight.w500,
                       ),
                       overflow: TextOverflow.ellipsis,
                     ),
                    if (message.attachmentSize != null)
                      Text(
                        _formatFileSize(int.tryParse(message.attachmentSize!) ?? 0),
                        style: TextStyle(
                          color: isCurrentUser ? Colors.white.withOpacity(0.7) : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Widget _buildDateSeparator(DateTime? timestamp) {
    if (timestamp == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    String label;
    final difference = now.difference(messageDate).inDays;
    if (difference == 0) {
      label = 'Today';
    } else if (difference == 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMM d, yyyy').format(messageDate);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
} 