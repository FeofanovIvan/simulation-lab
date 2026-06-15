import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SimulationService extends ChangeNotifier {
  static const _proKey = "is_pro";
  static const _freeUsedKey = "free_simulation_used";

  bool _isProUser = false;
  bool _isFreeSimulationUsed = false;

  bool get isProUser => _isProUser;
  bool get isFreeSimulationUsed => _isFreeSimulationUsed;

  SimulationService() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isProUser = prefs.getBool(_proKey) ?? false;
    _isFreeSimulationUsed = prefs.getBool(_freeUsedKey) ?? false;
    notifyListeners();
  }

  Future<void> activatePro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proKey, true);
    _isProUser = true;
    notifyListeners();
  }

  Future<void> deactivatePro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proKey, false);
    _isProUser = false;
    notifyListeners();
  }

  Future<void> markFreeUsed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_freeUsedKey, true);
    _isFreeSimulationUsed = true;
    notifyListeners();
  }

  Future<void> resetFreeCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_freeUsedKey, false);
    _isFreeSimulationUsed = false;
    notifyListeners();
  }
  Future<void> resetFreeSimulationCounter() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_freeUsedKey, false);
  notifyListeners();
}
}