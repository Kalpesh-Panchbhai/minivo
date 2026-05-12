import 'bootstrap.dart';
import 'config/ad_config.dart';
import 'firebase_options_dev.dart';

void main() => bootstrap(
      firebaseOptions: DevFirebaseOptions.currentPlatform,
      adConfig: AdConfig.test(),
      isDev: true,
    );
