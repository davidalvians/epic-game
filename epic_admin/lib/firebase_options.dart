// File ini di-generate oleh FlutterFire CLI untuk project EPIC App (Production).
// Jangan edit secara manual. Gunakan: flutterfire configure
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Konfigurasi Firebase untuk project EPIC App — epic-app1 (Production).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS belum dikonfigurasi. Jalankan flutterfire configure untuk iOS.',
        );
      case TargetPlatform.windows:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions tidak dikonfigurasi untuk platform ini.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDy1r3W0aSVpuvbD8bWt-G2p04mxF37QoE',
    appId: '1:745796494398:web:5e5eb55bcc5744b70f5d6f',
    messagingSenderId: '745796494398',
    projectId: 'epic-app1',
    authDomain: 'epic-app1.firebaseapp.com',
    storageBucket: 'epic-app1.firebasestorage.app',
    measurementId: 'G-ZWG47Q08BB',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBmhhz1N_bFZFJsKhSgtD1fl1kGecOC7xk',
    appId: '1:745796494398:android:e25798652ff972bf0f5d6f',
    messagingSenderId: '745796494398',
    projectId: 'epic-app1',
    storageBucket: 'epic-app1.firebasestorage.app',
  );
}
