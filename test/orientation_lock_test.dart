import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Guards against a recurring regression: someone enables a single landscape
// orientation somewhere in the stack (often re-adding a default) and the
// app starts shipping with broken layouts because each game canvas
// assumes portrait. The lock has to be consistent across THREE places:
//
//   1. Flutter:  SystemChrome.setPreferredOrientations(...)  in bootstrap.dart
//   2. iOS:      UISupportedInterfaceOrientations            in Info.plist
//   3. Android:  android:screenOrientation                   in AndroidManifest
//
// This test reads each file as text and asserts the relevant lines are
// present and the forbidden ones absent. If any layer drifts, CI fails
// here long before TestFlight / Play Console rejects the build.

void main() {
  group('Orientation lock', () {
    test('Flutter bootstrap locks portrait', () {
      final bootstrap =
          File('lib/bootstrap.dart').readAsStringSync();
      expect(
        bootstrap.contains(
          'setPreferredOrientations([DeviceOrientation.portraitUp])',
        ),
        isTrue,
        reason:
            'bootstrap.dart must call setPreferredOrientations([portraitUp]) '
            'before runApp so the very first frame is portrait-locked.',
      );
    });

    test('iOS Info.plist allows portrait only', () {
      final plist =
          File('ios/Runner/Info.plist').readAsStringSync();
      // The iPhone block (UISupportedInterfaceOrientations, NOT ~ipad)
      // must contain Portrait and nothing else.
      final phoneStart =
          plist.indexOf('<key>UISupportedInterfaceOrientations</key>');
      expect(phoneStart, greaterThan(-1),
          reason: 'Missing UISupportedInterfaceOrientations key');
      final phoneEnd = plist.indexOf('</array>', phoneStart);
      final phoneSection = plist.substring(phoneStart, phoneEnd);
      expect(
        phoneSection.contains('UIInterfaceOrientationLandscapeLeft'),
        isFalse,
        reason:
            'iPhone block in Info.plist must not allow LandscapeLeft. App '
            'is portrait-only; allowing landscape lets iOS show the splash '
            'sideways and rejects the App Store submission for inconsistency.',
      );
      expect(
        phoneSection.contains('UIInterfaceOrientationLandscapeRight'),
        isFalse,
        reason: 'iPhone block must not allow LandscapeRight.',
      );
      expect(
        phoneSection.contains('UIInterfaceOrientationPortrait'),
        isTrue,
        reason: 'iPhone block must allow Portrait.',
      );
    });

    test('iOS iPad orientations are portrait variants only', () {
      final plist =
          File('ios/Runner/Info.plist').readAsStringSync();
      final ipadStart =
          plist.indexOf('<key>UISupportedInterfaceOrientations~ipad</key>');
      expect(ipadStart, greaterThan(-1),
          reason: 'Missing UISupportedInterfaceOrientations~ipad key');
      final ipadEnd = plist.indexOf('</array>', ipadStart);
      final ipadSection = plist.substring(ipadStart, ipadEnd);
      expect(
        ipadSection.contains('Landscape'),
        isFalse,
        reason:
            'iPad block must not include any Landscape value (no '
            'LandscapeLeft, LandscapeRight, or anything else).',
      );
    });

    test('Android manifest locks MainActivity to portrait', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(
        manifest.contains('android:screenOrientation="portrait"'),
        isTrue,
        reason:
            'AndroidManifest.xml must set android:screenOrientation="portrait" '
            'on the MainActivity so the OS never tries to lay it out in '
            'landscape (including the launch splash).',
      );
    });
  });
}
