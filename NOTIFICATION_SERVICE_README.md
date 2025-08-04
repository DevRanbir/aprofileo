# Android Notification Service for AProfileo

This notification service provides comprehensive push notification support for your Flutter Android app, handling both foreground and background notifications when new chat messages arrive.

## Features

- **Real-time Notifications**: Automatically detects new messages in Firestore and displays notifications
- **Foreground & Background Support**: Works when app is active, in background, or completely closed
- **FCM Integration**: Uses Firebase Cloud Messaging for reliable delivery
- **Local Notifications**: Uses Flutter Local Notifications for enhanced control
- **Duplicate Prevention**: Smart filtering to avoid spam notifications
- **Android-Specific**: Optimized specifically for Android platform

## Setup

### 1. Dependencies (Already Added)
- `firebase_messaging: ^14.7.17`
- `flutter_local_notifications: ^16.3.2`
- `cloud_firestore: ^4.15.5`

### 2. Android Configuration (Already Added)
- FCM service declared in `AndroidManifest.xml`
- Notification permissions included
- Default notification channel configured

### 3. Firebase Configuration
- `google-services.json` is already configured with your project
- Firebase project ID: `devprofileo`

## Usage

### Initialization
The service is automatically initialized in `main.dart`:

```dart
await NotificationService().initialize();
```

### Manual Testing
Use the floating action button in the admin chat screen to access notification testing tools.

### Testing Notifications

1. **Grant Permission**: Use the test widget to request notification permission
2. **Add Test Message**: Add a new document to the `chat_messages` collection in Firestore
3. **Verify**: Notification should appear regardless of app state

Example Firestore document structure:
```json
{
  "sender": "Test User",
  "userName": "Test User",
  "message": "Hello! This is a test message.",
  "timestamp": "2025-01-01T12:00:00Z",
  "expiresAt": "2025-01-02T12:00:00Z",
  "userId": "test-user-123"
}
```

## How It Works

### 1. Firestore Listener
- Monitors `chat_messages` collection for new documents
- Filters messages by timestamp to avoid duplicates
- Triggers local notifications for new messages

### 2. Firebase Cloud Messaging
- Handles background message delivery
- Registers FCM tokens for targeted notifications
- Processes notification taps to navigate to chat

### 3. Local Notifications
- Creates notification channels for Android
- Displays rich notifications with sender info
- Handles notification interaction

## Key Methods

### `NotificationService().initialize()`
Initializes the entire notification system.

### `NotificationService().requestNotificationPermission()`
Requests notification permission from the user.

### `NotificationService().getFCMToken()`
Gets the FCM token for this device.

### `NotificationService().clearAllNotifications()`
Clears all displayed notifications.

### `NotificationService().sendNotificationToAll()`
Sends notifications to all registered devices (requires server-side implementation).

## Firestore Collections Used

### `chat_messages`
Main collection for chat messages that triggers notifications.

### `fcm_tokens`
Stores FCM tokens for all devices to enable targeted notifications.

## Troubleshooting

### No Notifications Appearing
1. Check notification permission is granted
2. Verify FCM token is being generated
3. Ensure Firebase project is correctly configured
4. Check Android notification channel settings

### Duplicate Notifications
The service includes smart filtering based on timestamp to prevent duplicates.

### Background Notifications Not Working
- Ensure `firebase_messaging_auto_init_enabled` is true in AndroidManifest.xml
- Verify background message handler is properly registered
- Check Android battery optimization settings

## Server-Side Implementation (Optional)

For sending notifications from your server:

```javascript
// Example using Firebase Admin SDK
const admin = require('firebase-admin');

const message = {
  notification: {
    title: 'New Message',
    body: 'You have a new chat message'
  },
  data: {
    messageId: 'message-123',
    sender: 'John Doe',
    timestamp: new Date().toISOString()
  },
  token: 'user-fcm-token'
};

admin.messaging().send(message);
```

## Production Considerations

1. **Security**: FCM tokens should be securely managed
2. **Performance**: Monitor Firestore read operations
3. **Battery**: Consider notification frequency limits
4. **Privacy**: Respect user notification preferences
5. **Analytics**: Track notification delivery and engagement

## Files Created/Modified

1. `lib/services/notification_service.dart` - Main notification service
2. `lib/widgets/notification_test_widget.dart` - Testing interface
3. `android/app/src/main/AndroidManifest.xml` - FCM configuration
4. `android/app/google-services.json` - Firebase configuration
5. `lib/main.dart` - Service initialization
6. `lib/screens/admin_chat_screen.dart` - Test button integration

## Next Steps

1. Test notifications with real Firebase data
2. Implement server-side notification sending (optional)
3. Add custom notification sounds/styles
4. Implement notification analytics
5. Add user notification preferences

The notification service is now fully integrated and ready for testing!
