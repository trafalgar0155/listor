import 'package:flutter/material.dart';

import 'favorites.dart';
import 'listor_home.dart';
import 'literotica_api.dart';
import 'local_story_store.dart';

void main() {
  runApp(const ListorApp());
}

class ListorApp extends StatelessWidget {
  const ListorApp({
    super.key,
    this.repository,
    this.savedStoriesRepository,
    this.favoritesRepository,
  });

  final StoryRepository? repository;
  final SavedStoriesRepository? savedStoriesRepository;
  final FavoritesRepository? favoritesRepository;

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
      home: ListorHomePage(
        repository: repository,
        savedStoriesRepository: savedStoriesRepository,
        favoritesRepository: favoritesRepository,
      ),
    );
  }
}
