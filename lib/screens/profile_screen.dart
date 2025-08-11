import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
// import '../widgets/theme_toggle_button.dart';
import '../models/user.dart' as app_user;
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 600 || screenWidth < 400;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUser;
          
          if (user == null) {
            return const Center(
              child: Text('No user data available'),
            );
          }

          // Debug: Print avatar URL
          if (user.avatarUrl != null) {
            print('Avatar URL: ${user.avatarUrl}');
            print('Avatar URL length: ${user.avatarUrl!.length}');
            print('Avatar URL starts with http: ${user.avatarUrl!.startsWith('http')}');
          } else {
            print('No avatar URL found');
          }
          
          Widget buildAvatar(app_user.User user, bool isSmallScreen) {
            return CircleAvatar(
              radius: isSmallScreen ? 40 : 50,
              backgroundColor: Theme.of(context).colorScheme.primary,
              backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? NetworkImage(user.avatarUrl!) 
                  : null,
              onBackgroundImageError: user.avatarUrl != null 
                  ? (exception, stackTrace) {
                      print('Error loading avatar: $exception');
                      print('Avatar URL was: ${user.avatarUrl}');
                      // Force rebuild to show fallback
                      setState(() {});
                    }
                  : null,
              child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                  ? Text(
                      user.name?.substring(0, 1).toUpperCase() ?? 'U',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 24 : 32,
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Center(
                  child: Column(
                    children: [
                      buildAvatar(user, isSmallScreen),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      Text(
                        user.name ?? 'Unknown User',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isSmallScreen ? 6 : 8),
                      Text(
                        user.email ?? '',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmallScreen ? 24 : 32),
                
                // Profile Information
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Information',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        _buildInfoRow('Name', user.name ?? 'Not set', isSmallScreen),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        _buildInfoRow('Email', user.email ?? 'Not set', isSmallScreen),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        _buildInfoRow(
                          'Last Active', 
                          user.lastActive != null 
                              ? _formatDate(user.lastActive!)
                              : 'Unknown',
                          isSmallScreen,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 20 : 24),
                
                // Actions
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Actions',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 16,
                            vertical: isSmallScreen ? 4 : 8,
                          ),
                          leading: Icon(
                            Icons.edit, 
                            color: Colors.blue,
                            size: isSmallScreen ? 20 : 24,
                          ),
                          title: Text(
                            'Edit Profile',
                            style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                          ),
                          subtitle: Text(
                            'Update your information',
                            style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                          ),
                                                     onTap: () async {
                             await Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (context) => const EditProfileScreen(),
                               ),
                             );
                             
                             // Refresh user data when returning from edit screen
                             await authProvider.refreshUserData();
                           },
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 16,
                            vertical: isSmallScreen ? 4 : 8,
                          ),
                          leading: Icon(
                            Icons.logout, 
                            color: Colors.red,
                            size: isSmallScreen ? 20 : 24,
                          ),
                          title: Text(
                            'Logout',
                            style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                          ),
                          subtitle: Text(
                            'Sign out of your account',
                            style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                          ),
                          onTap: () => _showLogoutDialog(context, authProvider),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: isSmallScreen ? 20 : 32),
                
                // App Version
                Center(
                  child: Text(
                    'Flutter Chat v1.0.0',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10 : 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 20 : 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isSmallScreen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isSmallScreen ? 80 : 100,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
              fontSize: isSmallScreen ? 12 : 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: isSmallScreen ? 12 : 14,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }



  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await authProvider.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                }
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
} 