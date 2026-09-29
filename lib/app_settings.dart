import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AppSettingsRepository {
  Future<bool> readHistoryEnabled();
  Future<bool> readAppLockEnabled();
  Future<void> writeHistoryEnabled(bool enabled);
  Future<void> writeAppLockEnabled(bool enabled);
}

class SharedPreferencesAppSettingsRepository implements AppSettingsRepository {
  static const _historyEnabledKey = 'history_enabled';
  static const _appLockEnabledKey = 'app_lock_enabled';

  @override
  Future<bool> readHistoryEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_historyEnabledKey) ?? true;
  }

  @override
  Future<bool> readAppLockEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_appLockEnabledKey) ?? false;
  }

  @override
  Future<void> writeHistoryEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_historyEnabledKey, enabled);
  }

  @override
  Future<void> writeAppLockEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_appLockEnabledKey, enabled);
  }
}

class AppSettingsController extends ChangeNotifier {
  AppSettingsController(this._repository);

  final AppSettingsRepository _repository;
  bool _historyEnabled = true;
  bool _appLockEnabled = false;
  bool _isLoaded = false;
  Object? _loadError;

  bool get historyEnabled => _historyEnabled;
  bool get appLockEnabled => _appLockEnabled;
  bool get isLoaded => _isLoaded;
  Object? get loadError => _loadError;

  Future<void> load() async {
    _loadError = null;
    try {
      final values = await Future.wait([
        _repository.readHistoryEnabled(),
        _repository.readAppLockEnabled(),
      ]);
      _historyEnabled = values[0];
      _appLockEnabled = values[1];
      _isLoaded = true;
    } catch (error) {
      _loadError = error;
    }
    notifyListeners();
  }

  Future<void> setHistoryEnabled(bool enabled) async {
    if (_historyEnabled == enabled) return;
    _historyEnabled = enabled;
    notifyListeners();
    await _repository.writeHistoryEnabled(enabled);
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    if (_appLockEnabled == enabled) return;
    _appLockEnabled = enabled;
    notifyListeners();
    await _repository.writeAppLockEnabled(enabled);
  }
}

abstract interface class BiometricAuthenticator {
  Future<bool> hasEnrolledBiometrics();
  Future<bool> authenticate({required String reason});
}

class LocalBiometricAuthenticator implements BiometricAuthenticator {
  LocalBiometricAuthenticator({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> hasEnrolledBiometrics() async {
    try {
      if (!await _authentication.canCheckBiometrics) return false;
      return (await _authentication.getAvailableBiometrics()).isNotEmpty;
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _authentication.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }
}
