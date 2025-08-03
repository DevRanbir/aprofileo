# AProfileo Admin Chat Dashboard

A Flutter admin panel for managing real-time chat conversations from your website visitors.

## Features

### 🔥 Real-time Chat Management
- View all active chat conversations in real-time
- Respond to user messages instantly
- See unread message indicators
- Auto-scroll to new messages

### 📊 Analytics Dashboard
- Total conversation count
- Recent activity (last 24 hours)
- Pending responses awaiting admin reply
- Message statistics (user vs support messages)

### 🧹 Maintenance Tools
- Automatic message expiration (2 hours)
- Manual cleanup of expired conversations
- Database optimization features

### 🔍 Search & Filter
- Search conversations by user name
- Search within message content
- Filter active vs expired threads

## Setup Instructions

### 1. Firebase Configuration
Make sure your Firebase project is properly configured with:
- Cloud Firestore enabled
- Collection name: `chat-messages`
- Proper security rules for admin access

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run the App
```bash
flutter run
```

## Chat System Integration

This admin panel works with the JavaScript chat system from your website. The chat structure follows this pattern:

### Thread Structure
```
chat-messages/
  ├── thread_user_001/           # Auto-generated thread ID
  │   ├── userId: "user_001..."  # Original user ID
  │   ├── userName: "User Name"  # Display name
  │   ├── createdAt: timestamp
  │   ├── lastUpdated: timestamp
  │   └── messages/
  │       ├── msg_001/
  │       │   ├── sender: "user"
  │       │   ├── message: "Hello!"
  │       │   ├── timestamp: ISO string
  │       │   └── expiresAt: ISO string
  │       └── msg_002/
  │           ├── sender: "support"
  │           ├── message: "Hi! How can I help?"
  │           ├── timestamp: ISO string
  │           └── expiresAt: ISO string
```

### Message Flow
1. **User sends message** → Creates/updates thread in Firestore
2. **Admin sees message** → Real-time update in Flutter app
3. **Admin responds** → Message added to thread
4. **User sees response** → Real-time update on website

### Key Features

#### Thread List (Left Panel)
- **Status Indicators:**
  - 🟣 Purple: Unread user messages
  - 🟢 Green: Admin has responded
  - 🟠 Orange: Awaiting response

- **Information Displayed:**
  - User name and ID
  - Last message preview
  - Unread message count
  - Time since last activity
  - Total message count

#### Chat Conversation (Right Panel)
- **Message Display:**
  - User messages: Left-aligned, gray background
  - Admin messages: Right-aligned, purple background
  - Timestamp and sender indicators
  - Expired message warnings

- **Admin Features:**
  - Type and send responses
  - Copy messages (long press)
  - Auto-scroll to latest messages
  - Send confirmation feedback

#### Statistics Dashboard
- **Real-time Metrics:**
  - Total conversations
  - Recent activity (24 hours)
  - Pending responses
  - Message counts by type

- **Maintenance Tools:**
  - Cleanup expired threads
  - Database optimization
  - System information

## Usage Tips

### Best Practices
1. **Regular Monitoring:** Check for new messages frequently
2. **Quick Responses:** Aim to reply within business hours
3. **Professional Tone:** Maintain helpful, courteous communication
4. **Regular Cleanup:** Use the cleanup feature to maintain database performance

### Keyboard Shortcuts
- **Enter:** Send message
- **Long Press:** Copy message content
- **Refresh Button:** Update statistics

### Troubleshooting

#### Common Issues
1. **No messages appearing:**
   - Check Firebase configuration
   - Verify collection name is `chat-messages`
   - Ensure proper Firestore rules

2. **Can't send messages:**
   - Check internet connection
   - Verify Firebase authentication
   - Check console for errors

3. **Statistics not loading:**
   - Refresh the dashboard
   - Check Firestore permissions
   - Verify data structure

#### Error Handling
The app includes comprehensive error handling with:
- User-friendly error messages
- Automatic retry mechanisms
- Fallback UI states
- Console logging for debugging

## Integration with Website

### JavaScript Functions Used
From your `firestoreService.js`, this admin panel integrates with:

