import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

/// Firebase configuration — replace placeholder values with your project's config.
///
/// To generate this file automatically:
///   1. Install FlutterFire CLI: `dart pub global activate flutterfire_cli`
///   2. Run: `flutterfire configure`
///
/// Or manually:
///   1. Go to https://console.firebase.google.com
///   2. Create a project → Add Android app with package name `com.noblara.noblara_flutter`
///   3. Download `google-services.json` → place in `android/app/`
///   4. Copy the values below from the Firebase console
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAjMErTchW0-wrLDFyRkVL-9FkyTymE4fQ',
    appId: '1:20213020186:android:656e6a81fc29b5c21a03a3',
    messagingSenderId: '20213020186',
    projectId: 'noblora-8cbc0',
    storageBucket: 'noblora-8cbc0.firebasestorage.app',
  );

  // iOS: add values from Firebase Console when iOS app is registered
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAjMErTchW0-wrLDFyRkVL-9FkyTymE4fQ',
    appId: '1:20213020186:android:656e6a81fc29b5c21a03a3',
    messagingSenderId: '20213020186',
    projectId: 'noblora-8cbc0',
    storageBucket: 'noblora-8cbc0.firebasestorage.app',
    iosBundleId: 'com.noblara.noblaraFlutter',
  );
}
