# 🏥 MediFlow Pro

**Complete Clinic & Medical Center Management System**

A production-ready Flutter application for managing clinics, hospitals, and medical centers. Supports **Android, iOS, Web, and Desktop** platforms.

---

## ✨ Features

### 👤 Patient Portal
- Sign up / Login with role-based access
- Browse doctors by specialty with search & filtering
- Book appointments with date/time selection
- View upcoming & past appointments
- Prescription history with medication details
- Profile management with theme toggle (dark/light)

### 🩺 Doctor Portal
- Real-time dashboard with today's stats
- Appointment schedule management
- Patient records browser
- Revenue tracking
- Profile & availability settings

### 🛡️ Admin Portal
- Full analytics dashboard with charts
- Revenue overview (bar chart) & specialty distribution (pie chart)
- Manage doctors (add/edit/remove)
- Manage patients
- Billing & invoices with payment status tracking
- System-wide notifications

### 🔧 Technical Features
- **Clean Architecture** + MVVM pattern
- **Riverpod** state management
- **GoRouter** with role-based navigation guards
- **Material 3** with premium medical theme
- **Dark/Light mode** toggle
- **Responsive design** for mobile/tablet/web
- **Offline-first** demo data (Firebase-ready)
- **StatefulShellRoute** for persistent bottom navigation
- **Professional charts** (fl_chart)
- **Form validation** on all inputs
- **Reusable widget library** (StatCard, DoctorCard, AppointmentCard, etc.)

---

## 🏗️ Architecture

```
lib/
├── core/
│   ├── constants/      # Colors, Sizes, Strings
│   ├── theme/          # Material 3 Light/Dark themes
│   ├── providers/      # Riverpod state providers
│   └── widgets/        # Core reusable widgets
├── features/
│   ├── auth/           # Splash, Onboarding, Login, Register
│   ├── patient/        # Dashboard, Doctors, Appointments, Prescriptions, Profile
│   ├── doctor/         # Dashboard, Schedule, Patients, Profile
│   └── admin/          # Dashboard, Manage Doctors/Patients, Billing
├── shared/
│   ├── enums/          # UserRole, AppointmentStatus, Specialty, etc.
│   ├── models/         # User, Doctor, Appointment, Prescription, Invoice
│   └── widgets/        # Shared UI components
├── services/           # Demo data, future Firebase services
├── routes/             # GoRouter configuration
└── main.dart           # App entry point
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.41+ (stable channel)
- Dart 3.11+

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd mediflow

# Install dependencies
flutter pub get

# Run on web
flutter run -d chrome

# Run on Android
flutter run -d android

# Run on iOS
flutter run -d ios

# Build for production
flutter build web
flutter build apk
flutter build ios
```

### Demo Credentials

The app includes built-in demo data. Use any email/password to login:

| Role    | Email              | Password     |
|---------|-------------------|--------------|
| Patient | demo@mediflow.com | password123  |
| Doctor  | demo@mediflow.com | password123  |
| Admin   | demo@mediflow.com | password123  |

Select the desired role on the login screen before signing in.

---

## 🔥 Firebase Integration Guide

To connect Firebase services, follow these steps:

### 1. Create Firebase Project
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

### 2. Initialize Firebase in `main.dart`
```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MediFlowApp()));
}
```

### 3. Firestore Collections Structure
```
users/           → UserModel (role, fullName, email, phone...)
doctors/         → DoctorModel (specialty, fee, availability...)
appointments/    → AppointmentModel (patientId, doctorId, dateTime, status...)
prescriptions/   → PrescriptionModel (medications, diagnosis...)
invoices/        → InvoiceModel (items, total, paymentStatus...)
medical_reports/ → MedicalReportModel (fileUrl, fileType...)
```

### 4. Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    match /appointments/{appointmentId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null
        && (resource.data.patientId == request.auth.uid
            || resource.data.doctorId == request.auth.uid
            || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
    }
  }
}
```

---

## 📦 Key Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `go_router` | Declarative routing |
| `fl_chart` | Charts & analytics |
| `google_fonts` | Premium typography |
| `firebase_core` | Firebase integration |
| `cloud_firestore` | Database |
| `firebase_auth` | Authentication |
| `firebase_storage` | File uploads |
| `pdf` / `printing` | PDF invoice generation |
| `table_calendar` | Calendar widget |
| `intl` | Date formatting & i18n |

---

## 🎨 Design System

- **Primary**: Teal (`#0D9488`) — Professional medical feel
- **Secondary**: Indigo (`#6366F1`) — Modern accent
- **Accent**: Amber (`#F59E0B`) — Warm highlights
- **Typography**: Inter (Google Fonts)
- **Border Radius**: 8–24px with consistent tokens
- **Cards**: Zero elevation with subtle borders
- **Gradients**: Premium gradient stat cards

---

## 📱 Platform Support

| Platform | Status |
|----------|--------|
| Android  | ✅ Ready |
| iOS      | ✅ Ready |
| Web      | ✅ Built & Verified |
| Windows  | ✅ Ready |
| macOS    | ✅ Ready |
| Linux    | ✅ Ready |

---

## 📄 License

This project is available for commercial use as a template or client product.

---

**Built with ❤️ using Flutter 3.41 + Material 3**
