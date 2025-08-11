import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/user.dart' as app_user;

class ContactProvider extends ChangeNotifier {
  static final ContactProvider _instance = ContactProvider._internal();
  factory ContactProvider() => _instance;
  ContactProvider._internal();

  final SupabaseService _supabaseService = SupabaseService();
  
  List<app_user.User> _contacts = [];
  List<app_user.User> _searchResults = [];
  final Map<String, Map<String, String>> _displayNameOverrides = {};
  bool _isLoading = false;
  bool _isLoaded = false; // Add flag to track if contacts are loaded
  String? _error;

  List<app_user.User> get contacts => _contacts;
  List<app_user.User> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded; // Add getter for the flag
  String? get error => _error;

  Future<void> loadContacts(String userId) async {
    // Prevent unnecessary reloads if already loaded and not forced
    if (_isLoaded && !_isLoading) {
      return;
    }
    
    _isLoading = true;
    _error = null;
    
    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      _contacts = await _supabaseService.getContacts(userId);
      _applyDisplayNameOverrides(userId);
      _isLoading = false;
      _isLoaded = true; // Mark as loaded
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load contacts: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchUsers(String email) async {
    if (email.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    
    print('ContactProvider: Searching for users with email: $email');
    
    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      _searchResults = await _supabaseService.searchUsersByEmail(email);
      print('ContactProvider: Found ${_searchResults.length} users');
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('ContactProvider: Search error: $e');
      _error = 'Failed to search users: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addContact(String userId, String contactId) async {
    try {
      await _supabaseService.addContact(userId, contactId);
      // Force reload contacts after adding
      await forceReloadContacts(userId);
      return true;
    } catch (e) {
      // Check if it's a duplicate key error - don't set error for these
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('duplicate key value') || 
          errorString.contains('dublicate key value') ||
          errorString.contains('23505') ||
          errorString.contains('contact_user_id_contact_id_key') ||
          errorString.contains('unique constraint') ||
          errorString.contains('violates unique constraint')) {
        // Don't set error for duplicate key violations
        return false;
      } else {
        _error = 'Failed to add contact: $e';
        notifyListeners();
        return false;
      }
    }
  }

  Future<bool> deleteContact(String userId, String contactId) async {
    try {
      await _supabaseService.deleteContact(userId, contactId);
      // Force reload contacts after deleting
      await forceReloadContacts(userId);
      return true;
    } catch (e) {
      _error = 'Failed to delete contact: $e';
      notifyListeners();
      return false;
    }
  }

  // Add method to force reload
  Future<void> forceReloadContacts(String userId) async {
    _isLoaded = false; // Reset the flag to force reload
    await loadContacts(userId);
  }

  // Local display name overrides per currentUserId -> contactId -> name
  Future<void> setLocalDisplayName({
    required String currentUserId,
    required String contactId,
    required String displayName,
  }) async {
    _displayNameOverrides.putIfAbsent(currentUserId, () => {});
    _displayNameOverrides[currentUserId]![contactId] = displayName;
    _applyDisplayNameOverrides(currentUserId);
    notifyListeners();
  }

  String displayNameFor({
    required String currentUserId,
    required app_user.User contact,
  }) {
    final override = _displayNameOverrides[currentUserId]?[contact.uuid];
    return override?.isNotEmpty == true ? override! : (contact.name ?? 'Unknown User');
  }

  void _applyDisplayNameOverrides(String currentUserId) {
    final overrides = _displayNameOverrides[currentUserId] ?? {};
    _contacts = _contacts.map((u) {
      final override = overrides[u.uuid];
      return override == null || override.isEmpty ? u : u.copyWith(name: override);
    }).toList();
    _searchResults = _searchResults.map((u) {
      final override = overrides[u.uuid];
      return override == null || override.isEmpty ? u : u.copyWith(name: override);
    }).toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  void clearContacts() {
    _contacts = [];
    _isLoaded = false; // Reset the loaded flag
    notifyListeners();
  }
} 