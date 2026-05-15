import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/home/main_shell.dart';
import '../../lib/features/home/home_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

// MainShell is now a thin wrapper around HomeScreen — no bottom nav,
// no tab state. These tests cover the wrapper contract (renders without
// overflow on every supported device) and verify the delegation hasn't
// regressed. Per-screen behavior is covered in home_screen_test.dart.
void main() {
  for (final device in allTestDevices) {
    group('MainShell on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders without overflow', (tester) async {
        await pumpScreen(tester, device, const MainShell());
        expectNoOverflow(device, 'MainShell');
        cleanUp(tester);
      });

      testWidgets('delegates to HomeScreen', (tester) async {
        await pumpScreen(tester, device, const MainShell());
        expect(find.byType(HomeScreen), findsOneWidget);
        cleanUp(tester);
      });
    });
  }
}
