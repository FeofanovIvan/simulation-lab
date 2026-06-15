import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:simulation_lab/core/services/language_service.dart';

import 'app_language.dart';

class AppLocalization {

  static String currentLanguage = "en";

  static Map<String, dynamic> _localizedStrings = {};
  static Map<String, dynamic> _fallbackStrings = {};

  /// загрузка конкретного языка
  static Future<void> load(String languageCode) async {

    currentLanguage = languageCode;

    final jsonString = await rootBundle.loadString(
      'assets/lang/$languageCode.json',
    );

    _localizedStrings = json.decode(jsonString);

    /// fallback english
    final fallback = await rootBundle.loadString(
      'assets/lang/en.json',
    );

    _fallbackStrings = json.decode(fallback);
  }

  /// получение перевода
  static String t(String key) {

    return _localizedStrings[key]
        ?? _fallbackStrings[key]
        ?? key;
  }

  /// автоопределение языка телефона
  static Future<void> loadDeviceLanguage() async {

  /// 1 проверяем сохраненный язык
  final saved = await LanguageService.loadLanguage();

  if (saved != null) {
    await load(saved);
    return;
  }

  /// 2 иначе язык телефона
  final deviceLang =
      PlatformDispatcher.instance.locale.languageCode;

  final supported =
      languages.map((e) => e.code).toList();

  if (supported.contains(deviceLang)) {
    await load(deviceLang);
  } else {
    await load("en");
  }
}
}