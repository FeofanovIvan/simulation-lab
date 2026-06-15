import 'package:flutter/foundation.dart';

enum StoredField {

  // ===== FIRST POSITION =====
  entryFirst,
  marginFirst,
  positionSideFirst,
  sizeFirst,
  roiFirst,
  pnlFirst,

  // ===== SECOND POSITION =====
  entrySecond,
  marginSecond,
  positionSideSecond,
  sizeSecond,
  roiSecond,
  pnlSecond,

  // ===== COMMON / ACCOUNT =====
  liquidation,
  currentPrice,
  marginMode,
  leverage,
  marginRatio,
}

enum FieldSource {
  manual,
  simulation,
  calculation,
}

class DialogStorageService extends ChangeNotifier {
  final Map<StoredField, double> _values = {};
  final Map<StoredField, FieldSource> _sources = {};

  DialogStorageService() {
    _initializeDefaults();
  }

  void _initializeDefaults() {
    debugPrint("🚀 STORAGE INITIALIZE DEFAULTS");

    _values[StoredField.positionSideFirst] = 1;
    _sources[StoredField.positionSideFirst] = FieldSource.manual;

    _values[StoredField.positionSideSecond] = -1;
    _sources[StoredField.positionSideSecond] = FieldSource.manual;

    _values[StoredField.marginMode] = 1; // 1 = isolated, 0 = cross
    _sources[StoredField.marginMode] = FieldSource.manual;

    _values[StoredField.leverage] = 5;
    _sources[StoredField.leverage] = FieldSource.manual;

    notifyListeners();
  }

  void save({
    required StoredField field,
    required double value,
    required FieldSource source,
  }) {
    debugPrint("========== STORAGE SAVE ==========");
    debugPrint("FIELD: $field");
    debugPrint("NEW VALUE: $value");
    debugPrint("SOURCE: $source");

    _values[field] = value;
    _sources[field] = source;

    // ================= AUTO HEDGE RULE =================
    final isCross = _values[StoredField.marginMode] == 0;

    if (isCross) {
      // Если изменили сторону первого блока
      if (field == StoredField.positionSideFirst) {
        final corrected = -value;

        debugPrint("🔁 AUTO SYNC SECOND SIDE");
        debugPrint("SECOND = $corrected");

        _values[StoredField.positionSideSecond] = corrected;
        _sources[StoredField.positionSideSecond] = FieldSource.calculation;
      }

      // Если изменили сторону второго блока
      if (field == StoredField.positionSideSecond) {
        final corrected = -value;

        debugPrint("🔁 AUTO SYNC FIRST SIDE");
        debugPrint("FIRST = $corrected");

        _values[StoredField.positionSideFirst] = corrected;
        _sources[StoredField.positionSideFirst] = FieldSource.calculation;
      }
    }

    debugPrint("==================================");

    notifyListeners();
  }

  double? getValue(StoredField field) => _values[field];

  FieldSource? getSource(StoredField field) => _sources[field];

  void clear() {
    debugPrint("🧹 STORAGE CLEAR");

    _values.clear();
    _sources.clear();

    _initializeDefaults();
  }

  void clearSecondPosition() {
    debugPrint("🧹 CLEAR SECOND POSITION");

    // input fields
    _values.remove(StoredField.entrySecond);
    _values.remove(StoredField.marginSecond);

    // calculated fields
    _values.remove(StoredField.sizeSecond);

    _values.remove(StoredField.roiSecond);
    _values.remove(StoredField.pnlSecond);

    _values.remove(StoredField.marginRatio);
_sources.remove(StoredField.marginRatio);

    _sources.remove(StoredField.entrySecond);
    _sources.remove(StoredField.marginSecond);

    _sources.remove(StoredField.sizeSecond);

    _sources.remove(StoredField.roiSecond);
    _sources.remove(StoredField.pnlSecond);

    notifyListeners();
  }

  void clearForModeSwitch() {
    debugPrint("🧹 CLEAR FOR MODE SWITCH");

    // first position
    _values.remove(StoredField.entryFirst);
    _values.remove(StoredField.marginFirst);
    _values.remove(StoredField.sizeFirst);

    _values.remove(StoredField.roiFirst);
    _values.remove(StoredField.pnlFirst);

    // second position
    _values.remove(StoredField.entrySecond);
    _values.remove(StoredField.marginSecond);
    _values.remove(StoredField.sizeSecond);

    _values.remove(StoredField.roiSecond);
    _values.remove(StoredField.pnlSecond);

    // common calculated
    _values.remove(StoredField.liquidation);
    _values.remove(StoredField.marginRatio);
_sources.remove(StoredField.marginRatio);

    _sources.remove(StoredField.entryFirst);
    _sources.remove(StoredField.marginFirst);
    _sources.remove(StoredField.sizeFirst);
  
    _sources.remove(StoredField.roiFirst);
    _sources.remove(StoredField.pnlFirst);

    _sources.remove(StoredField.entrySecond);
    _sources.remove(StoredField.marginSecond);
    _sources.remove(StoredField.sizeSecond);
  
    _sources.remove(StoredField.roiSecond);
    _sources.remove(StoredField.pnlSecond);

    _sources.remove(StoredField.liquidation);

    notifyListeners();
  }
}