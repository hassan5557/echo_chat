import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/group.dart';


class GroupProvider extends ChangeNotifier {
  static final GroupProvider _instance = GroupProvider._internal();
  factory GroupProvider() => _instance;
  GroupProvider._internal();

  final SupabaseService _supabaseService = SupabaseService();
  
  List<Group> _groups = [];
  bool _isLoading = false;
  bool _isLoaded = false;
  String? _error;

  List<Group> get groups => _groups;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get error => _error;

  Future<void> loadGroups(String userId) async {
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
      _groups = await _supabaseService.getUserGroups(userId);
      _isLoading = false;
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load groups: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createGroup({
    required String name,
    required String creatorId,
    required List<String> memberIds,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Create the group and get the created group ID
      final createdGroupId = await _supabaseService.createGroupAndGetId(
        name: name,
        creatorId: creatorId,
      );

      if (createdGroupId == null) {
        throw Exception('Failed to create group - no group ID returned');
      }

      // Add members to the group
      for (final memberId in memberIds) {
        await _supabaseService.addGroupMember(
          groupId: createdGroupId,
          userId: memberId,
        );
      }

      // Add creator as member
      await _supabaseService.addGroupMember(
        groupId: createdGroupId,
        userId: creatorId,
      );

      // Force reload groups
      await forceReloadGroups(creatorId);
      
      return true;
    } catch (e) {
      _error = 'Failed to create group: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> forceReloadGroups(String userId) async {
    _isLoaded = false;
    await loadGroups(userId);
  }

  void clearGroups() {
    _groups = [];
    _isLoaded = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
} 