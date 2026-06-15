import 'package:flutter/material.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:simulation_lab/core/scenario/scenario_loader.dart';
import 'package:simulation_lab/core/services/simulation_report_service.dart';
import 'package:simulation_lab/core/localization/app_localization.dart';
import 'package:simulation_lab/core/localization/language_provider.dart';
import 'package:path_provider/path_provider.dart';

class SimulationHistoryScreen extends StatefulWidget {
  const SimulationHistoryScreen({super.key});

  @override
  State<SimulationHistoryScreen> createState() =>
      _SimulationHistoryScreenState();
}

class _SimulationHistoryScreenState extends State<SimulationHistoryScreen> {

  List<FileSystemEntity> files = [];

  Map<String, String> scenarioNames = {};
  Map<String, int> ticksMap = {};

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final dir = await getApplicationDocumentsDirectory();

    final all = dir.listSync();

    files = all
        .where((f) => f.path.contains("sim_") && f.path.endsWith(".jsonl"))
        .toList();

    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );

    scenarioNames.clear();
    ticksMap.clear();

    for (final f in files) {
      final file = File(f.path);
      await _readMeta(file);
    }

    setState(() {});
  }

  Future<void> _readMeta(File file) async {
    try {
      final lines = await file.readAsLines();

      String scenario = "Simulation";
      int ticks = 0;

      for (final line in lines) {
        final json = jsonDecode(line);

        if (json["type"] == "scenario_set") {
          final s = json["data"]?["scenario"];
          if (s != null) {
            scenario = s.toString().replaceAll(".csv", "");
          }
        }

        if (json["type"] == "session_end") {
          ticks = json["ticks"] ?? 0;
        }
      }

      scenarioNames[file.path] = scenario;
      ticksMap[file.path] = ticks;
    } catch (_) {
      scenarioNames[file.path] = "Simulation";
      ticksMap[file.path] = 0;
    }
  }

  Future<void> _deleteFile(File file) async {
    await file.delete();
    _loadFiles();
  }

  Future<void> _downloadFile(File file) async {
  final fileName = p.basename(file.path);

  if (Platform.isAndroid) {
    final downloadsDir = Directory('/storage/emulated/0/Download');

    if (!downloadsDir.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalization.t("downloads_folder_not_found"))),
      );
      return;
    }

    final newPath = "${downloadsDir.path}/$fileName";

    await file.copy(newPath);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${AppLocalization.t("file_saved")}: $fileName"),
      ),
    );
    return;
  }

  await Share.shareXFiles(
    [XFile(file.path)],
    text: fileName,
  );
}

  Future<void> _confirmDelete(File file) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:  Text(AppLocalization.t("delete_simulation")),
          content:  Text(
            AppLocalization.t("delete_simulation_confirm"),
          ),
          actions: [
            TextButton(
              child:  Text(AppLocalization.t("cancel")),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              child: Text(
                AppLocalization.t("delete"),
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _deleteFile(file);
    }
  }

  String _date(File file) {
    final t = file.statSync().modified;
    return DateFormat('dd MMM yyyy').format(t);
  }

  String _time(File file) {
    final t = file.statSync().modified;
    return DateFormat('HH:mm').format(t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: Text(AppLocalization.t("simulation_history")),
  actions: [
    IconButton(
      icon: const Icon(Icons.delete_sweep), // 🔥 идеальная иконка для "очистить всё"
      onPressed: _confirmClearAll,
    ),
  ],
),
      body: files.isEmpty
          ?  Center(
              child: Text(AppLocalization.t("no_saved_simulations")),
            )
          : ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = File(files[index].path);

                final scenario =
                    scenarioNames[file.path] ?? "Simulation";

                final ticks =
                    ticksMap[file.path] ?? 0;

                return ListTile(
                  leading: const Icon(Icons.show_chart),

                  title: Text(scenario),

                  subtitle: Text(
                    "${_date(file)} ",
                  ),

                  trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(_time(file)),

    // 📄 PDF
    IconButton(
      icon: const Icon(Icons.picture_as_pdf),
      onPressed: () => _generatePdfReport(file),
    ),

    // 🔥 JSON (новая кнопка)
    IconButton(
      icon: const Icon(Icons.code),
      onPressed: () => _downloadJson(file),
    ),

    // ❌ delete
    IconButton(
      icon: const Icon(Icons.delete),
      onPressed: () => _confirmDelete(file),
    ),
  ],
),
                );
              },
            ),
    );
  }
  Future<void> _confirmClearAll() async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(AppLocalization.t("clear_history")),
        content: Text(
          AppLocalization.t("clear_history_confirm"),
        ),
        actions: [
          TextButton(
            child: Text(AppLocalization.t("cancel")),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text(
              AppLocalization.t("delete"),
              style: const TextStyle(color: Colors.red),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      );
    },
  );

  if (result == true) {
    await _clearAllFiles();
  }
}
Future<void> _clearAllFiles() async {
  for (final f in files) {
    try {
      await File(f.path).delete();
    } catch (_) {}
  }

  await _loadFiles();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(AppLocalization.t("history_cleared")),
    ),
  );
}
Future<void> _generatePdfReport(File file) async {
  final lines = await file.readAsLines();

  String scenario = "";
  int ticks = 0;
  double startPrice = 0;

  for (final line in lines) {
    final json = jsonDecode(line);
    final type = json["type"];

    if (type == "scenario_set") {
      scenario = json["data"]["scenario"];
    }

    if (type == "start_price_set") {
      startPrice = (json["data"]["to"] ?? 0).toDouble();
    }

    if (type == "session_start" && startPrice == 0) {
      startPrice = (json["state"]["price"] ?? 0).toDouble();
    }

    if (type == "session_end") {
      ticks = json["ticks"] ?? 0;
    }
  }

  if (scenario.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Scenario not found in journal")),
    );
    return;
  }

  final deltas = await ScenarioLoader.loadDeltas(scenario);

  final pdf = await SimulationReportService.generateReport(
    journalFile: file,
    deltas: deltas,
    startPrice: startPrice,
    ticks: ticks,
  );

  if (Platform.isAndroid) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${AppLocalization.t("pdf_created")}: ${pdf.path}"),
      ),
    );
    return;
  }

  await Share.shareXFiles(
    [XFile(pdf.path)],
    text: p.basename(pdf.path),
  );
}
Future<void> _downloadJson(File file) async {
  final lines = await file.readAsLines();
  final jsonList = lines.map((l) => jsonDecode(l)).toList();
  final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonList);

  final originalName = p.basename(file.path);
  final newName = originalName.replaceAll(".jsonl", ".json");

  if (Platform.isAndroid) {
    final downloadsDir = Directory('/storage/emulated/0/Download');

    if (!downloadsDir.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalization.t("downloads_folder_not_found"))),
      );
      return;
    }

    final newPath = "${downloadsDir.path}/$newName";
    final newFile = File(newPath);

    await newFile.writeAsString(prettyJson);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("JSON saved: $newName")),
    );
    return;
  }

  final dir = await getTemporaryDirectory();
  final tempFile = File('${dir.path}/$newName');

  await tempFile.writeAsString(prettyJson);

  await Share.shareXFiles(
    [XFile(tempFile.path)],
    text: newName,
  );
}
}