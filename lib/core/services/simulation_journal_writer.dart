import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SimulationJournalWriter {
  File? _file;
  IOSink? _sink;

  String? get path => _file?.path;

  Future<void> start({
  required String sessionId,
  required String? scenario,
  required Map<String, dynamic> initialState,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/sim_$sessionId.jsonl');

  _file = file;
  _sink = file.openWrite(mode: FileMode.writeOnlyAppend);

  _sink!.writeln(jsonEncode({
  "type": "session_start",
  "sessionId": sessionId,
  "ts": DateTime.now().toIso8601String(),
  "state": initialState,
}));

  await _sink!.flush();
}
  void appendEvent({
    required int minute,
    required String type,
    Map<String, dynamic>? data,
  }) {
    if (_sink == null) return;

    _sink!.writeln(jsonEncode({
      "minute": minute,
      "type": type,
      "ts": DateTime.now().toIso8601String(),
      if (data != null) "data": data,
    }));
    // flush НЕ делаем каждый раз — иначе тормоза
  }

  Future<void> stop({
  Map<String, dynamic>? finalState,
  int? ticks,
}) async {
  if (_sink == null) return;

  _sink!.writeln(jsonEncode({
    "type": "session_end",
    "ts": DateTime.now().toIso8601String(),
    "ticks": ticks,
    if (finalState != null) "finalState": finalState,
  }));

  await _sink!.flush();
  await _sink!.close();
  _sink = null;
}
  Future<void> resume({required String sessionId}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/sim_$sessionId.jsonl');

  if (await file.exists()) {
    _file = file;
    _sink = file.openWrite(mode: FileMode.append);
  }
}
}