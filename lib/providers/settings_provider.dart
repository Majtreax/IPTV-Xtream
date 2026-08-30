import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final int fontSizeLevel; // 1 = STANDARD (1.0X), 2 = MEDIUM (1.25X), 3 = LARGE (1.50X)

  const SettingsState({this.fontSizeLevel = 1});

  double get textScaleFactor {
    switch (fontSizeLevel) {
      case 2:
        return 1.25;
      case 3:
        return 1.50;
      case 1:
      default:
        return 1.0;
    }
  }

  String get fontSizeLabel {
    switch (fontSizeLevel) {
      case 2:
        return 'Medium';
      case 3:
        return 'Large';
      case 1:
      default:
        return 'Standard';
    }
  }

  SettingsState copyWith({int? fontSizeLevel}) {
    return SettingsState(
      fontSizeLevel: fontSizeLevel ?? this.fontSizeLevel,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
      return SettingsNotifier();
    });

final fontSizeScaleProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider).textScaleFactor;
});

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const String _kFontSizeKey = 'font_size_level';

  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLevel = prefs.getInt(_kFontSizeKey) ?? 1;
      final clampedLevel = savedLevel.clamp(1, 3);
      state = state.copyWith(fontSizeLevel: clampedLevel);
    } catch (_) {
      // USE DEFAULT STATE IF READING PREFERENCES FAILS
    }
  }

  Future<void> setFontSizeLevel(int level) async {
    final clampedLevel = level.clamp(1, 3);
    state = state.copyWith(fontSizeLevel: clampedLevel);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kFontSizeKey, clampedLevel);
    } catch (_) {
      // IGNORE
    }
  }
}
