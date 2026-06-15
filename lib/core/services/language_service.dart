import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {

  static const _key = "app_language";

  static Future<void> saveLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }

  static Future<String?> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }
}