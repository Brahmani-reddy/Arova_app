import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAfcc2eKRwQ8gQ3ML6Mo5HcxptYeSOvIJk',
    appId: '1:70253499417:web:f8c29e612edb65ce398688',
    messagingSenderId: '70253499417',
    projectId: 'arova1',
    authDomain: 'arova1.firebaseapp.com',
    storageBucket: 'arova1.firebasestorage.app',
    measurementId: 'G-20MFRTLNL9',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDzs9JX8StxzNza1K4it6SmoR--0UDXG_s',
    appId: '1:70253499417:android:e53fb0a0a32c4d8e398688',
    messagingSenderId: '70253499417',
    projectId: 'arova1',
    storageBucket: 'arova1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD9J4xVny-FCjF1Sg-oEVv9485XB6yH42E',
    appId: '1:70253499417:ios:67b6e9c9777222ff398688',
    messagingSenderId: '70253499417',
    projectId: 'arova1',
    storageBucket: 'arova1.firebasestorage.app',
    iosBundleId: 'com.example.arova',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD9J4xVny-FCjF1Sg-oEVv9485XB6yH42E',
    appId: '1:70253499417:ios:67b6e9c9777222ff398688',
    messagingSenderId: '70253499417',
    projectId: 'arova1',
    storageBucket: 'arova1.firebasestorage.app',
    iosBundleId: 'com.example.arova',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAfcc2eKRwQ8gQ3ML6Mo5HcxptYeSOvIJk',
    appId: '1:70253499417:web:294efdad90f0ca4e398688',
    messagingSenderId: '70253499417',
    projectId: 'arova1',
    authDomain: 'arova1.firebaseapp.com',
    storageBucket: 'arova1.firebasestorage.app',
    measurementId: 'G-TLBF3LDMNK',
  );
}