import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeKey = 'theme';
const _languageKey = 'language';
const _welcomeKey = 'welcome_seen';
const _feedKey = 'feed_layout';

/// How the home screen shows lost pets: big cards, a compact list, or a grid of photos.
enum FeedLayout { cards, list, grid }

/// Choices kept on the phone: theme, language, and whether the welcome screens were seen.
class Preferences {
  const Preferences({
    this.themeMode = ThemeMode.system,
    this.language,
    this.welcomeSeen = false,
    this.feedLayout = FeedLayout.cards,
  });

  final ThemeMode themeMode;
  final String? language; // "en", "fr", "ar"; null: the phone's language
  final bool welcomeSeen;
  final FeedLayout feedLayout;

  Locale? get locale => language == null ? null : Locale(language!);

  Preferences copyWith({
    ThemeMode? themeMode,
    String? Function()? language,
    bool? welcomeSeen,
    FeedLayout? feedLayout,
  }) => Preferences(
    themeMode: themeMode ?? this.themeMode,
    language: language != null ? language() : this.language,
    welcomeSeen: welcomeSeen ?? this.welcomeSeen,
    feedLayout: feedLayout ?? this.feedLayout,
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
      feedLayout: FeedLayout.values.asNameMap()[store.getString(_feedKey)] ?? FeedLayout.cards,
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

  void setFeedLayout(FeedLayout layout) {
    state = state.copyWith(feedLayout: layout);
    _store?.setString(_feedKey, layout.name);
  }

  void welcomeDone() {
    state = state.copyWith(welcomeSeen: true);
    _store?.setBool(_welcomeKey, true);
  }
}

final preferencesProvider = NotifierProvider<PreferencesController, Preferences>(PreferencesController.new);
