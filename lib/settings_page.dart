import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'reading_history.dart';

class SettingsDestination extends StatelessWidget {
  const SettingsDestination({
    super.key,
    required this.settings,
    required this.history,
    required this.authenticator,
  });

  final AppSettingsController settings;
  final ReadingHistoryViewModel history;
  final BiometricAuthenticator authenticator;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: Listenable.merge([settings, history]),
        builder: (context, _) => ListView(
          key: const Key('settings-list'),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            _SectionCard(
              title: 'Reading history',
              children: [
                SwitchListTile(
                  key: const Key('history-setting'),
                  secondary: const Icon(Icons.history_rounded),
                  title: const Text('Save reading history'),
                  subtitle: const Text(
                    'Remember opened stories and the last page you read.',
                  ),
                  value: settings.historyEnabled,
                  onChanged: (enabled) async {
                    history.setEnabled(enabled);
                    await settings.setHistoryEnabled(enabled);
                  },
                ),
                ListTile(
                  key: const Key('clear-history-setting'),
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: const Text('Clear history'),
                  subtitle: const Text('Remove all saved reading progress.'),
                  enabled: history.entries.isNotEmpty,
                  onTap: history.entries.isEmpty
                      ? null
                      : () => _confirmClearHistory(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'App lock',
              children: [
                SwitchListTile(
                  key: const Key('app-lock-setting'),
                  secondary: const Icon(Icons.fingerprint_rounded),
                  title: const Text('Fingerprint lock'),
                  subtitle: const Text(
                    'Require an enrolled biometric whenever Listor is opened.',
                  ),
                  value: settings.appLockEnabled,
                  onChanged: (enabled) => _changeAppLock(context, enabled),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear reading history?'),
        content: const Text('This removes all saved reading progress.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-clear-history-setting'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) await history.clear();
  }

  Future<void> _changeAppLock(BuildContext context, bool enabled) async {
    if (!enabled) {
      await settings.setAppLockEnabled(false);
      return;
    }

    final available = await authenticator.hasEnrolledBiometrics();
    if (!context.mounted) return;
    if (!available) {
      _showMessage(
        context,
        'Set up a fingerprint or biometric in your device settings first.',
      );
      return;
    }

    final authenticated = await authenticator.authenticate(
      reason: 'Confirm your fingerprint to enable Listor app lock',
    );
    if (!context.mounted) return;
    if (!authenticated) {
      _showMessage(context, 'App lock was not enabled.');
      return;
    }
    await settings.setAppLockEnabled(true);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }
}
