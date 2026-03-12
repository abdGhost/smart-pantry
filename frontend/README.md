# Smart Pantry – Flutter frontend

Cross-platform Flutter app for Smart Pantry: dashboard, recipe suggestions, recipe details with AI steps, and adding items via receipt scan, barcode scan, manual form, or pasted text.

## Tech stack

- **Flutter** (Dart) – iOS, Android, Web, Windows
- **Riverpod** – state management
- **Dio** – HTTP client for the Smart Pantry API
- **Hive** – optional local cache
- **intl** – date/time formatting
- **image_picker** – receipt photo or gallery
- **mobile_scanner** – barcode scan (iOS/Android)
- **flutter_native_splash** – native splash screen (cream theme)
- **google_fonts**, **flutter_animate**, **shimmer** – UI

## Getting started

1. **Install dependencies**

```bash
cd frontend
flutter pub get
```

2. **Run the app**

Ensure the [backend](../backend) is running on **http://localhost:8100**, then:

```bash
# Web
flutter run -d chrome

# Windows desktop
flutter run -d windows

# iOS simulator / Android emulator / device
flutter run
```

3. **Custom API URL**

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://your-host:8100
```

## Project structure

- `lib/core/` – theme, colors
- `lib/models/` – recipe, recipe details, food item
- `lib/providers/` – pantry API, Riverpod providers
- `lib/screens/` – dashboard, recipe results, recipe detail, barcode scanner
- `lib/widgets/` – recipe card, pantry tile, scan FAB, dialogs (manual add, paste receipt)

## Splash screen

Splash is configured in `pubspec.yaml` under `flutter_native_splash`. To regenerate after changes:

```bash
dart run flutter_native_splash:create
```

## Platform notes

- **Web**: “Scan receipt” uses file picker; “Scan barcode” shows a message to use the app on a phone.
- **iOS/Android**: Camera and barcode scanner work; ensure camera permission is granted.
- **Theme**: Teal and cream (`AppColors`); no white cards.
