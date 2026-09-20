// Firebase client configuration for this project.
//
// Derived from android/app/google-services.json, from
// ios/Runner/GoogleService-Info.plist, and from the web app registered in the
// Firebase console. `flutterfire configure` overwrites this file, which is the
// intended way to regenerate it once that CLI is installed.
//
// These values are client identifiers, not secrets. Access is controlled by
// Firebase Auth and by the Firestore and Storage security rules.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform. Only Android '
          'and iOS have apps registered in this Firebase project.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCKsAkpP948nAEWJVcKuFl6IUqDuplajhg',
    appId: '1:621918723863:web:d9e5a62582ac00214a2152',
    messagingSenderId: '621918723863',
    projectId: 'grocery-accounting-993ed',
    authDomain: 'grocery-accounting-993ed.firebaseapp.com',
    storageBucket: 'grocery-accounting-993ed.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyALAJgCtgY9p9quvd-6sx-nDClCMccFIyo',
    appId: '1:621918723863:android:d2ad6d708dc8c7cb4a2152',
    messagingSenderId: '621918723863',
    projectId: 'grocery-accounting-993ed',
    storageBucket: 'grocery-accounting-993ed.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB9IqRJ3YJWmYDScJe6dXtK5mjYP3Jo5iQ',
    appId: '1:621918723863:ios:0826c744bb9162f44a2152',
    messagingSenderId: '621918723863',
    projectId: 'grocery-accounting-993ed',
    storageBucket: 'grocery-accounting-993ed.firebasestorage.app',
    iosBundleId: 'com.example.groceryAccounting',
  );
}
