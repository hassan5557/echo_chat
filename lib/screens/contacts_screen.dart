import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/contact_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/conversation_provider.dart';
import '../models/user.dart' as app_user;
// import '../services/supabase_service.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid calling methods during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContacts();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only load contacts if they haven't been loaded yet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContactsIfNeeded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    
    if (authProvider.currentUser?.uuid != null) {
      await contactProvider.loadContacts(authProvider.currentUser!.uuid!);
    }
  }

  Future<void> _loadContactsIfNeeded() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    
    // Only load if contacts are empty and not currently loading
    if (authProvider.currentUser?.uuid != null && 
        !contactProvider.isLoaded && 
        !contactProvider.isLoading) {
      await contactProvider.loadContacts(authProvider.currentUser!.uuid!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 600 || screenWidth < 400;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  Provider.of<ContactProvider>(context, listen: false).clearSearchResults();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearching) _buildSearchBar(isSmallScreen),
          Expanded(
            child: Consumer2<ContactProvider, AuthProvider>(
              builder: (context, contactProvider, authProvider, child) {
                if (contactProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (contactProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          contactProvider.error!,
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadContacts,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final contacts = _isSearching 
                    ? contactProvider.searchResults 
                    : contactProvider.contacts;

                if (contacts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isSearching ? Icons.search_off : Icons.people_outline,
                          size: isSmallScreen ? 48 : 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        Text(
                          _isSearching 
                              ? 'No users found'
                              : 'No contacts yet',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            color: Colors.grey,
                          ),
                        ),
                        if (!_isSearching) ...[
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Text(
                            'Search for users to add them as contacts',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return _buildContactTile(contact, authProvider, isSmallScreen);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by email...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16, 
                vertical: isSmallScreen ? 10 : 12
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                Provider.of<ContactProvider>(context, listen: false).searchUsers(value);
              } else {
                Provider.of<ContactProvider>(context, listen: false).clearSearchResults();
              }
            },
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          Text(
            'Search for users by their email address to add them as contacts',
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(app_user.User contact, AuthProvider authProvider, bool isSmallScreen) {
    final isSearchResult = _isSearching;
    final isCurrentUser = contact.uuid == authProvider.currentUser?.uuid;
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    final isAlreadyContact = !isSearchResult && contactProvider.contacts.any((c) => c.uuid == contact.uuid);
    final isNewContact = _isNewContact(contact);

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 4 : 8,
      ),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: isSmallScreen ? 20 : 24,
            backgroundColor: Colors.blue,
            child: Text(
              contact.name?.substring(0, 1).toUpperCase() ?? 'U',
              style: TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
          ),
          if (isNewContact && !isSearchResult)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: isSmallScreen ? 12 : 14,
                height: isSmallScreen ? 12 : 14,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 8 : 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              contact.name ?? 'Unknown User',
              style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            ),
          ),
          if (isNewContact && !isSearchResult)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 6 : 8,
                vertical: isSmallScreen ? 2 : 4,
              ),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
              ),
              child: Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 8 : 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contact.email ?? '',
            style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
          ),
         
        ],
      ),
      trailing: isSearchResult && !isCurrentUser
          ? ElevatedButton(
              onPressed: isAlreadyContact 
                  ? null 
                  : () => _addContact(contact),
              style: ElevatedButton.styleFrom(
                backgroundColor: isAlreadyContact ? Colors.grey : Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 6 : 8,
                ),
              ),
              child: Text(
                isAlreadyContact ? 'Added' : 'Add',
                style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
              ),
            )
          : null,
      onTap: isSearchResult && !isCurrentUser && !isAlreadyContact
          ? () => _addContact(contact)
          : isCurrentUser
              ? null
              : () => _openChat(contact),
      onLongPress: !isSearchResult && !isCurrentUser
          ? () => _showDeleteContactDialog(contact)
          : null,
    );
  }

  bool _isNewContact(app_user.User contact) {
    // Check if the contact was added within the last 24 hours
    if (contact.contactCreatedAt == null) return false;
    
    final now = DateTime.now();
    final contactAdded = contact.contactCreatedAt!;
    final difference = now.difference(contactAdded);
    
    // Show as "new" if added within the last 24 hours
    return difference.inHours < 24;
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

           if (success && mounted) {
             // Add conversation for the new contact
             final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
             await conversationProvider.addConversationForContact(contact);
             
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text('✅ ${contact.name} added to contacts!'),
                 backgroundColor: Colors.green,
                 duration: const Duration(seconds: 2),
               ),
             );
            
            // Clear search and go back to contacts list
            setState(() {
              _isSearching = false;
              _searchController.clear();
            });
            contactProvider.clearSearchResults();
                     } else if (mounted) {
             // Check if it's a duplicate key error
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
          if (mounted) {
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
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(contact: contact),
      ),
    );
  }

  void _showDeleteContactDialog(app_user.User contact) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Contact'),
          content: Text('Are you sure you want to delete ${contact.name} from your contacts? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteContact(contact);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteContact(app_user.User contact) async {
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
            Text('Deleting ${contact.name} from contacts...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    final success = await contactProvider.deleteContact(
      authProvider.currentUser!.uuid!,
      contact.uuid!,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${contact.name} removed from contacts'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(contactProvider.error ?? 'Failed to delete contact'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Debug dialog removed

  // Debug helper removed

  // Debug helper removed

  // Debug helper removed

  // Debug helper removed

  // Debug helper removed

  // Debug helper removed

  // Debug helper removed
} 