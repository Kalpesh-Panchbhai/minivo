// DEV Firebase options — generated via flutterfire configure --project=puzzloragames-minivo-dev
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DevFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DevFirebaseOptions are not configured for '
          '${defaultTargetPlatform.name}',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyDeeGkEQjRe7dxeliwfTURi3Lykl7zTZYQ',
    appId:             '1:1030228829143:android:cda7e5d380a47904772192',
    messagingSenderId: '1030228829143',
    projectId:         'puzzloragames-minivo-dev',
    storageBucket:     'puzzloragames-minivo-dev.firebasestorage.app',
  );

  // iOS credentials — run: gem install xcodeproj && flutterfire configure --project=puzzloragames-minivo-dev

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDqkhlLmz8PCTIphQovyG9kASV1jwhgr-s',
    appId: '1:1030228829143:ios:60d6a4eb3fdf290f772192',
    messagingSenderId: '1030228829143',
    projectId: 'puzzloragames-minivo-dev',
    storageBucket: 'puzzloragames-minivo-dev.firebasestorage.app',
    iosBundleId: 'com.puzzloragames.dropzy',
  );

  // then copy iosBundleId, apiKey and appId from the generated GoogleService-Info.plist
}