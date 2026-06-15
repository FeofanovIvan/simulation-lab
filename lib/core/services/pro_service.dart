import 'package:shared_preferences/shared_preferences.dart';

class ProService {
  static const _proKey = "is_pro";
  static const _freeKey = "free_attempts";

  bool isPro = false;
  int freeAttemptsLeft = 1;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isPro = prefs.getBool(_proKey) ?? false;
    freeAttemptsLeft = prefs.getInt(_freeKey) ?? 1;
  }

  Future<void> activatePro() async {
    final prefs = await SharedPreferences.getInstance();
    isPro = true;
    await prefs.setBool(_proKey, true);
  }

  Future<void> useFreeAttempt() async {
    if (freeAttemptsLeft > 0) {
      freeAttemptsLeft--;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_freeKey, freeAttemptsLeft);
    }
  }
}
