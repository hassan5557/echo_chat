import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../providers/contact_provider.dart';
import '../models/group.dart';
import '../models/user.dart' as app_user;
import 'group_chat_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroups();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroupsIfNeeded();
    });
  }

  Future<void> _loadGroups() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    
    if (authProvider.currentUser?.uuid != null) {
      await groupProvider.loadGroups(authProvider.currentUser!.uuid!);
    }
  }

  Future<void> _loadGroupsIfNeeded() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    
    if (authProvider.currentUser?.uuid != null && 
        !groupProvider.isLoaded && 
        !groupProvider.isLoading) {
      await groupProvider.loadGroups(authProvider.currentUser!.uuid!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 600 || screenWidth < 400;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateGroupDialog(context),
          ),
        ],
      ),
      body: Consumer2<GroupProvider, AuthProvider>(
        builder: (context, groupProvider, authProvider, child) {
          if (groupProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (groupProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    groupProvider.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadGroups,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final groups = groupProvider.groups;

          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: isSmallScreen ? 64 : 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 20),
                  Text(
                    'No groups yet',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  Text(
                    'Create a group to start chatting with multiple people',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 24 : 32),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateGroupDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Group'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 20 : 24,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return _buildGroupTile(group, isSmallScreen);
            },
          );
        },
      ),
    );
  }

  Widget _buildGroupTile(Group group, bool isSmallScreen) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 4 : 8,
      ),
      leading: CircleAvatar(
        radius: isSmallScreen ? 24 : 28,
        backgroundColor: Colors.green,
        child: Text(
          group.name?.substring(0, 1).toUpperCase() ?? 'G',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 16 : 18,
          ),
        ),
      ),
      title: Text(
        group.name ?? 'Unknown Group',
        style: TextStyle(
          fontSize: isSmallScreen ? 16 : 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        'Created ${_formatTime(group.createdAt)}',
        style: TextStyle(
          fontSize: isSmallScreen ? 12 : 14,
          color: Colors.grey[600],
        ),
      ),
             onTap: () {
         Navigator.push(
           context,
           MaterialPageRoute(
             builder: (context) => GroupChatScreen(group: group),
           ),
         );
       },
    );
  }

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (messageDate == today) {
      return 'today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'yesterday';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _showCreateGroupDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final List<app_user.User> selectedContacts = [];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create New Group'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Group Name',
                        hintText: 'Enter group name...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select members:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Consumer<ContactProvider>(
                      builder: (context, contactProvider, child) {
                        if (contactProvider.contacts.isEmpty) {
                          return const Text(
                            'No contacts available. Add some contacts first.',
                            style: TextStyle(color: Colors.grey),
                          );
                        }

                        return SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: contactProvider.contacts.length,
                            itemBuilder: (context, index) {
                              final contact = contactProvider.contacts[index];
                              final isSelected = selectedContacts.contains(contact);
                              
                              return CheckboxListTile(
                                title: Text(contact.name ?? 'Unknown'),
                                subtitle: Text(contact.email ?? ''),
                                value: isSelected,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedContacts.add(contact);
                                    } else {
                                      selectedContacts.remove(contact);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: nameController.text.trim().isEmpty || selectedContacts.isEmpty
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          await _createGroup(
                            name: nameController.text.trim(),
                            memberIds: selectedContacts.map((c) => c.uuid!).toList(),
                          );
                        },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);

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
            Text('Creating group "$name"...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    final success = await groupProvider.createGroup(
      name: name,
      creatorId: authProvider.currentUser!.uuid!,
      memberIds: memberIds,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Group "$name" created successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(groupProvider.error ?? 'Failed to create group'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
} 