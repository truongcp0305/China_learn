import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool onboarded;
  final String hskLevel;
  final int dailyGoal;
  final String targetHskLevel;
  final ThemeMode themeMode;
  final bool notifyEnabled;
  final int notifyHour;
  final int notifyMinute;

  const AppSettings({
    required this.onboarded,
    required this.hskLevel,
    required this.dailyGoal,
    required this.targetHskLevel,
    required this.themeMode,
    required this.notifyEnabled,
    required this.notifyHour,
    required this.notifyMinute,
  });

  static const _defaultHskLevel = '1';
  static const _defaultDailyGoal = 20;
  static const _defaultTargetHskLevel = '3';

  AppSettings copyWith({
    bool? onboarded,
    String? hskLevel,
    int? dailyGoal,
    String? targetHskLevel,
    ThemeMode? themeMode,
    bool? notifyEnabled,
    int? notifyHour,
    int? notifyMinute,
  }) {
    return AppSettings(
      onboarded: onboarded ?? this.onboarded,
      hskLevel: hskLevel ?? this.hskLevel,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      targetHskLevel: targetHskLevel ?? this.targetHskLevel,
      themeMode: themeMode ?? this.themeMode,
      notifyEnabled: notifyEnabled ?? this.notifyEnabled,
      notifyHour: notifyHour ?? this.notifyHour,
      notifyMinute: notifyMinute ?? this.notifyMinute,
    );
  }

  static const initial = AppSettings(
    onboarded: false,
    hskLevel: _defaultHskLevel,
    dailyGoal: _defaultDailyGoal,
    targetHskLevel: _defaultTargetHskLevel,
    themeMode: ThemeMode.system,
    notifyEnabled: false,
    notifyHour: 20,
    notifyMinute: 0,
  );
}

const _kOnboarded = 'onboarded';
const _kHskLevel = 'hsk_level';
const _kDailyGoal = 'daily_goal';
const _kTargetHskLevel = 'target_hsk_level';
const _kThemeMode = 'theme_mode';
const _kNotifyEnabled = 'notify_enabled';
const _kNotifyHour = 'notify_hour';
const _kNotifyMinute = 'notify_minute';

ThemeMode _themeModeFromString(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

String _themeModeToString(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      onboarded: prefs.getBool(_kOnboarded) ?? false,
      hskLevel: prefs.getString(_kHskLevel) ?? AppSettings.initial.hskLevel,
      dailyGoal: prefs.getInt(_kDailyGoal) ?? AppSettings.initial.dailyGoal,
      targetHskLevel: prefs.getString(_kTargetHskLevel) ?? AppSettings.initial.targetHskLevel,
      themeMode: _themeModeFromString(prefs.getString(_kThemeMode)),
      notifyEnabled: prefs.getBool(_kNotifyEnabled) ?? AppSettings.initial.notifyEnabled,
      notifyHour: prefs.getInt(_kNotifyHour) ?? AppSettings.initial.notifyHour,
      notifyMinute: prefs.getInt(_kNotifyMinute) ?? AppSettings.initial.notifyMinute,
    );
  }

  Future<void> completeOnboarding({required String hskLevel, required int dailyGoal}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarded, true);
    await prefs.setString(_kHskLevel, hskLevel);
    await prefs.setInt(_kDailyGoal, dailyGoal);
    state = AsyncData((state.value ?? AppSettings.initial).copyWith(
      onboarded: true,
      hskLevel: hskLevel,
      dailyGoal: dailyGoal,
    ));
  }

  Future<void> setTargetHskLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTargetHskLevel, level);
    state = AsyncData((state.value ?? AppSettings.initial).copyWith(targetHskLevel: level));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, _themeModeToString(mode));
    state = AsyncData((state.value ?? AppSettings.initial).copyWith(themeMode: mode));
  }

  Future<void> setNotifyEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifyEnabled, enabled);
    state = AsyncData((state.value ?? AppSettings.initial).copyWith(notifyEnabled: enabled));
  }

  Future<void> setNotifyTime({required int hour, required int minute}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNotifyHour, hour);
    await prefs.setInt(_kNotifyMinute, minute);
    state = AsyncData((state.value ?? AppSettings.initial).copyWith(notifyHour: hour, notifyMinute: minute));
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
