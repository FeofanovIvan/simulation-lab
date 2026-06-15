import 'package:flutter/material.dart';
import 'app_localization.dart';

class LanguageProvider extends ChangeNotifier {

  String currentLanguage = AppLocalization.currentLanguage;

  Future<void> changeLanguage(String code) async {

    if (code == currentLanguage) return;

    await AppLocalization.load(code);

    currentLanguage = code;

    notifyListeners();
  }
}