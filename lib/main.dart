import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/group_provider.dart';
import 'providers/theme_provider.dart';
import 'utils/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize theme provider
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AuthProvider()),
        ChangeNotifierProvider.value(value: ContactProvider()),
        ChangeNotifierProvider.value(value: ChatProvider()),
        ChangeNotifierProvider.value(value: ConversationProvider()),
        ChangeNotifierProvider.value(value: GroupProvider()),
        ChangeNotifierProvider.value(value: ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Flutter Chat',
            theme: themeProvider.isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,

            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        }

                 // Clear providers when user is not authenticated (logged out)
         if (mounted) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) {
               final contactProvider = Provider.of<ContactProvider>(context, listen: false);
               final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
               final chatProvider = Provider.of<ChatProvider>(context, listen: false);
               final groupProvider = Provider.of<GroupProvider>(context, listen: false);
               
               contactProvider.clearContacts();
               conversationProvider.clearConversations();
               chatProvider.clearMessages();
               groupProvider.clearGroups();
             }
           });
         }

        return const LoginScreen();
      },
    );
  }
}
