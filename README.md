# 🚀 aProfileo

> Mobile app linked with portfolio website chat system for seamless communication.

---

## 📖 Description

aProfileo is a Flutter-based mobile application that connects directly to the chat system on the portfolio website. It enables visitors to communicate through their mobile devices, providing a native app experience for real-time messaging and interaction.

What makes it unique:
- Native mobile experience for portfolio chat
- Real-time message synchronization
- Push notifications for new messages
- Offline message queuing
- Seamless integration with web portfolio

---

## ✨ Features

- **Real-time Chat** – Instant messaging with portfolio visitors
- **Push Notifications** – Never miss a message
- **Offline Support** – Queue messages when offline
- **Message History** – Access past conversations
- **User Profiles** – View visitor information
- **Cross-platform** – Works on Android and iOS

---

## 🧠 Tech Stack

**Frontend**
- Flutter
- Dart

**Backend Integration**
- Firebase Firestore
- Firebase Cloud Messaging

**Platform**
- Android
- iOS

---

## 🏗️ Architecture / Workflow

```text
Mobile App → Firebase → Portfolio Website Chat System → Real-time Sync
```

---

## ⚙️ Installation & Setup

```bash
# Clone the repository
git clone https://github.com/DevRanbir/aprofileo.git

# Navigate to project
cd aprofileo

# Get Flutter dependencies
flutter pub get

# Run the app
flutter run
```

---

## 🔐 Environment Variables

Create a `lib/config. dart` file and add:

```dart
class Config {
  static const String firebaseApiKey = 'your_firebase_api_key';
  static const String projectId = 'your_project_id';
  static const String messagingSenderId = 'your_sender_id';
}
```

---

## 🧪 Usage

* Step 1: Install the app on your device
* Step 2: Sign in with your credentials
* Step 3: Receive notifications for new messages
* Step 4:  Respond to portfolio visitors in real-time
* Step 5:  Manage conversations on the go

---

## 📂 Project Structure

```text
aprofileo/
├── lib/
│   ├── screens/
│   ├── widgets/
│   ├── services/
│   └── models/
├── android/
├── ios/
├── pubspec.yaml
└── README.md
```

---

## 🚧 Future Improvements

- [ ] Add voice message support
- [ ] Implement video call feature
- [ ] Add file sharing capabilities
- [ ] Create chat templates
- [ ] Add multi-language support

---

## 👥 Team / Author

* **Name:** DevRanbir
* **GitHub:** [https://github.com/DevRanbir](https://github.com/DevRanbir)

---

## 📜 License

This project is licensed under the MIT License.
