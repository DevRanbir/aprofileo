# 🚀 AProfileo - Real-Time Chat Management System

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

**A powerful Flutter application for managing real-time chat conversations with advanced notification grouping and reliable background processing.**

[Features](#-features) • [Installation](#-installation) • [Configuration](#-configuration) • [Usage](#-usage) • [Architecture](#-architecture) • [Contributing](#-contributing)

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features) 
- [Screenshots](#-screenshots)
- [Installation & Setup](#-installation--setup)
- [Firebase Configuration](#-firebase-configuration)
- [Project Structure](#-project-structure)
- [Core Components](#-core-components)
- [Notification System](#-notification-system)
- [Usage Guide](#-usage-guide)
- [Testing](#-testing)
- [Troubleshooting](#-troubleshooting)
- [API Reference](#-api-reference)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Overview

AProfileo is a comprehensive real-time chat management system built with Flutter and Firebase. It provides administrators with powerful tools to manage customer conversations, with advanced features like intelligent notification grouping, reliable background processing, and comprehensive analytics.

### 🌟 What Makes AProfileo Special?

- **🔄 Real-Time Communication**: Instant message delivery and synchronization
- **📱 Smart Notifications**: Advanced notification grouping to prevent spam
- **🔋 Background Reliability**: Robust background processing that works even when the app is closed
- **📊 Analytics Dashboard**: Comprehensive insights into chat performance
- **🎨 Modern UI**: Clean, responsive design with dark theme support
- **🛡️ Enterprise-Ready**: Built with scalability and security in mind

---

## ✨ Key Features

### 🔥 Real-Time Chat Management
- **Live Conversations**: View and respond to user messages in real-time
- **Unread Indicators**: Clear visual indicators for pending messages
- **Auto-Scroll**: Automatic scrolling to new messages
- **Message History**: Complete conversation history with timestamps
- **User Identification**: Track conversations by user names and IDs

### 📱 Advanced Notification System
- **Smart Grouping**: Multiple messages from the same user are grouped into single notifications
- **Background Processing**: Reliable notifications even when app is closed or backgrounded
- **Multiple Fallbacks**: Redundant notification systems ensure delivery
- **Customizable Channels**: Different notification types with appropriate priority levels
- **Permission Management**: Intelligent permission requesting and handling

### 📊 Analytics & Insights
- **Real-Time Statistics**: Live metrics on conversation volume
- **User Engagement**: Track active conversations and response times
- **Message Analytics**: Breakdown of user vs support messages
- **Performance Monitoring**: System health and notification delivery status

### 🛠️ Administrative Tools
- **Search & Filter**: Find conversations by user name or message content
- **Bulk Operations**: Mark multiple conversations as read
- **Message Management**: Edit and delete support messages
- **Automated Cleanup**: Automatic removal of expired conversations
- **Testing Tools**: Built-in notification and system testing

### 🔧 Technical Excellence
- **Offline Support**: Works with poor network connectivity
- **Background Sync**: Continues processing when app is not active
- **Error Recovery**: Automatic retry mechanisms for failed operations
- **Performance Optimized**: Efficient memory and battery usage
- **Modular Architecture**: Clean, maintainable code structure

---

## 📱 Screenshots

| Chat Dashboard | Conversation View | Notification Grouping |
|:-------------:|:----------------:|:--------------------:|
| *Real-time chat overview with unread indicators* | *Detailed conversation interface* | *Smart notification grouping in action* |

---

## 🚀 Installation & Setup

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (3.0 or higher) - [Installation Guide](https://docs.flutter.dev/get-started/install)
- **Dart SDK** (2.19 or higher) - *Included with Flutter*
- **Android Studio** or **VS Code** with Flutter extensions
- **Firebase CLI** - [Installation Guide](https://firebase.google.com/docs/cli)
- **Git** for version control

### 🔧 Step 1: Clone the Repository

```bash
# Clone the repository
git clone https://github.com/DevRanbir/aprofileo.git

# Navigate to project directory
cd aprofileo

# Check Flutter installation
flutter doctor
```

### 📦 Step 2: Install Dependencies

```bash
# Clean any previous builds
flutter clean

# Get all dependencies
flutter pub get

# Verify no dependency conflicts
flutter pub deps
```

### 🔑 Step 3: Firebase Setup

1. **Create Firebase Project**
   ```bash
   # Login to Firebase (if not already logged in)
   firebase login
   
   # Initialize Firebase in your project
   firebase init
   ```

2. **Download Configuration Files**
   - Download `google-services.json` for Android → Place in `android/app/`
   - Download `GoogleService-Info.plist` for iOS → Place in `ios/Runner/`

3. **Update Firebase Options**
   
   Edit `lib/firebase_options.dart` with your actual Firebase configuration:

   ```dart
   static const FirebaseOptions android = FirebaseOptions(
     apiKey: 'your-android-api-key',
     appId: 'your-android-app-id',
     messagingSenderId: 'your-messaging-sender-id',
     projectId: 'your-project-id',
     storageBucket: 'your-project.appspot.com',
   );
   ```

### 🏗️ Step 4: Build and Run

```bash
# For development
flutter run

# For release build
flutter build apk --release

# For debugging with logs
flutter run --verbose
```

---

## 🔥 Firebase Configuration

### Required Firebase Services

1. **Cloud Firestore** - Real-time database for chat messages
2. **Firebase Messaging** - Push notifications
3. **Firebase Analytics** - Usage tracking (optional)
4. **Firebase Auth** - User authentication (future feature)

### Firestore Database Structure

```javascript
// Collection: chat-messages
{
  "chat_user_timestamp": {
    "userName": "John Doe",
    "userId": "user_12345",
    "supportAgentName": "Support Team",
    "createdAt": "2025-01-01T00:00:00Z",
    "lastUpdated": "2025-01-01T00:05:00Z",
    "messages": {
      "msg_12345_001": {
        "sender": "user",
        "message": "Hello, I need help",
        "timestamp": "2025-01-01T00:00:00Z",
        "expiresAt": "2025-01-01T02:00:00Z"
      },
      "msg_12345_002": {
        "sender": "support", 
        "message": "Hi! How can I help you?",
        "timestamp": "2025-01-01T00:01:00Z",
        "expiresAt": "2025-01-01T02:01:00Z"
      }
    }
  }
}

// Collection: fcm_tokens
{
  "token_id": {
    "token": "fcm_device_token",
    "platform": "android",
    "createdAt": "2025-01-01T00:00:00Z",
    "lastUpdated": "2025-01-01T00:00:00Z"
  }
}

// Collection: notification_requests
{
  "request_id": {
    "type": "chat_message",
    "title": "New message from John Doe",
    "body": "Hello, I need help",
    "data": {
      "messageId": "msg_12345_001",
      "sender": "John Doe",
      "timestamp": "2025-01-01T00:00:00Z"
    },
    "processed": false,
    "timestamp": "2025-01-01T00:00:00Z"
  }
}
```

### Security Rules

```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write access to chat-messages
    match /chat-messages/{document} {
      allow read, write: if true; // Configure based on your auth requirements
    }
    
    // Allow read/write access to FCM tokens
    match /fcm_tokens/{document} {
      allow read, write: if true;
    }
    
    // Allow read/write access to notification requests
    match /notification_requests/{document} {
      allow read, write: if true;
    }
  }
}
```

---

## 📁 Project Structure

```
aprofileo/
├── 📱 android/                     # Android-specific configuration
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── AndroidManifest.xml # App permissions and services
│   │   │   └── res/                # Android resources
│   │   └── google-services.json    # Firebase Android config
│   └── build.gradle                # Android build configuration
│
├── 🍎 ios/                         # iOS-specific configuration
│   ├── Runner/
│   │   ├── Info.plist              # iOS app configuration
│   │   └── GoogleService-Info.plist # Firebase iOS config
│   └── Runner.xcworkspace/         # Xcode workspace
│
├── 💻 lib/                         # Main application code
│   ├── 🎯 main.dart                # App entry point
│   ├── 🔥 firebase_options.dart    # Firebase configuration
│   │
│   ├── 📱 screens/                 # UI Screens
│   │   └── admin_chat_screen.dart  # Main chat management interface
│   │
│   ├── 🔧 services/                # Business Logic Layer
│   │   ├── chat_service.dart       # Chat operations and Firestore integration
│   │   └── notification_service.dart # Advanced notification management
│   │
│   ├── 🏗️ models/                  # Data Models
│   │   └── chat_models.dart        # Chat and message data structures
│   │
│   └── 🎨 widgets/                 # Reusable UI Components
│       ├── admin_stats_widget.dart # Analytics dashboard widget
│       ├── chat_conversation.dart  # Individual conversation view
│       └── thread_list_item.dart   # Chat list item component
│
├── 🧪 test/                        # Test files
│   ├── widget_test.dart            # Widget testing
│   └── notification_service_test.dart # Service testing
│
├── 📄 pubspec.yaml                 # Dependencies and project metadata
├── 🔥 firebase.json                # Firebase project configuration
├── ⚙️ analysis_options.yaml        # Code analysis rules
└── 📖 README.md                    # This file
```

---

## 🔧 Core Components

### 🎯 Main Application (`main.dart`)

The entry point initializes Firebase and the notification service:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with platform-specific configuration
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform
  );

  // Initialize the advanced notification system
  await NotificationService().initialize();

  runApp(const MyApp());
}
```

### 💬 Chat Service (`chat_service.dart`)

Manages all chat-related operations:

- **Real-time messaging** with Firestore integration
- **User management** and conversation tracking
- **Message persistence** with automatic expiration
- **Notification triggering** for new messages
- **Analytics data** collection and reporting

Key Methods:
```dart
// Send a message to chat
Future<Map<String, dynamic>> sendChatMessage(String message, String userId, String userName)

// Send support response
Future<Map<String, dynamic>> sendSupportResponse(String userId, String message)

// Get chat statistics
Future<Map<String, int>> getChatStatistics()

// Cleanup expired messages
Future<Map<String, dynamic>> cleanupExpiredMessages()
```

### 🔔 Notification Service (`notification_service.dart`)

Advanced notification management system:

- **Smart Grouping**: Groups multiple messages from the same user
- **Background Processing**: Continues working when app is closed
- **Multiple Fallbacks**: Ensures notification delivery
- **Lifecycle Management**: Adapts behavior based on app state
- **Permission Handling**: Manages notification permissions

Key Features:
```dart
// Initialize notification system
Future<void> initialize()

// Show grouped notification for multiple messages
Future<void> _sendGroupedNotification(String userKey)

// Test notification functionality
Future<void> testNotification({String title, String body})

// Handle app lifecycle changes
void didChangeAppLifecycleState(AppLifecycleState state)
```

### 🎨 UI Components

#### Admin Chat Screen
- **Responsive layout** that adapts to different screen sizes
- **Real-time updates** for new messages and conversations
- **Search functionality** to find specific conversations
- **Statistics panel** with key metrics
- **Testing tools** for system validation

#### Chat Conversation Widget
- **Real-time message display** with automatic updates
- **Message composition** with support for rich text
- **Typing indicators** and read receipts
- **Message management** (edit/delete support messages)

---

## 🔔 Notification System

### Smart Notification Grouping

The notification system intelligently groups messages to provide a better user experience:

```dart
// Before Grouping (overwhelming)
🔔 "Message from Alice: Hello"
🔔 "Message from Alice: How are you?"  
🔔 "Message from Alice: Are you there?"

// After Grouping (clean)
🔔 "3 new messages from Alice"
   • Hello
   • How are you? 
   • Are you there?
```

### Background Processing Architecture

1. **Foreground Mode**: Real-time Firestore listeners for instant updates
2. **Background Mode**: Aggressive polling every 3-5 seconds
3. **Closed App Mode**: Firebase Cloud Messaging with local notification fallbacks
4. **Offline Mode**: Local caching with sync when connection returns

### Notification Channels

| Channel ID | Purpose | Priority | Features |
|:-----------|:--------|:---------|:---------|
| `chat_channel` | Chat messages | High | Sound, vibration, heads-up |
| `system_status` | System notifications | Low | Silent, ongoing |
| `emergency_channel` | Critical alerts | Max | Full-screen, persistent |

---

## 📖 Usage Guide

### 🚀 Getting Started

1. **Launch the App**
   ```bash
   flutter run
   ```

2. **Grant Permissions**
   - The app will request notification permissions on first launch
   - Allow all permissions for full functionality

3. **View Dashboard**
   - The main screen shows all active conversations
   - Unread messages are highlighted with badges
   - Statistics are displayed in the top panel

### 💬 Managing Conversations

#### Viewing Messages
- **Tap any conversation** in the left panel to view details
- **Auto-scroll** keeps you at the latest messages
- **Timestamps** show when each message was sent
- **Sender identification** clearly shows user vs support messages

#### Responding to Users
- **Type your response** in the bottom text field
- **Press Enter or tap Send** to deliver the message
- **Messages are delivered instantly** to the user
- **Edit or delete** your messages if needed

#### Search and Filter
- **Use the search bar** to find specific conversations
- **Search by user name** or message content
- **Results update in real-time** as you type

### 📊 Analytics and Reports

#### Understanding Statistics
- **Total Threads**: All conversations in the system
- **Recent Activity**: Conversations from the last 24 hours
- **Unread Messages**: Threads requiring admin attention
- **Message Breakdown**: User messages vs support responses

#### Performance Monitoring
- **Notification Status**: Check if the notification system is working
- **Connection Health**: Monitor Firestore connectivity
- **Background Processing**: Verify background services are active

### 🔧 Testing and Debugging

#### Built-in Testing Tools
```dart
// Test basic notifications
await NotificationService().testNotification();

// Test grouped notifications (multiple messages from same user)
await NotificationService().testGroupedNotifications(userName: 'Test User', messageCount: 3);

// Test multiple users (different users get separate notifications)
await NotificationService().testMultipleUserNotifications();

// Check notification system status
final status = await NotificationService().getNotificationStatus();
```

#### Debugging Steps
1. **Check Permissions**: Ensure notification permissions are granted
2. **Verify Firebase Config**: Confirm Firebase project is set up correctly
3. **Test Connectivity**: Use built-in connection tests
4. **Monitor Logs**: Check console output for error messages
5. **Clear Cache**: Use "Clear processed messages" for fresh testing

---

## 🧪 Testing

### Unit Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/notification_service_test.dart

# Run tests with coverage
flutter test --coverage
```

### Integration Testing

```bash
# Test on physical device
flutter drive --target=test_driver/app.dart

# Test on emulator
flutter drive --target=test_driver/app.dart -d emulator-5554
```

### Manual Testing Checklist

- [ ] **Notifications appear when app is in foreground**
- [ ] **Notifications appear when app is in background**
- [ ] **Notifications appear when app is completely closed**
- [ ] **Multiple messages from same user are grouped**
- [ ] **Different users get separate notifications**
- [ ] **Search functionality works correctly**
- [ ] **Real-time updates work properly**
- [ ] **Message sending and receiving works**
- [ ] **Statistics display accurately**
- [ ] **App handles poor network connectivity**

---

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 🚫 Notifications Not Working

**Symptoms**: No notifications appear when messages are received

**Solutions**:
1. **Check Permissions**
   ```dart
   final hasPermission = await NotificationService().isNotificationPermissionGranted();
   if (!hasPermission) {
     await NotificationService().requestNotificationPermission();
   }
   ```

2. **Verify Firebase Configuration**
   - Ensure `google-services.json` is in `android/app/`
   - Check that Firebase project ID matches in `firebase_options.dart`
   - Verify Cloud Messaging is enabled in Firebase Console

3. **Test Notification System**
   ```dart
   await NotificationService().testNotification(
     title: 'Test',
     body: 'If you see this, notifications are working!'
   );
   ```

#### 🔌 Connection Issues

**Symptoms**: Messages not updating in real-time

**Solutions**:
1. **Check Internet Connection**
   - Verify device has stable internet access
   - Test with other apps to confirm connectivity

2. **Restart Firestore Listener**
   ```dart
   await NotificationService().restartFirestoreListener();
   ```

3. **Clear App Cache**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

#### 📱 Performance Issues

**Symptoms**: App is slow or consumes too much battery

**Solutions**:
1. **Optimize Background Processing**
   - Adjust polling intervals in notification service
   - Disable unnecessary background timers

2. **Clean Up Old Data**
   ```dart
   await ChatService().cleanupExpiredMessages();
   ```

3. **Memory Management**
   - Restart app if memory usage is high
   - Check for memory leaks in debug mode

#### 🏗️ Build Errors

**Symptoms**: App fails to compile or build

**Solutions**:
1. **Dependency Issues**
   ```bash
   flutter clean
   flutter pub cache repair
   flutter pub get
   ```

2. **Platform-Specific Issues**
   ```bash
   # For Android
   cd android && ./gradlew clean
   cd .. && flutter build apk
   
   # For iOS  
   cd ios && rm -rf Pods/ Podfile.lock
   pod install
   cd .. && flutter build ios
   ```

3. **Firebase Configuration**
   - Verify all Firebase config files are present
   - Check that package names match across all files

#### 📊 Statistics Not Loading

**Symptoms**: Dashboard shows empty or incorrect statistics

**Solutions**:
1. **Refresh Statistics**
   ```dart
   await ChatService().getChatStatistics();
   ```

2. **Check Database Permissions**
   - Verify Firestore security rules allow read access
   - Test with Firebase Console to ensure data exists

3. **Clear Processed Cache**
   ```dart
   NotificationService().clearProcessedMessagesCache();
   ```

---

## 📚 API Reference

### ChatService Methods

```dart
class ChatService {
  // Message Operations
  Future<Map<String, dynamic>> sendChatMessage(String message, String userId, String userName);
  Future<Map<String, dynamic>> sendSupportResponse(String userId, String message);
  Future<Map<String, dynamic>> editSupportMessage(String userId, String messageId, String newMessage);
  Future<Map<String, dynamic>> deleteSupportMessage(String userId, String messageId);
  
  // Thread Management  
  Stream<List<ChatThread>> subscribeToAllChatThreads();
  Stream<ChatThread?> subscribeToThread(String userId);
  Future<void> markThreadAsRead(String userId);
  Future<Map<String, dynamic>> deleteChatThread(String userId);
  
  // Search and Analytics
  Stream<List<ChatThread>> searchThreads(String searchQuery);
  Future<Map<String, int>> getChatStatistics();
  
  // Maintenance
  Future<Map<String, dynamic>> cleanupExpiredMessages();
  
  // Testing
  Future<Map<String, dynamic>> testChatFlow({String? testUserId});
}
```

### NotificationService Methods

```dart
class NotificationService {
  // Initialization
  Future<void> initialize();
  void dispose();
  
  // Core Functionality
  Future<void> sendChatNotificationToAllTokens({required String title, required String body, required String messageId, required String sender, required String timestamp});
  Future<void> processPendingNotifications();
  
  // Notification Management
  Future<void> clearAllNotifications();
  Future<void> clearNotification(int id);
  Future<void> clearNotificationsForUser(String userKey);
  
  // Testing
  Future<void> testNotification({String title = 'Test Notification', String body = 'This is a test notification'});
  Future<void> testGroupedNotifications({String userName = 'Test User', int messageCount = 3});
  Future<void> testMultipleUserNotifications();
  
  // Configuration
  void setCurrentUserId(String? userId);
  Future<bool> isNotificationPermissionGranted();
  Future<bool> requestNotificationPermission();
  
  // Status and Debugging
  Future<Map<String, dynamic>> getNotificationStatus();
  void clearProcessedMessagesCache();
  Future<void> restartFirestoreListener();
}
```

### Model Classes

```dart
class ChatMessage {
  final String id;
  final String sender;
  final String? userName;
  final String message;
  final DateTime timestamp;
  final DateTime expiresAt;
  final String userId;
  final bool isFromUser;
  final bool isFromSupport;
}

class ChatThread {
  final String id;
  final String userName;
  final String userId;
  final String supportAgentName;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final List<ChatMessage> messages;
  final bool hasUnreadUserMessages;
  final ChatMessage? lastMessage;
}
```

---

## 🤝 Contributing

We welcome contributions to AProfileo! Here's how you can help:

### 🚀 Getting Started

1. **Fork the repository**
   ```bash
   git clone https://github.com/DevRanbir/aprofileo.git
   cd aprofileo
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow the existing code style
   - Add tests for new functionality
   - Update documentation as needed

4. **Test your changes**
   ```bash
   flutter test
   flutter analyze
   flutter format .
   ```

5. **Submit a pull request**
   - Provide a clear description of your changes
   - Include screenshots for UI changes
   - Reference any related issues

### 📝 Code Style Guidelines

- **Follow Dart/Flutter conventions**
- **Use meaningful variable and function names**
- **Add documentation comments for public APIs**
- **Keep functions small and focused**
- **Use const constructors where possible**
- **Handle errors gracefully**

### 🐛 Reporting Bugs

When reporting bugs, please include:

- **Flutter version** (`flutter --version`)
- **Device information** (OS, version, model)
- **Steps to reproduce** the issue
- **Expected vs actual behavior**
- **Console logs** and error messages
- **Screenshots** if applicable

### 💡 Feature Requests

For feature requests, please provide:

- **Clear description** of the proposed feature
- **Use case** and justification
- **Potential implementation approach**
- **Any relevant mockups or examples**

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025 DevRanbir

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 📞 Support & Contact

- **GitHub Issues**: [Report bugs or request features](https://github.com/DevRanbir/aprofileo/issues)
- **Developer**: DevRanbir
- **Project Repository**: [https://github.com/DevRanbir/aprofileo](https://github.com/DevRanbir/aprofileo)

---

<div align="center">

**⭐ If you find this project helpful, please consider giving it a star! ⭐**

Made with ❤️ by [DevRanbir](https://github.com/DevRanbir)

---

*AProfileo - Empowering real-time communication with intelligent notification management*

</div>