- `subscribeToAllChatThreads()` - Real-time thread monitoring
- `sendSupportResponse()` - Sending admin replies
- `cleanupExpiredMessages()` - Database maintenance
- `generateThreadId()` - Thread ID generation logic

### Data Synchronization
- **Real-time updates** using Firestore listeners
- **Automatic message expiration** after 2 hours
- **Thread-based organization** for easy management
- **Cross-platform compatibility** between web and mobile

## Security Considerations

### Admin Access
- This app should only be used by authorized personnel
- Consider implementing authentication for production use
- Restrict network access to admin devices only

### Data Privacy
- Messages automatically expire after 2 hours
- User data is handled according to your privacy policy
- Regular cleanup maintains data minimization

## Technical Details

### Architecture
- **Frontend:** Flutter with Material Design 3
- **Backend:** Firebase Cloud Firestore
- **Real-time:** Firestore listeners
- **State Management:** StatefulWidget with Streams

### Performance
- **Optimized queries** with proper indexing
- **Efficient pagination** for large datasets
- **Memory management** with Stream subscriptions
- **Auto-cleanup** for expired data

This admin chat system provides a professional, efficient way to manage customer conversations from your website, ensuring timely responses and excellent user experience.
- **Admin Replies**: Send replies that are marked as admin messages
- **Message Management**: Delete messages with long press
- **Real-time Updates**: Live updates using Firestore streams

## Database Structure

The app expects a Firestore collection named `chat-messages` with documents containing:

```json
{
  "message": "Hello, I need help with...",
  "messageType": "user", // or "admin" for replies
  "timestamp": "2025-08-01T14:23:34.041Z",
  "createdAt": "2025-08-01T14:23:34.041Z",
  "expiresAt": "2025-09-01T21:53:34Z",
  "isFromTelegram": false, // App filters for false values only
  "userId": "user_175405820943826puulbf",
  "userName": "King"
}
```

## Setup Instructions

### 1. Firebase Configuration

You need to configure Firebase for your project:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project or select existing one
3. Add your Flutter app to the project
4. Download the configuration files:
   - `google-services.json` for Android (place in `android/app/`)
   - `GoogleService-Info.plist` for iOS (place in `ios/Runner/`)

### 2. Update Firebase Options

Edit `lib/firebase_options.dart` and replace the placeholder values with your actual Firebase configuration:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'your-actual-api-key',
  appId: 'your-actual-app-id',
  messagingSenderId: 'your-messaging-sender-id',
  projectId: 'your-project-id',
  authDomain: 'your-project.firebaseapp.com',
  storageBucket: 'your-project.appspot.com',
);
```

Do this for all platforms (android, ios, macos, windows).

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Run the App

```bash
flutter run
```

## Usage

1. **View Users**: The main screen shows all users who have sent messages from your website
2. **Read Messages**: Tap on a user to view their conversation history
3. **Send Replies**: Use the text input at the bottom to send admin replies
4. **Delete Messages**: Long press on any message to delete it
5. **Real-time Updates**: Messages appear automatically as they come in

## Firestore Security Rules

Make sure your Firestore security rules allow read/write access to the `chat-messages` collection:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /chat-messages/{document} {
      allow read, write: if true; // Adjust based on your security needs
    }
  }
}
```

## Troubleshooting

1. **Firebase Connection Issues**: 
   - Verify your `firebase_options.dart` configuration
   - Check that Firebase project is properly set up
   - Ensure Firestore is enabled in Firebase Console

2. **No Messages Appearing**:
   - Verify your collection name is `chat-messages`
   - Check that messages have `isFromTelegram: false`
   - Verify Firestore security rules allow access

3. **Build Issues**:
   - Run `flutter clean && flutter pub get`
   - Ensure all Firebase configuration files are in place
   - Check that minimum SDK versions are met

## Dependencies

- `firebase_core`: Firebase SDK initialization
- `cloud_firestore`: Firestore database integration
- `firebase_auth`: Authentication (for future use)

## Architecture

- **Models**: Data structures for chat messages and users
- **Services**: Firestore service for database operations
- **Screens**: UI components for chat list and detail views
- **Firebase Integration**: Centralized Firebase configuration
