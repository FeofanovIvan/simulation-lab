import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ScenarioLoader {
  static Future<List<double>> loadDeltas(String fileName) async {
    final raw = await rootBundle
        .loadString('assets/scenarios/$fileName');

    final lines = raw.split('\n');

    final deltas = <double>[];

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.isEmpty) continue;

      final value = double.tryParse(trimmed);

      if (value != null) {
        deltas.add(value);
      } else {
        debugPrint("⚠️ Пропущена строка: $trimmed");
      }
    }

    return deltas;
  }
}
