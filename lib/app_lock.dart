import 'dart:async';

import 'package:flutter/material.dart';

import 'app_settings.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.settings,
    required this.authenticator,
    required this.child,
  });

  final AppSettingsController settings;
  final BiometricAuthenticator authenticator;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  late bool _wasEnabled;
  late bool _locked;
  bool _authenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasEnabled = widget.settings.appLockEnabled;
    _locked = _wasEnabled;
    widget.settings.addListener(_settingsChanged);
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_settingsChanged);
    super.dispose();
  }

  void _settingsChanged() {
    final enabled = widget.settings.appLockEnabled;
    if (!enabled) {
      _locked = false;
      _error = null;
    } else if (!_wasEnabled) {
      // Enabling the setting already required a successful biometric check.
      _locked = false;
      _error = null;
    }
    _wasEnabled = enabled;
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.settings.appLockEnabled) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (_locked) unawaited(_unlock());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Lock as soon as the app leaves the foreground. Locking already on
        // `inactive` matters: the OS app-switcher snapshot is taken while the
        // app is paused (when no more frames render), so the lock screen must
        // have been composited during the `inactive` phase to cover the
        // snapshot. Locking must not be skipped while an authentication
        // prompt is visible: if the user backgrounds the app mid-prompt, the
        // app must still require a fresh unlock on return.
        if (mounted) {
          setState(() {
            _locked = true;
            _error = null;
          });
        }
      case AppLifecycleState.detached:
        // The engine is going away; nothing to lock.
        break;
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || !widget.settings.appLockEnabled) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    final authenticated = await widget.authenticator.authenticate(
      reason: 'Unlock Listor',
    );
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _locked = !authenticated;
      _error = authenticated ? null : 'Fingerprint not recognized';
    });
  }

  @override
  Widget build(BuildContext context) {
    // `widget.child` must stay in the tree at all times. Swapping it out for
    // the lock screen would dispose the home page's state, resetting the
    // selected destination, tabs, and feeds when the app is unlocked.
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Scaffold(
              key: const Key('app-lock-screen'),
              backgroundColor: const Color(0xFF05070A),
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fingerprint_rounded,
                          size: 72,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Listor is locked',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error ?? 'Use your fingerprint to continue.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          key: const Key('unlock-app'),
                          onPressed: _authenticating ? null : _unlock,
                          icon: _authenticating
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.fingerprint_rounded),
                          label: Text(
                            _authenticating ? 'Checking…' : 'Unlock',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
