import 'package:flutter_test/flutter_test.dart';
import 'package:listor/app_settings.dart';
import 'package:listor/literotica_api.dart';
import 'package:listor/reading_history.dart';

void main() {
  test('settings controller loads and persists both settings', () async {
    final repository = _SettingsRepository(
      historyEnabled: false,
      appLockEnabled: true,
    );
    final controller = AppSettingsController(repository);
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.isLoaded, isTrue);
    expect(controller.historyEnabled, isFalse);
    expect(controller.appLockEnabled, isTrue);

    await controller.setHistoryEnabled(true);
    await controller.setAppLockEnabled(false);
    expect(repository.historyEnabled, isTrue);
    expect(repository.appLockEnabled, isFalse);
  });

  test('disabled history neither records nor resumes progress', () async {
    final repository = _HistoryRepository();
    final history = ReadingHistoryViewModel(repository, enabled: false);
    addTearDown(history.dispose);

    await history.record(_story, pageIndex: 2, pageCount: 3);
    expect(repository.entries, isEmpty);
    expect(await history.resumePage(_story.id, 3), 0);

    history.setEnabled(true);
    await history.record(_story, pageIndex: 2, pageCount: 3);
    expect(repository.entries.single.pageIndex, 2);
    expect(await history.resumePage(_story.id, 3), 2);
  });
}

class _SettingsRepository implements AppSettingsRepository {
  _SettingsRepository({
    required this.historyEnabled,
    required this.appLockEnabled,
  });

  bool historyEnabled;
  bool appLockEnabled;

  @override
  Future<bool> readAppLockEnabled() async => appLockEnabled;

  @override
  Future<bool> readHistoryEnabled() async => historyEnabled;

  @override
  Future<void> writeAppLockEnabled(bool enabled) async {
    appLockEnabled = enabled;
  }

  @override
  Future<void> writeHistoryEnabled(bool enabled) async {
    historyEnabled = enabled;
  }
}

class _HistoryRepository implements ReadingHistoryRepository {
  final entries = <ReadingHistoryEntry>[];

  @override
  Future<void> clear() async => entries.clear();

  @override
  Future<List<ReadingHistoryEntry>> readAll() async => List.of(entries);

  @override
  Future<void> remove(int storyId) async {
    entries.removeWhere((entry) => entry.story.id == storyId);
  }

  @override
  Future<void> save(ReadingHistoryEntry entry) async {
    entries.removeWhere((item) => item.story.id == entry.story.id);
    entries.add(entry);
  }
}

final _story = ListorItem(
  id: 7,
  title: 'History Test',
  description: 'A test story.',
  category: ListorCategory.nonErotic,
  author: 'Test Author',
  approvedAt: DateTime(2026, 9, 29),
  favoriteCount: 0,
  rating: 4,
  url: Uri.parse('https://www.literotica.com/s/history-test'),
);
