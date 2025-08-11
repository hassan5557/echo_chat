# 🗣️ Echo - Modern Real-time Chat Application

![Echo Logo](assets/icons/echo_logo.png)

## 📱 About Echo

**Echo** is a modern, feature-rich real-time chat application built with Flutter, Supabase, and Isar database. It provides seamless messaging experience with offline support, file sharing, group conversations, and emoji support.

## ✨ Features

### 💬 **Real-time Messaging**
- Instant message delivery with Supabase real-time subscriptions
- Message status tracking (sending, sent, delivered, read)
- Offline message storage with Isar database
- Message synchronization when back online

### 👥 **Group Conversations**
- Create and manage group chats
- Add/remove group members
- Group rename functionality
- Group deletion (creator only)
- Real-time group message updates

### 📎 **File Sharing**
- Image and video attachments
- Document sharing
- Camera and gallery integration
- File preview and download
- Secure file storage with Supabase

### 😊 **Emoji Support**
- Built-in emoji picker
- Emoji keyboard integration
- Recent emojis tracking
- Skin tone support

### 🎨 **Modern UI/UX**
- Responsive design for all screen sizes
- Dark/Light theme support
- Modern Material Design 3
- Smooth animations and transitions
- Profile image display with tap-to-view

### 🔐 **Authentication & Security**
- Secure user authentication with Supabase
- Row-level security (RLS) policies
- User profile management
- Contact management with privacy controls

### 📱 **Cross-Platform**
- **Android**: Native Android app with custom Echo icon
- **iOS**: Native iOS app with custom Echo icon
- **Web**: Progressive Web App (PWA) with offline support
- **Windows**: Desktop application with custom Echo branding

## 🛠️ Technology Stack

### **Frontend**
- **Flutter**: Cross-platform UI framework
- **Provider**: State management
- **Responsive Framework**: Adaptive UI design

### **Backend & Database**
- **Supabase**: Backend-as-a-Service
  - Real-time database
  - Authentication
  - File storage
  - Row-level security
- **Isar**: Local database for offline support

### **Key Packages**
- `supabase_flutter`: Supabase integration
- `isar`: Local database
- `provider`: State management
- `image_picker`: File selection
- `emoji_picker_flutter`: Emoji support
- `cached_network_image`: Image caching
- `uuid`: Unique identifiers
- `intl`: Internationalization

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Dart SDK
- Supabase account and project
- Android Studio / VS Code

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd echo
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   - Create a Supabase project
   - Set up database tables and RLS policies
   - Configure authentication
   - Set up storage buckets

4. **Update configuration**
   - Add your Supabase URL and anon key to `lib/utils/config.dart`

5. **Run the application**
   ```bash
   # Android
   flutter run
   
   # iOS
   flutter run
   
   # Web
   flutter run -d chrome
   
   # Windows
   flutter run -d windows
   ```

## 📋 Database Schema

### Users Table
- UUID, name, email, avatar URL, created/updated timestamps

### Contacts Table
- User relationships with RLS policies

### Messages Table
- Text content, sender/receiver, timestamp, status, attachments

### Groups Table
- Group information, creator, members

### Group Messages Table
- Group-specific messages with sender information

## 🎨 Brand Identity

### Logo Design
- **Speech Bubble**: Represents communication and messaging
- **Paperclip**: Symbolizes file attachments and sharing
- **"Echo" Text**: App identity and branding
- **Blue Color (#007AFF)**: Trust, reliability, modern design

### Color Palette
- **Primary Blue**: #007AFF
- **Dark Gray**: #2C2C2E
- **White**: #FFFFFF

## 🔧 Configuration

### Environment Setup
```dart
// lib/utils/config.dart
class Config {
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```

### Icon Generation
The app uses `flutter_launcher_icons` for consistent branding across platforms:
```yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  windows:
    generate: true
    image_path: "assets/icons/echo_logo.png"
  web:
    generate: true
    image_path: "assets/icons/echo_logo.png"
```

## 📱 Screenshots

### Chat Interface
- Modern message bubbles with timestamps
- Profile images and user avatars
- File attachment previews
- Emoji picker integration

### Group Management
- Group creation and member management
- Group settings and customization
- Real-time group updates

### User Profile
- Profile image management
- User information editing
- Theme preferences

## 🔒 Security Features

- **Row-Level Security (RLS)**: Database-level access control
- **Authentication**: Secure user login and registration
- **File Security**: Protected file uploads and downloads
- **Privacy Controls**: User data protection

## 🚀 Deployment

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

### Windows
```bash
flutter build windows --release
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Flutter Team**: For the amazing cross-platform framework
- **Supabase**: For the powerful backend-as-a-service
- **Isar Team**: For the excellent local database solution
- **Open Source Community**: For the various packages and tools used

## 📞 Support

For support and questions:
- Create an issue in the repository
- Check the documentation
- Review the code comments

---

**Echo** - Where conversations come to life! 🗣️✨
