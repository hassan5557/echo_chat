import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/theme_toggle_button.dart';

import '../models/group.dart';
import '../models/group_message.dart';
import '../services/supabase_service.dart';
import 'group_details_screen.dart';
import '../widgets/modern_chat_input.dart';

class GroupChatScreen extends StatefulWidget {
  final Group group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<GroupMessage> _messages = [];
  bool _isLoading = false;
  String? _error;
  // ignore: prefer_final_fields
  SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToGroupMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (widget.group.uuid == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final messages = await _supabaseService.getGroupMessages(widget.group.uuid!);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = 'Failed to load messages: $e';
        _isLoading = false;
      });
    }
  }

  void _subscribeToGroupMessages() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser?.uuid != null) {
      _supabaseService.subscribeToGroupMessages(
        authProvider.currentUser!.uuid!,
        (messageData) {
          if (mounted) {
            final newMessage = GroupMessage.fromJson(messageData);
            setState(() {
              _messages.add(newMessage);
            });
            _scrollToBottom();
          }
        },
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser?.uuid == null || widget.group.uuid == null) return;

    _messageController.clear();

    try {
      await _supabaseService.sendGroupMessage(
        groupId: widget.group.uuid!,
        senderId: authProvider.currentUser!.uuid!,
        content: content,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 600 || screenWidth < 400;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupDetailsScreen(group: widget.group),
              ),
            );
          },
          child: Row(
            children: [
              // Group Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.green,
                child: Text(
                  (widget.group.name ?? 'G').substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              // Group Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.group.name ?? 'Group Chat',
                            style: TextStyle(fontSize: isSmallScreen ? 16 : 18, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                      ],
                    ),
                    Text(
                      'Group Chat',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          const ThemeToggleButton(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesList(),
          ),
          ModernChatInput(
            onSend: (text) {
              _messageController.text = text;
              _sendMessage();
            },
            onAttachmentSelected: (file) {
              // TODO: Implement group attachment handling
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Attachments not yet supported in group chats')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMessages,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the group conversation!',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final previous = index > 0 ? _messages[index - 1] : null;
        bool showDateSeparator = false;
        final currTs = message.timestamp;
        if (previous == null) {
          showDateSeparator = true;
        } else if (currTs != null && previous.timestamp != null) {
          final prev = previous.timestamp!;
          final curr = currTs;
          final prevDate = DateTime(prev.year, prev.month, prev.day);
          final currDate = DateTime(curr.year, curr.month, curr.day);
          showDateSeparator = currDate.isAfter(prevDate);
        }
        return Column(
          children: [
            if (showDateSeparator) _buildDateSeparator(currTs),
            _buildMessageBubble(message),
          ],
        );
      },
    );
  }

    Widget _buildMessageBubble(GroupMessage message) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isMyMessage = message.senderId == authProvider.currentUser?.uuid;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 600 || screenWidth < 400;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
             margin: EdgeInsets.symmetric(
         vertical: isSmallScreen ? 4 : 6,
         horizontal: isSmallScreen ? 6 : 8,
       ),
      child: Row(
        mainAxisAlignment: isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMyMessage) ...[
                         Container(
               margin: const EdgeInsets.only(right: 6),
               child: CircleAvatar(
                radius: isSmallScreen ? 16 : 20,
                backgroundColor: Theme.of(context).colorScheme.secondary,
                child: Text(
                  message.senderName?.substring(0, 1).toUpperCase() ?? 'U',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondary,
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Column(
                crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMyMessage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 4),
                      child: Text(
                        message.senderName ?? 'Unknown User',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                  Container(
                                         padding: EdgeInsets.symmetric(
                       horizontal: isSmallScreen ? 14 : 16,
                       vertical: isSmallScreen ? 10 : 12,
                     ),
                                         decoration: BoxDecoration(
                       color: isMyMessage 
                           ? Theme.of(context).colorScheme.primary
                           // ignore: deprecated_member_use
                           : Theme.of(context).colorScheme.surfaceVariant,
                       borderRadius: BorderRadius.only(
                         topLeft: const Radius.circular(18),
                         topRight: const Radius.circular(18),
                         bottomLeft: Radius.circular(isMyMessage ? 4 : 18),
                         bottomRight: Radius.circular(isMyMessage ? 18 : 4),
                       ),
                       boxShadow: [
                         BoxShadow(
                           color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
                           blurRadius: 4,
                           offset: const Offset(0, 1),
                         ),
                       ],
                     ),
                    child: Column(
                      crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.content ?? '',
                          style: TextStyle(
                            color: isMyMessage
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: isSmallScreen ? 15 : 16,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 4 : 6),
                        Text(
                          _formatAmPm(message.timestamp),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 11,
                            color: isMyMessage
                                ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMyMessage) ...[
                         Container(
               margin: const EdgeInsets.only(left: 6),
               child: CircleAvatar(
                radius: isSmallScreen ? 16 : 20,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  authProvider.currentUser?.name?.substring(0, 1).toUpperCase() ?? 'U',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Deprecated: replaced by ModernChatInput

  String _formatAmPm(DateTime? timestamp) {
    if (timestamp == null) return '';
    final hour = timestamp.hour;
    final minute = timestamp.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = (hour % 12 == 0) ? 12 : (hour % 12);
    final mm = minute.toString().padLeft(2, '0');
    return '$displayHour:$mm $period';
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
      label = '${_monthName(messageDate.month)} ${messageDate.day}, ${messageDate.year}';
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

  String _monthName(int m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[(m - 1).clamp(0, 11)];
  }

  // _showGroupInfo removed (unused)
} 