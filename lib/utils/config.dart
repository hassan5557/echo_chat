class Config {
  // Supabase Configuration
  static const String supabaseUrl = 'https://mxwzfkuxttphxuifurcw.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im14d3pma3V4dHRwaHh1aWZ1cmN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ0OTY5NDQsImV4cCI6MjA3MDA3Mjk0NH0.0-nh1vD5xp0pd2j9XC4grpQlAs7VSbexaIvVN88Jk2I';
  
  // App Configuration
  static const String appName = 'Flutter Chat';
  static const String appVersion = '1.0.0';
  
  // Database Configuration
  static const String isarDatabaseName = 'flutter_chat.isar';
  
  // Message Configuration
  static const int maxMessageLength = 1000;
  static const int maxGroupNameLength = 50;
  
  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 8.0;
  
  // Validation
  static const int minPasswordLength = 6;
  static const int maxNameLength = 50;
} 