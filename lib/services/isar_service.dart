import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user.dart';
import '../models/contact.dart';
import '../models/message.dart';
import '../models/group.dart';
import '../models/group_member.dart';
import '../models/group_message.dart';

class IsarService {
  late Isar _isar;

  Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [UserSchema, ContactSchema, MessageSchema, GroupSchema, GroupMemberSchema, GroupMessageSchema],
      directory: dir.path,
    );
  }

  // User operations
  Future<void> saveUser(User user) async {
    await _isar.writeTxn(() async {
      await _isar.users.put(user);
    });
  }

  Future<User?> getUserById(String uuid) async {
    return await _isar.users.filter().uuidEqualTo(uuid).findFirst();
  }

  Future<List<User>> getAllUsers() async {
    return await _isar.users.where().findAll();
  }

  Future<void> deleteUser(String uuid) async {
    await _isar.writeTxn(() async {
      await _isar.users.filter().uuidEqualTo(uuid).deleteAll();
    });
  }

  // Contact operations
  Future<void> saveContact(Contact contact) async {
    await _isar.writeTxn(() async {
      await _isar.contacts.put(contact);
    });
  }

  Future<List<Contact>> getContactsByUserId(String userId) async {
    return await _isar.contacts.filter().userIdEqualTo(userId).findAll();
  }

  Future<void> deleteContact(String userId, String contactId) async {
    await _isar.writeTxn(() async {
      await _isar.contacts
          .filter()
          .userIdEqualTo(userId)
          .and()
          .contactIdEqualTo(contactId)
          .deleteAll();
    });
  }

  // Message operations
  Future<void> saveMessage(Message message) async {
    await _isar.writeTxn(() async {
      await _isar.messages.put(message);
    });
  }

  Future<List<Message>> getMessagesByChatId(String chatId) async {
    return await _isar.messages
        .filter()
        .chatIdEqualTo(chatId)
        .sortByTimestamp()
        .findAll();
  }

  Future<List<Message>> getMessagesByUserId(String userId) async {
    return await _isar.messages
        .filter()
        .senderIdEqualTo(userId)
        .or()
        .receiverIdEqualTo(userId)
        .sortByTimestamp()
        .findAll();
  }

  Future<void> markMessageAsRead(String messageId) async {
    await _isar.writeTxn(() async {
      final message = await _isar.messages.filter().uuidEqualTo(messageId).findFirst();
      if (message != null) {
        message.isRead = true;
        await _isar.messages.put(message);
      }
    });
  }

  Future<void> deleteMessage(String messageId) async {
    await _isar.writeTxn(() async {
      await _isar.messages.filter().uuidEqualTo(messageId).deleteAll();
    });
  }

  // Group operations
  Future<void> saveGroup(Group group) async {
    await _isar.writeTxn(() async {
      await _isar.groups.put(group);
    });
  }

  Future<Group?> getGroupById(String uuid) async {
    return await _isar.groups.filter().uuidEqualTo(uuid).findFirst();
  }

  Future<List<Group>> getAllGroups() async {
    return await _isar.groups.where().findAll();
  }

  Future<void> deleteGroup(String uuid) async {
    await _isar.writeTxn(() async {
      await _isar.groups.filter().uuidEqualTo(uuid).deleteAll();
    });
  }

  // Group member operations
  Future<void> saveGroupMember(GroupMember member) async {
    await _isar.writeTxn(() async {
      await _isar.groupMembers.put(member);
    });
  }

  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    return await _isar.groupMembers.filter().groupIdEqualTo(groupId).findAll();
  }

  Future<List<GroupMember>> getUserGroups(String userId) async {
    return await _isar.groupMembers.filter().userIdEqualTo(userId).findAll();
  }

  Future<void> removeGroupMember(String groupId, String userId) async {
    await _isar.writeTxn(() async {
      await _isar.groupMembers
          .filter()
          .groupIdEqualTo(groupId)
          .and()
          .userIdEqualTo(userId)
          .deleteAll();
    });
  }

  // Group message operations
  Future<void> saveGroupMessage(GroupMessage message) async {
    await _isar.writeTxn(() async {
      await _isar.groupMessages.put(message);
    });
  }

  Future<List<GroupMessage>> getGroupMessages(String groupId) async {
    return await _isar.groupMessages
        .filter()
        .groupIdEqualTo(groupId)
        .sortByTimestamp()
        .findAll();
  }

  Future<void> markGroupMessageAsRead(String messageId) async {
    await _isar.writeTxn(() async {
      final message = await _isar.groupMessages.filter().uuidEqualTo(messageId).findFirst();
      if (message != null) {
        message.isRead = true;
        await _isar.groupMessages.put(message);
      }
    });
  }

  Future<void> deleteGroupMessage(String messageId) async {
    await _isar.writeTxn(() async {
      await _isar.groupMessages.filter().uuidEqualTo(messageId).deleteAll();
    });
  }

  // Sync operations
  Future<void> syncUsers(List<User> users) async {
    await _isar.writeTxn(() async {
      for (final user in users) {
        await _isar.users.put(user);
      }
    });
  }

  Future<void> syncMessages(List<Message> messages) async {
    await _isar.writeTxn(() async {
      for (final message in messages) {
        await _isar.messages.put(message);
      }
    });
  }

  Future<void> syncGroups(List<Group> groups) async {
    await _isar.writeTxn(() async {
      for (final group in groups) {
        await _isar.groups.put(group);
      }
    });
  }

  Future<void> syncGroupMessages(List<GroupMessage> messages) async {
    await _isar.writeTxn(() async {
      for (final message in messages) {
        await _isar.groupMessages.put(message);
      }
    });
  }

  // Cleanup
  Future<void> close() async {
    await _isar.close();
  }
} 