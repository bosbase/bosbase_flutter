# Bosbase Flutter Example

This project is a Flutter application demonstrating how to integrate the Bosbase Dart SDK. It shows how to list songs from a Bosbase collection, add a new song through the SDK, and delete a song. When the SDK is not available, the page falls back to local mock data for listing only.

## Prerequisites

- Java Development Kit (JDK) 17
- Flutter SDK `3.35.7`
- Android Studio (for Android) or Xcode (for iOS)
- Git

## Installation

1. Clone the repository:
   - `git clone <your-repo-url>`
   - `cd bosbase_app`

2. Configure Java 17 and Flutter `3.35.7`:
   - Ensure your system `JAVA_HOME` points to a JDK 17 installation.
   - Ensure your `flutter` on PATH is version `3.35.7`.
     - You can manage Flutter version with FVM:
       - `dart pub global activate fvm`
       - `fvm use 3.35.7 --force`
       - Use `fvm flutter ...` commands to run the project.

3. Update `android/gradle.properties` for JDK 17 (example):
   - Open `android/gradle.properties` and add:
     ```
     # Use Java 17 (adjust to your JDK 17 installation path)
     org.gradle.java.home=C:\\Program Files\\Java\\jdk-17

     # Optional: tune Gradle memory and encoding
     org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8

     # Document the required Flutter SDK version (informational)
     flutter.sdk.version=3.35.7
     ```
   - Note: `flutter.sdk.version` here is informational. Flutter version is controlled by the SDK you install or by FVM.

4. Install dependencies:
   - `flutter pub get` (or `fvm flutter pub get` if using FVM)

5. Run the app:
   - Android: `flutter run -d android`
   - iOS: `flutter run -d ios`
   - Windows: `flutter run -d windows`
   - Web: `flutter run -d chrome`

## Bosbase SDK

### Dependency

- The app imports the Bosbase SDK with `import 'package:bosbase/bosbase.dart';`.
- If you need to add or update the SDK:
  - Preferred: `flutter pub add bosbase` (uses the latest hosted version on pub.dev)
  - Alternatively (Git): add the following to `pubspec.yaml` under `dependencies`:
    ```yaml
    bosbase:
      git:
        url: https://github.com/bosbase/dart-sdk.git
    ```
  - Then run `flutter pub get`.

### Configuration

- The default Bosbase endpoint and credentials are centralized in `lib/config.dart`:
  ```dart
  class AppConfig {
    static const String endpoint = 'http://192.168.37.129:8090';
    static const String adminEmail = 'a@qq.com';
    static const String adminPassword = 'bosbasepass';
  }
  ```
- To change them, update `lib/config.dart` and rebuild the app.
- Security note: Avoid committing real credentials in public repositories. Use environment-specific config management for production.

### App Behavior

- On startup, the app tries to authenticate and load the `songs` collection via the SDK.
- If SDK connects:
  - The list displays records from `songs`.
  - Add button inserts a new record using a generated name (no manual input).
  - Long-press on a song opens a delete confirmation and removes the record via SDK.
- If SDK fails to connect:
  - The page displays locally generated mock songs.
  - The Add button requires SDK and shows an error if not connected.

## Troubleshooting

- Missing `.g.dart` or duplicate method build errors:
  - Prefer the hosted package: `flutter pub add bosbase` and remove any Git dependency to avoid ungenerated sources.
- Gradle or AGP requiring Java 17:
  - Ensure `JAVA_HOME` points to JDK 17 and optionally set `org.gradle.java.home` in `android/gradle.properties`.
- SDK not connected:
  - Verify the Bosbase server is reachable from your device/emulator.
  - Confirm endpoint, email, and password in `lib/bosbase_service.dart`.

## Project Structure

- `lib/bosbase_service.dart`: Bosbase client setup, authentication, and CRUD helpers.
- `lib/songs_tab.dart`: UI for listing, adding, and deleting songs with SDK fallback.
- `lib/song_detail_tab.dart`: Detail page showing a selected song.
- `pubspec.yaml`: Project dependencies.

## Notes

- This project targets Flutter `3.35.7` and uses Android Gradle Plugin 8.x that requires JDK 17.
- UI strings on the songs page are in English.