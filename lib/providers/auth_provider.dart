import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/user.dart' as app_user;

class AuthProvider extends ChangeNotifier {
  static final AuthProvider _instance = AuthProvider._internal();
  factory AuthProvider() => _instance;
  AuthProvider._internal();

  final SupabaseService _supabaseService = SupabaseService();
  
  app_user.User? _currentUser;
  bool _isLoading = false;
  String? _error;

  app_user.User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  Future<void> initialize() async {
    _isLoading = true;
    
    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      await _supabaseService.initialize();
      
      final user = _supabaseService.currentUser;
      if (user != null) {
        await _loadUserProfile(user.id);
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    _isLoading = true;
    _error = null;
    
    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        name: name,
      );

      if (response.session == null) {
        _error = 'Please check your email to confirm your account before logging in.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _loadUserProfile(response.user!.id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Sign up failed: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    
    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );

      if (response.user!.emailConfirmedAt == null) {
        _error = 'Please confirm your email before logging in.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await _loadUserProfile(response.user!.id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      String errorMessage = 'Sign in failed: $e';
      if (e.toString().contains('Invalid login credentials')) {
        errorMessage = 'Invalid email or password.';
      } else if (e.toString().contains('Email not confirmed')) {
        errorMessage = 'Please confirm your email before logging in.';
      }
      _error = errorMessage;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    
    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      await _supabaseService.signOut();
      _currentUser = null;
      
      // Clear other providers when signing out
      // Note: We can't directly access other providers here, so this will be handled
      // in the UI when the user navigates to the login screen
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Sign out failed: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? name,
    String? avatarUrl,
  }) async {
    if (_currentUser?.uuid == null) return;

    try {
      await _supabaseService.updateUserProfile(
        userId: _currentUser!.uuid!,
        name: name,
        avatarUrl: avatarUrl,
      );

      if (name != null) {
        _currentUser = _currentUser!.copyWith(name: name);
      }
      if (avatarUrl != null) {
        _currentUser = _currentUser!.copyWith(avatarUrl: avatarUrl);
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to update profile: $e';
      notifyListeners();
    }
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      _currentUser = await _supabaseService.getUserById(userId);
      if (_currentUser == null) {
        // If profile doesn't exist, create a default one
        _currentUser = app_user.User(
          uuid: userId,
          email: _supabaseService.currentUser?.email,
          name: _supabaseService.currentUser?.userMetadata?['name'] ?? 'User',
          lastActive: DateTime.now(),
        );
        print('Created default user profile for: ${_currentUser?.email}');
      }
      notifyListeners();
    } catch (e) {
      print('Failed to load user profile: $e');
      _error = 'Failed to load user profile: $e';
      notifyListeners();
    }
  }

  Future<void> refreshUserData() async {
    if (_currentUser?.uuid == null) return;

    try {
      print('Refreshing user data for user: ${_currentUser!.uuid}');
      final updatedUser = await _supabaseService.getUserById(_currentUser!.uuid!);
      if (updatedUser != null) {
        print('Updated user data received:');
        print('- Name: ${updatedUser.name}');
        print('- Email: ${updatedUser.email}');
        print('- Avatar URL: ${updatedUser.avatarUrl}');
        _currentUser = updatedUser;
        notifyListeners();
        print('User data refreshed and listeners notified');
      } else {
        print('No updated user data received');
      }
    } catch (e) {
      print('Failed to refresh user data: $e');
      _error = 'Failed to refresh user data: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
} 