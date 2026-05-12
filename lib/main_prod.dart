import 'bootstrap.dart';
import 'config/ad_config.dart';
import 'firebase_options.dart';

void main() => bootstrap(
      firebaseOptions: DefaultFirebaseOptions.currentPlatform,
      adConfig: AdConfig.prod(),
      isDev: false,
    );
