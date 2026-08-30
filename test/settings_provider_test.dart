import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iptv_xtream/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsProvider & Font Scaling Tests', () {
    test('Default font size level is 1 with textScaleFactor 1.0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final settings = container.read(settingsProvider);
      final fontScale = container.read(fontSizeScaleProvider);

      expect(settings.fontSizeLevel, 1);
      expect(settings.fontSizeLabel, 'Standard');
      expect(fontScale, 1.0);
    });

    test('Updating font size to level 2 gives 1.25x scale factor', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).setFontSizeLevel(2);

      final settings = container.read(settingsProvider);
      final fontScale = container.read(fontSizeScaleProvider);

      expect(settings.fontSizeLevel, 2);
      expect(settings.fontSizeLabel, 'Medium');
      expect(fontScale, 1.25);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('font_size_level'), 2);
    });

    test('Updating font size to level 3 gives 1.50x scale factor', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).setFontSizeLevel(3);

      final settings = container.read(settingsProvider);
      final fontScale = container.read(fontSizeScaleProvider);

      expect(settings.fontSizeLevel, 3);
      expect(settings.fontSizeLabel, 'Large');
      expect(fontScale, 1.50);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('font_size_level'), 3);
    });

    test('Font size level is clamped between 1 and 3', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).setFontSizeLevel(5);
      expect(container.read(settingsProvider).fontSizeLevel, 3);
      expect(container.read(fontSizeScaleProvider), 1.50);

      await container.read(settingsProvider.notifier).setFontSizeLevel(0);
      expect(container.read(settingsProvider).fontSizeLevel, 1);
      expect(container.read(fontSizeScaleProvider), 1.0);
    });
  });
}
