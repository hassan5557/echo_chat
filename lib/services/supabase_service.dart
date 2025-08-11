import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'dart:io';
import 'dart:typed_data';
import '../models/user.dart' as app_user;
import '../models/message.dart';
import '../models/group.dart';
import '../models/group_message.dart';
import '../utils/config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    await Supabase.initialize(
      url: Config.supabaseUrl,
      anonKey: Config.supabaseAnonKey,
    );
    _initialized = true;
  }

  SupabaseClient get client => Supabase.instance.client;
  dynamic get currentUser => client.auth.currentUser;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    await initialize();
    
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      
      print('SignUp response: ${response.session}');
      print('User: ${response.user}');
      
      if (response.session != null) {
        await _createUserProfile(response.user!);
      }
      
      return response;
    } catch (e) {
      print('SignUp error: $e');
      rethrow;
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    await initialize();
    
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      print('SignIn response: ${response.user?.emailConfirmedAt}');
      
      if (response.user!.emailConfirmedAt != null) {
        // User is confirmed, ensure their profile exists in public.users
        await ensureUserProfileExists(response.user!.id);
      }
      
      return response;
    } catch (e) {
      print('SignIn error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await initialize();
    await client.auth.signOut();
  }

  Future<void> _createUserProfile(dynamic user) async {
    try {
      await client.from('users').insert({
        'id': user.id,
        'email': user.email,
        'name': user.userMetadata?['name'] ?? 'User',
        'avatar_url': null,
        'last_active': DateTime.now().toIso8601String(),
      });
      print('User profile created successfully');
    } catch (e) {
      print('Failed to create user profile: $e');
      // Don't rethrow - profile creation failure shouldn't break signup
    }
  }

  Future<app_user.User?> getUserById(String userId) async {
    await initialize();
    
    try {
      final response = await client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      
      return app_user.User.fromJson(response);
    } catch (e) {
      print('getUserById error: $e');
      
      // If user profile doesn't exist, try to create it
      if (e.toString().contains('0 rows') || e.toString().contains('not found')) {
        try {
          print('User profile not found for $userId, attempting to create...');
          await ensureUserProfileExists(userId);
          
          // Retry fetching the user after creating profile
          final retryResponse = await client
              .from('users')
              .select()
              .eq('id', userId)
              .single();
          return app_user.User.fromJson(retryResponse);
        } catch (retryError) {
          print('Failed to create or fetch user profile: $retryError');
          return null;
        }
      }
      
      return null;
    }
  }

  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? avatarUrl,
  }) async {
    await initialize();
    
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    updates['last_active'] = DateTime.now().toIso8601String();

    print('Updating user profile for user $userId with updates: $updates');

    await client
        .from('users')
        .update(updates)
        .eq('id', userId);
    
    print('User profile update completed');
  }

  Future<void> uploadProfilePhoto({
    required String userId,
    required File imageFile,
  }) async {
    await initialize();
    
    try {
      print('=== Starting profile photo upload ===');
      print('User ID: $userId');
      print('File path: ${imageFile.path}');
      print('File size: ${await imageFile.length()} bytes');
      
      // Upload image to Supabase Storage
      // Use path format that matches common RLS policies: avatars/<userId>/profile.jpg
      final fileName = 'profile.jpg';
      final preferredBucket = 'avatars';
      final preferredPath = '$userId/$fileName';
      
      print('Preferred object path: $preferredPath');
      
      // Try preferred bucket first, then fall back to a few common names
      String? imageUrl;
      List<String> bucketNames = [preferredBucket, 'images', 'public', 'storage'];
      
      for (String bucketName in bucketNames) {
        try {
          print('Attempting to upload to bucket: $bucketName');
          
          // Try uploading directly; if the bucket doesn't exist or policy blocks,
          // this will throw and we'll try the next candidate.
          
          // Choose the correct object path for this bucket
          final objectPath = bucketName == preferredBucket
              ? preferredPath
              : 'profile_photos/profile_$userId.jpg';

          // Upload the file (upsert to overwrite existing)
          await client.storage
              .from(bucketName)
              .upload(
                objectPath,
                imageFile,
                fileOptions: const FileOptions(upsert: true),
              );
          
          print('File uploaded successfully to bucket: $bucketName');
          
          // Get the public URL and add cache-busting query to force UI refresh
          final baseUrl = client.storage
              .from(bucketName)
              .getPublicUrl(objectPath);
          final cacheBuster = DateTime.now().millisecondsSinceEpoch;
          imageUrl = '$baseUrl?v=$cacheBuster';
          
          print('Successfully uploaded to bucket: $bucketName');
          print('Generated image URL: $imageUrl');
          break;
        } catch (bucketError) {
          print('Failed to upload to bucket $bucketName: $bucketError');
          print('Error type: ${bucketError.runtimeType}');
          print('Error details: $bucketError');
          
          if (bucketName == bucketNames.last) {
            // If all buckets fail, throw the error
            throw Exception('No available storage bucket found. Please create a storage bucket in your Supabase project.');
          }
        }
      }
      
      if (imageUrl != null) {
        print('About to update user profile with avatar URL: $imageUrl');
        // Update user profile with the new avatar URL
        await updateUserProfile(
          userId: userId,
          avatarUrl: imageUrl,
        );
        print('User profile updated successfully with avatar URL');
      } else {
        print('No image URL generated, cannot update profile');
      }
    } catch (e) {
      print('Error uploading profile photo: $e');
      print('Error stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<List<app_user.User>> searchUsersByEmail(String email) async {
    await initialize();
    
    print('Searching for users with email containing: $email');
    
    final response = await client
        .from('users')
        .select()
        .ilike('email', '%$email%')
        .limit(10);

    print('Search response: $response');
    print('Found ${response.length} users');

    final users = response.map((user) => app_user.User.fromJson(user)).toList();
    
    // Filter out the current user from search results
    final currentUserId = client.auth.currentUser?.id;
    final filteredUsers = users.where((user) => user.uuid != currentUserId).toList();
    
    print('Filtered users (excluding current user): ${filteredUsers.length}');
    
    return filteredUsers;
  }

  Future<void> addContact(String userId, String contactId) async {
    await initialize();
    
    try {
      print('Adding contact: $userId -> $contactId');
      
      // Check if contact already exists
      final existingContact = await client
          .from('contacts')
          .select()
          .eq('user_id', userId)
          .eq('contact_id', contactId)
          .maybeSingle();
      
      if (existingContact != null) {
        print('Contact already exists, skipping...');
        return;
      }
      
      await client.from('contacts').insert({
        'user_id': userId,
        'contact_id': contactId,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      print('✅ Contact added successfully');
    } catch (e) {
      print('❌ Error adding contact: $e');
      if (e.toString().contains('row-level security policy')) {
        throw Exception('RLS policy error: Please ensure you are authenticated and the RLS policies are correctly configured.');
      }
      rethrow;
    }
  }

  Future<void> deleteContact(String userId, String contactId) async {
    await initialize();
    
    await client
        .from('contacts')
        .delete()
        .eq('user_id', userId)
        .eq('contact_id', contactId);
  }

  Future<void> deleteMessages(String userId1, String userId2) async {
    await initialize();
    
    final chatId = _generateChatId(userId1, userId2);
    
    await client
        .from('messages')
        .delete()
        .eq('chat_id', chatId);
  }

  Future<List<app_user.User>> getContacts(String userId) async {
    await initialize();
    
    final response = await client
        .from('contacts')
        .select('contact_id, created_at')
        .eq('user_id', userId);

    if (response.isEmpty) return [];

    final contactIds = response.map((contact) => contact['contact_id']).toList();
    
    final usersResponse = await client
        .from('users')
        .select()
        .inFilter('id', contactIds);

    final users = usersResponse.map((user) => app_user.User.fromJson(user)).toList();
    
    // Filter out the current user from contacts
    final filteredUsers = users.where((user) => user.uuid != userId).toList();
    
    // Add creation date to each user
    for (int i = 0; i < filteredUsers.length; i++) {
      final contactData = response.firstWhere(
        (contact) => contact['contact_id'] == filteredUsers[i].uuid,
        orElse: () => {'created_at': null},
      );
      filteredUsers[i].contactCreatedAt = contactData['created_at'] != null 
          ? DateTime.parse(contactData['created_at'])
          : null;
    }

    return filteredUsers;
  }

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    await initialize();
    
    final chatId = _generateChatId(senderId, receiverId);
    
    await client.from('messages').insert({
      'chat_id': chatId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
      'is_read': false,
      'status': 'sent',
      'type': 'text',
    });
  }

  Future<void> sendMessageWithAttachment({
    required String senderId,
    required String receiverId,
    required String content,
    required File file,
    required MessageType type,
  }) async {
    await initialize();
    
    try {
      // Upload file to Supabase Storage - use only avatars bucket
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final filePath = 'chat_attachments/$senderId/$fileName';
      
      final fileBytes = await file.readAsBytes();
      final fileSize = fileBytes.length;
      
      print('=== Starting file upload ===');
      print('File size: $fileSize bytes');
      print('File path: $filePath');
      print('Target bucket: avatars');
      
      // Use only the avatars bucket
      const bucketName = 'avatars';
      
      try {
        // Check if bucket exists first
        final buckets = await client.storage.listBuckets();
        final bucketExists = buckets.any((bucket) => bucket.name == bucketName);
        
        if (!bucketExists) {
          throw Exception('Storage bucket "avatars" does not exist. Please create it in your Supabase Dashboard → Storage.');
        }
        
        print('Bucket $bucketName exists, proceeding with upload...');
        
        // Upload the file
        await client.storage.from(bucketName).uploadBinary(
          filePath,
          fileBytes,
          fileOptions: const FileOptions(
            contentType: 'application/octet-stream',
            upsert: true,
          ),
        );
        
        // Get public URL
        final publicUrl = client.storage.from(bucketName).getPublicUrl(filePath);
        print('✅ Successfully uploaded to bucket: $bucketName');
        print('Public URL: $publicUrl');
        
        // Determine MIME type
        String mimeType = 'application/octet-stream';
        if (type == MessageType.image) {
          mimeType = 'image/jpeg';
        } else if (type == MessageType.video) {
          mimeType = 'video/mp4';
        }
        
        final chatId = _generateChatId(senderId, receiverId);
        
        print('Inserting message with attachment to database...');
        await client.from('messages').insert({
          'chat_id': chatId,
          'sender_id': senderId,
          'receiver_id': receiverId,
          'content': content,
          'timestamp': DateTime.now().toIso8601String(),
          'is_read': false,
          'status': 'sent',
          'type': type.name,
          'attachment_url': publicUrl,
          'attachment_name': file.path.split('/').last,
          'attachment_size': fileSize.toString(),
          'attachment_type': mimeType,
        });
        
        print('✅ Message with attachment saved successfully');
        
      } catch (uploadError) {
        print('❌ Upload error: $uploadError');
        if (uploadError.toString().contains('Bucket not found')) {
          throw Exception('Storage bucket "avatars" not found. Please create it in Supabase Dashboard → Storage → Create bucket named "avatars" and make it public.');
        } else if (uploadError.toString().contains('row-level security policy')) {
          throw Exception('Storage RLS policy error. Please run the SQL script to fix storage policies.');
        } else {
          throw Exception('Upload failed: $uploadError');
        }
      }
      
    } catch (e) {
      print('❌ Error uploading file: $e');
      rethrow;
    }
  }

  Future<List<Message>> getMessages(String userId1, String userId2) async {
    await initialize();
    
    final chatId = _generateChatId(userId1, userId2);
    
    final response = await client
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .order('timestamp', ascending: true);

    return response.map((message) => Message.fromJson(message)).toList();
  }

  Future<List<Message>> getAllMessagesForUser(String userId) async {
    await initialize();
    
    final response = await client
        .from('messages')
        .select()
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('timestamp', ascending: true);

    return response.map((message) => Message.fromJson(message)).toList();
  }

  Future<void> markMessagesAsRead(String currentUserId, String otherUserId) async {
    await initialize();
    
    final chatId = _generateChatId(currentUserId, otherUserId);
    
    await client
        .from('messages')
        .update({
          'is_read': true,
          'status': 'read',
        })
        .eq('chat_id', chatId)
        .eq('sender_id', otherUserId)
        .eq('receiver_id', currentUserId);
  }

  Future<void> updateMessageStatus(String messageId, String status) async {
    await initialize();
    
    await client
        .from('messages')
        .update({'status': status})
        .eq('id', messageId);
  }

  Future<void> createGroup({
    required String name,
    required String creatorId,
  }) async {
    await initialize();
    
    await client.from('groups').insert({
      'name': name,
      'creator_id': creatorId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<String?> createGroupAndGetId({
    required String name,
    required String creatorId,
  }) async {
    await initialize();
    
    final response = await client.from('groups').insert({
      'name': name,
      'creator_id': creatorId,
      'created_at': DateTime.now().toIso8601String(),
    }).select('id').single();
    
    return response['id'] as String?;
  }

  Future<List<Group>> getUserGroups(String userId) async {
    await initialize();
    
    final response = await client
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId);

    if (response.isEmpty) return [];

    final groupIds = response.map((member) => member['group_id']).toList();
    
    final groupsResponse = await client
        .from('groups')
        .select()
        .inFilter('id', groupIds);

    return groupsResponse.map((group) => Group.fromJson(group)).toList();
  }

  Future<void> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String content,
  }) async {
    await initialize();
    
    await client.from('group_messages').insert({
      'group_id': groupId,
      'sender_id': senderId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
      'is_read': false,
    });
  }

  Future<List<GroupMessage>> getGroupMessages(String groupId) async {
    await initialize();
    
    final response = await client
        .from('group_messages')
        .select('*, users!group_messages_sender_id_fkey(name)')
        .eq('group_id', groupId)
        .order('timestamp', ascending: true);

    return response.map((message) {
      final messageData = Map<String, dynamic>.from(message);
      // Extract sender name from the joined users table
      final userData = message['users'] as Map<String, dynamic>?;
      messageData['sender_name'] = userData?['name'] as String?;
      return GroupMessage.fromJson(messageData);
    }).toList();
  }

  Future<void> addGroupMember({
    required String groupId,
    required String userId,
  }) async {
    await initialize();
    
    await client.from('group_members').insert({
      'group_id': groupId,
      'user_id': userId,
      'joined_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<app_user.User>> getGroupMembers(String groupId) async {
    await initialize();
    
    final response = await client
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId);

    if (response.isEmpty) return [];

    final memberIds = response.map((member) => member['user_id']).toList();
    
    final usersResponse = await client
        .from('users')
        .select()
        .inFilter('id', memberIds);

    return usersResponse.map((user) => app_user.User.fromJson(user)).toList();
  }

  Future<void> removeGroupMember({
    required String groupId,
    required String userId,
  }) async {
    await initialize();
    
    await client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<void> updateGroupName(String groupId, String newName) async {
    await initialize();
    
    await client
        .from('groups')
        .update({'name': newName})
        .eq('id', groupId);
  }

  Future<void> deleteGroup(String groupId) async {
    await initialize();
    
    // First delete all group messages
    await client
        .from('group_messages')
        .delete()
        .eq('group_id', groupId);
    
    // Then delete all group members
    await client
        .from('group_members')
        .delete()
        .eq('group_id', groupId);
    
    // Finally delete the group itself
    await client
        .from('groups')
        .delete()
        .eq('id', groupId);
  }

  void subscribeToMessages(String userId, Function(Map<String, dynamic>) onMessage) {
    client
        .channel('messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final senderId = newRecord['sender_id'];
            final receiverId = newRecord['receiver_id'];
            
            if (senderId == userId || receiverId == userId) {
              onMessage(newRecord);
            }
                    },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final updatedRecord = payload.newRecord;
            final senderId = updatedRecord['sender_id'];
            final receiverId = updatedRecord['receiver_id'];
            
            if (senderId == userId || receiverId == userId) {
              onMessage(updatedRecord);
            }
                    },
        )
        .subscribe();
  }

  // Subscribe to status updates for messages sent by the current user
  void subscribeToMessageStatusUpdates(String userId, Function(Map<String, dynamic>) onStatusUpdate) {
    client
        .channel('message_status')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final updatedRecord = payload.newRecord;
            final senderId = updatedRecord['sender_id'];
            final receiverId = updatedRecord['receiver_id'];
            final status = updatedRecord['status'];
            
            // Only notify if the current user is the sender and the message was read
            if (senderId == userId && status == 'read') {
              onStatusUpdate(updatedRecord);
            }
                    },
        )
        .subscribe();
  }

  void subscribeToGroupMessages(String userId, Function(Map<String, dynamic>) onMessage) {
    client
        .channel('group_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'group_messages',
          callback: (payload) {
            final newRecord = payload.newRecord;
            onMessage(newRecord);
                    },
        )
        .subscribe();
  }

  String _generateChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  Future<void> createTestUsers() async {
    await initialize();
    
    final testUsers = [
      {
        'id': 'test-user-1',
        'email': 'john@example.com',
        'name': 'John Doe',
        'avatar_url': null,
        'last_active': DateTime.now().toIso8601String(),
      },
      {
        'id': 'test-user-2',
        'email': 'jane@example.com',
        'name': 'Jane Smith',
        'avatar_url': null,
        'last_active': DateTime.now().toIso8601String(),
      },
      {
        'id': 'test-user-3',
        'email': 'bob@example.com',
        'name': 'Bob Johnson',
        'avatar_url': null,
        'last_active': DateTime.now().toIso8601String(),
      },
    ];

    try {
      for (final user in testUsers) {
        await client.from('users').upsert(user, onConflict: 'id');
        print('Created test user: ${user['email']}');
      }
      print('Test users created successfully');
    } catch (e) {
      print('Error creating test users: $e');
    }
  }

  Future<List<app_user.User>> getAllUsers() async {
    await initialize();
    
    try {
      final response = await client
          .from('users')
          .select()
          .order('name');

      print('All users in database: ${response.length}');
      for (final user in response) {
        print('- ${user['name']} (${user['email']})');
      }

      return response.map((user) => app_user.User.fromJson(user)).toList();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  Future<void> ensureUserProfileExists(String userId) async {
    await initialize();
    
    try {
      // Check if user profile exists
      final response = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (response == null) {
        // User profile doesn't exist, create it
        print('User profile not found for $userId, creating...');
        
        // Try to get user info from current session or create basic profile
        final currentUser = client.auth.currentUser;
        if (currentUser != null && currentUser.id == userId) {
          await client.from('users').insert({
            'id': currentUser.id,
            'email': currentUser.email,
            'name': currentUser.userMetadata?['name'] ?? 'User',
            'avatar_url': null,
            'last_active': DateTime.now().toIso8601String(),
          });
          print('User profile created successfully for $userId');
        } else {
          // Fallback: create a basic profile
          await client.from('users').insert({
            'id': userId,
            'email': 'user@example.com', // Placeholder
            'name': 'User',
            'avatar_url': null,
            'last_active': DateTime.now().toIso8601String(),
          });
          print('Basic user profile created for $userId');
        }
      } else {
        print('User profile already exists for $userId');
      }
    } catch (e) {
      print('Error ensuring user profile exists: $e');
      // Try to create a basic profile as fallback
      try {
        await client.from('users').upsert({
          'id': userId,
          'email': 'user@example.com',
          'name': 'User',
          'avatar_url': null,
          'last_active': DateTime.now().toIso8601String(),
        }, onConflict: 'id');
        print('Fallback user profile created for $userId');
      } catch (fallbackError) {
        print('Failed to create fallback profile: $fallbackError');
      }
    }
  }

  Future<void> syncAllAuthUsers() async {
    await initialize();
    
    try {
      print('Syncing all auth users to public.users table...');
      
      // Call the database function to sync all auth users
      await client.rpc('sync_all_auth_users');
      
      print('User sync completed');
    } catch (e) {
      print('Error syncing users: $e');
      // Fallback: manually create profiles for known users
      await _createMissingUserProfiles();
    }
  }

  Future<void> _createMissingUserProfiles() async {
    await initialize();
    
    try {
      // Get current user and ensure their profile exists
      final currentUser = client.auth.currentUser;
      if (currentUser != null) {
        await ensureUserProfileExists(currentUser.id);
      }
      
      // You can add more known user IDs here if needed
      final knownUserIds = [
        // Add any known user IDs here
      ];
      
      for (final userId in knownUserIds) {
        await ensureUserProfileExists(userId);
      }
      
      print('Missing user profiles created');
    } catch (e) {
      print('Error creating missing user profiles: $e');
    }
  }

  Future<bool> isUserInSupabase(String userId) async {
    await initialize();
    
    try {
      final response = await client
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      print('Error checking if user exists in Supabase: $e');
      return false;
    }
  }

  Future<bool> addUserToSupabase(app_user.User user) async {
    await initialize();
    
    try {
      await client.from('users').upsert({
        'id': user.uuid,
        'email': user.email,
        'name': user.name,
        'avatar_url': user.avatarUrl,
        'last_active': user.lastActive?.toIso8601String() ?? DateTime.now().toIso8601String(),
      }, onConflict: 'id');
      
      return true;
    } catch (e) {
      print('Error adding user to Supabase: $e');
      return false;
    }
  }

  // testStorageBuckets intentionally removed
} 