import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../utils/modern_ui_helpers.dart';
import '../widgets/theme_toggle_button.dart';
import 'conversations_screen.dart';
import 'contacts_screen.dart';
import 'groups_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ConversationsScreen(),
    const ContactsScreen(),
    const GroupsScreen(),
    const ProfileScreen(),
  ];

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: 'Chats',
    ),
    NavigationItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Contacts',
    ),
    NavigationItem(
      icon: Icons.group_outlined,
      activeIcon: Icons.group,
      label: 'Groups',
    ),
    NavigationItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.colorScheme.onSurface,
          ),
        ),
        backgroundColor: context.colorScheme.surface,
        elevation: 0,
        actions: [
          const ThemeToggleButton(),
          if (_currentIndex == 3) // Only show logout on profile screen
            IconButton(
              icon: Icon(
                Icons.logout,
                color: context.colorScheme.onSurface,
              ),
              onPressed: () => _showLogoutDialog(context),
            ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildModernBottomNavigation(),
    );
  }

  Widget _buildModernBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveHelper.isDesktop(context) 
                ? context.spacing32 
                : context.spacing16,
            vertical: ResponsiveHelper.isDesktop(context) 
                ? context.spacing12 
                : context.spacing8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navigationItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == _currentIndex;

              return _buildNavigationItem(
                item: item,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationItem({
    required NavigationItem item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing12,
          vertical: context.spacing8,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? context.colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(context.radius12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected 
                  ? context.colorScheme.primary
                  : context.colorScheme.onSurface.withOpacity(0.6),
              size: 24,
            ),
            SizedBox(height: context.spacing4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected 
                    ? context.colorScheme.primary
                    : context.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Chats';
      case 1:
        return 'Contacts';
      case 2:
        return 'Groups';
      case 3:
        return 'Profile';
      default:
        return 'Flutter Chat';
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.radius16),
          ),
          title: Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurface,
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: TextStyle(
              color: context.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: context.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
                         ElevatedButton(
               onPressed: () async {
                 Navigator.of(context).pop();
                 final authProvider = Provider.of<AuthProvider>(context, listen: false);
                 await authProvider.signOut();
                 if (mounted && context.mounted) {
                   Navigator.pushAndRemoveUntil(
                     context,
                     MaterialPageRoute(
                       builder: (context) => const LoginScreen(),
                     ),
                     (route) => false,
                   );
                 }
               },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colorScheme.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
} 