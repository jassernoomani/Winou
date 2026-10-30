import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeKey = 'theme';
const _languageKey = 'language';
const _welcomeKey = 'welcome_seen';

/// Choices kept on the phone: theme, language, and whether the welcome screens were seen.
class Preferences {
  const Preferences({this.themeMode = ThemeMode.system, this.language, this.welcomeSeen = false});

  final ThemeMode themeMode;
  final String? language; // "en", "fr"; null: the phone's language
  final bool welcomeSeen;

  Locale? get locale => language == null ? null : Locale(language!);

  Preferences copyWith({ThemeMode? themeMode, String? Function()? language, bool? welcomeSeen}) => Preferences(
    themeMode: themeMode ?? this.themeMode,
    language: language != null ? language() : this.language,
    welcomeSeen: welcomeSeen ?? this.welcomeSeen,
  );
}

/// Read before runApp, so the first frame already has the right theme and language.
Preferences _loaded = const Preferences();
SharedPreferences? _store;

Future<void> loadPreferences() async {
  try {
    final store = _store = await SharedPreferences.getInstance();
    _loaded = Preferences(
      themeMode: ThemeMode.values.asNameMap()[store.getString(_themeKey)] ?? ThemeMode.system,
      language: store.getString(_languageKey),
      welcomeSeen: store.getBool(_welcomeKey) ?? false,
    );
  } catch (_) {
    // Unreadable storage: the defaults
  }
}

class PreferencesController extends Notifier<Preferences> {
  @override
  Preferences build() => _loaded;

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _store?.setString(_themeKey, mode.name);
  }

  /// null: follow the phone.
  void setLanguage(String? language) {
    state = state.copyWith(language: () => language);
    language == null ? _store?.remove(_languageKey) : _store?.setString(_languageKey, language);
  }

  void welcomeDone() {
    state = state.copyWith(welcomeSeen: true);
    _store?.setBool(_welcomeKey, true);
  }
}

final preferencesProvider = NotifierProvider<PreferencesController, Preferences>(PreferencesController.new);
