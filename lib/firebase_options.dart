// PROD Firebase options — generated via flutterfire configure --project=puzzloragames-minivo
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for '
          '${defaultTargetPlatform.name}',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyAC08PVjE_HW-9LnXuGfYhxxG-VH509EIg',
    appId:             '1:168184149016:android:761ca8de9e282d37853f6d',
    messagingSenderId: '168184149016',
    projectId:         'puzzloragames-minivo',
    storageBucket:     'puzzloragames-minivo.firebasestorage.app',
  );

  // iOS credentials — run: gem install xcodeproj && flutterfire configure --project=puzzloragames-minivo

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD5ZY4nXO_YB3buSwNcX1p9JTvmjNS1u4c',
    appId: '1:168184149016:ios:0cb9331203ee8520853f6d',
    messagingSenderId: '168184149016',
    projectId: 'puzzloragames-minivo',
    storageBucket: 'puzzloragames-minivo.firebasestorage.app',
    iosBundleId: 'com.puzzloragames.dropzy',
  );

  // then copy apiKey and appId from the generated GoogleService-Info.plist
}