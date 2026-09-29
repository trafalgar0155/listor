import 'package:flutter/material.dart';

import 'app_lock.dart';
import 'app_settings.dart';
import 'favorites.dart';
import 'listor_home.dart';
import 'literotica_api.dart';
import 'local_story_store.dart';
import 'reading_history.dart';

void main() {
  runApp(const ListorApp());
}

class ListorApp extends StatefulWidget {
  const ListorApp({
    super.key,
    this.repository,
    this.savedStoriesRepository,
    this.favoritesRepository,
    this.historyRepository,
    this.settingsRepository,
    this.biometricAuthenticator,
  });

  final StoryRepository? repository;
  final SavedStoriesRepository? savedStoriesRepository;
  final FavoritesRepository? favoritesRepository;
  final ReadingHistoryRepository? historyRepository;
  final AppSettingsRepository? settingsRepository;
  final BiometricAuthenticator? biometricAuthenticator;

  @override
  State<ListorApp> createState() => _ListorAppState();
}

class _ListorAppState extends State<ListorApp> {
  late final AppSettingsController _settings;
  late final BiometricAuthenticator _authenticator;

  @override
  void initState() {
    super.initState();
    _settings = AppSettingsController(
      widget.settingsRepository ?? SharedPreferencesAppSettingsRepository(),
    );
    _authenticator =
        widget.biometricAuthenticator ?? LocalBiometricAuthenticator();
    _settings.load();
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  static const _blue = Color(0xFF2693FF);
  static const _background = Color(0xFF05070A);
  static const _surface = Color(0xFF0D1117);

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _blue,
      brightness: Brightness.dark,
      surface: _surface,
    );

    return MaterialApp(
      title: 'Listor',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: _background,
        canvasColor: _background,
        splashFactory: InkSparkle.splashFactory,
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: _surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF202934)),
          ),
        ),
        dividerColor: const Color(0xFF202934),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: const Color(0xFFE6EDF3),
          displayColor: Colors.white,
        ),
      ),
      home: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) {
          if (!_settings.isLoaded) {
            return Scaffold(
              body: Center(
                child: _settings.loadError == null
                    ? const CircularProgressIndicator()
                    : FilledButton.tonalIcon(
                        onPressed: _settings.load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry loading settings'),
                      ),
              ),
            );
          }
          return AppLockGate(
            settings: _settings,
            authenticator: _authenticator,
            child: ListorHomePage(
              repository: widget.repository,
              savedStoriesRepository: widget.savedStoriesRepository,
              favoritesRepository: widget.favoritesRepository,
              historyRepository: widget.historyRepository,
              settings: _settings,
              biometricAuthenticator: _authenticator,
            ),
          );
        },
      ),
    );
  }
}
