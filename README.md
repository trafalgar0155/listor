# Listor

A focused phone reading-list interface built with Flutter and Material 3.

## Current UI

- Floating filter action with a category, time range, and multi-select tags
- Swipeable New, Popular, and Random feeds
- Live story metadata from the HTTP API wrapped by `LiteroticaApi 2.1.0`
- Compact, high-density story list
- In-app multi-page story reader with the source HTML formatting preserved
- Dark black-and-blue visual theme

The NuGet assembly cannot run inside Flutter, so Listor implements its public
`https://literotica.com/api/3` request contract in Dart. The initial category is
**Non Erotic** (API category `35`). Available tags refresh for the selected
category and period and are displayed alphabetically. New selects the newest
category page, Popular uses the API's `popular` filter, and Random samples a
category page.

## Run locally

```sh
flutter pub get
flutter run
```

Run checks with `flutter analyze` and `flutter test`.
