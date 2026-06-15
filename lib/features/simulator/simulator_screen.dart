import 'package:flutter/material.dart';
import 'package:simulation_lab/theme/app_theme.dart';
import 'package:simulation_lab/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:simulation_lab/core/services/simulation_service.dart';
import 'package:simulation_lab/core/services/simulation_state_service.dart';
import 'package:simulation_lab/features/pro/pro_screen.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:simulation_lab/core/scenario/scenario_loader.dart';
import 'package:simulation_lab/core/engine/simulation_engine.dart';
import 'dart:math';
import 'package:simulation_lab/core/engine/position_calculator.dart';
import 'package:simulation_lab/core/engine/cross_account_calculator.dart';
import 'package:simulation_lab/core/services/dialog_storage_service.dart';
import 'package:simulation_lab/features/settings/settings_screen.dart';
import 'package:simulation_lab/core/services/simulation_report_service.dart';
import 'package:simulation_lab/core/scenario/scenario_loader.dart';
import 'dart:io';
import 'dart:convert';
import 'package:simulation_lab/core/scenario/scenario_loader.dart';
import 'package:simulation_lab/core/services/simulation_report_service.dart';
import 'package:simulation_lab/core/localization/app_localization.dart';
import 'package:simulation_lab/core/localization/language_provider.dart';





class SimulatorScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const SimulatorScreen({
    super.key,
    required this.onToggleTheme,
  });

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {



  @override
  void initState() {
    super.initState();
    // Нельзя использовать context.read в initState напрямую
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStateOnLoad();
    });
  }

  Future<void> _checkStateOnLoad() async {
  final simulationService = context.read<SimulationService>();

  final isPro = simulationService.isProUser;
  final freeUsed = simulationService.isFreeSimulationUsed;
  final simulationActive =
    context.read<SimulationStateService>().isActive;

  debugPrint("===== SIMULATOR STATE =====");
  debugPrint("PRO активен: $isPro");
  debugPrint("Бесплатная попытка использована: $freeUsed");
  debugPrint("Симуляция активна: $simulationActive");
  debugPrint("===========================");
  
}

  @override
  Widget build(BuildContext context) {
     context.watch<LanguageProvider>();
    final orientation = MediaQuery.of(context).orientation;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: AppColors.darkBackground,
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: AppColors.lightBackground,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
      child: Scaffold(
        body: SafeArea(
          child: orientation == Orientation.portrait
    ? _PortraitLayout()
    : const _LandscapeLayout(),

        ),
        floatingActionButton: FloatingActionButton(
  heroTag: "settings_button",
  child: const Icon(Icons.settings),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          onToggleTheme: widget.onToggleTheme,
        ),
      ),
    );
  },
),
      ),
    );
  }
}


///////////////////////////////////////////////////////////////
/// PORTRAIT
///////////////////////////////////////////////////////////////

class _PortraitLayout extends StatefulWidget {
  const _PortraitLayout();

  @override
  State<_PortraitLayout> createState() => _PortraitLayoutState();
}

class _PortraitLayoutState extends State<_PortraitLayout> {
  bool secondBlockAdded = false;
  bool _lastSimulationState = false;
  bool firstIsLong = true;
  bool secondIsLong = false;
  bool _lastIsIsolated = true;
  @override
void didChangeDependencies() {
  super.didChangeDependencies();

  final stateService =
      context.watch<SimulationStateService>();

  final isActive = stateService.isActive;
  final isIsolated = stateService.isIsolated;

  // ===============================
  // STOP → удаляем второй блок
  // ===============================
  if (_lastSimulationState == true && isActive == false) {
    if (secondBlockAdded) {
      setState(() {
        secondBlockAdded = false;
      });

      debugPrint("🧹 Second block removed after STOP");
    }
  }

  // ===============================
  // CROSS → ISOLATED
  // ===============================
  if (_lastIsIsolated == false && isIsolated == true) {
    if (secondBlockAdded) {
      setState(() {
        secondBlockAdded = false;
      });

      debugPrint("🧹 Second block removed (Cross → Isolated)");
    }
  }

 // ===============================
// START → восстановление состояния
// ===============================
if (_lastSimulationState == false && isActive == true) {

  final p1 = stateService.data.position1;
  final p2 = stateService.data.position2;

  final bool secondHasData =
      p2.entry != 0 ||
      p2.margin != 0 ||
      p2.size != 0;

  setState(() {
    firstIsLong = p1.isLong;
    secondIsLong = p2.isLong;

    if (secondHasData) {
      secondBlockAdded = true;
      debugPrint("🔄 Second block restored from simulation state");
    }
  });

  debugPrint("🔄 Directions synced with simulation");
}

_lastSimulationState = isActive;
_lastIsIsolated = isIsolated;
}

  @override
  Widget build(BuildContext context) {
     context.watch<LanguageProvider>();

    return Column(
      children: [
        const TopBarSection(),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 12),

                const SizedBox(
                  height: 420,
                  child: GraphSection(),
                ),

                const SizedBox(height: 12),

                const SizedBox(height: 8),
const _ActiveOrdersBlock(),
const SizedBox(height: 8),

                /// =============================
                /// ПЕРВЫЙ БЛОК
                /// =============================
                ControlSection(
                  key: ValueKey(
    context.watch<SimulationStateService>().isIsolated,
  ),
                  isLong: firstIsLong,
                  onToggleDirection: () {
                    setState(() {
                      firstIsLong = !firstIsLong;

                      // если есть второй блок — синхронизируем
                      if (secondBlockAdded) {
                        secondIsLong = !firstIsLong;
                      }
                    });
                  },
                ),

                const SizedBox(height: 16),

                /// =============================
                /// ВТОРОЙ БЛОК
                /// =============================
                if (secondBlockAdded)
                  ControlSection(
                    isSecondary: true,
                    isLong: secondIsLong,
                    onToggleDirection: () {
                      setState(() {
                        secondIsLong = !secondIsLong;
                        firstIsLong = !secondIsLong;
                      });
                    },
                    onClose: () {
                      setState(() {
                        secondBlockAdded = false;
                      });
                    },
                  ),

                /// =============================
                /// КНОПКА +
                /// =============================
                if (!secondBlockAdded)
                  Consumer<SimulationStateService>(
                    builder: (context, stateService, _) {
                      final bool showPlus =
                          stateService.isActive ||
                          !stateService.isIsolated;

                      if (!showPlus) {
                        return const SizedBox();
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: FloatingActionButton(
                            heroTag: "add_position",
                            onPressed: () {
                              setState(() {
                                secondBlockAdded = true;

                                // автоматически противоположное направление
                                secondIsLong = !firstIsLong;
                              });
                            },
                            child: const Icon(Icons.add),
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

///////////////////////////////////////////////////////////////
/// LANDSCAPE
///////////////////////////////////////////////////////////////

class _LandscapeLayout extends StatefulWidget {
  const _LandscapeLayout();

  @override
  State<_LandscapeLayout> createState() => _LandscapeLayoutState();
}

class _LandscapeLayoutState extends State<_LandscapeLayout> {
  bool secondBlockAdded = false;
  bool _lastSimulationState = false;
  bool _lastIsIsolated = true;
  bool firstIsLong = true;
  bool secondIsLong = false;

  @override
void didChangeDependencies() {
  super.didChangeDependencies();

  final stateService =
      context.watch<SimulationStateService>();

  final isActive = stateService.isActive;
  final isIsolated = stateService.isIsolated;

  // ===============================
  // STOP → удаляем второй блок
  // ===============================
  if (_lastSimulationState == true && isActive == false) {
    if (secondBlockAdded) {
      setState(() {
        secondBlockAdded = false;
      });

      debugPrint("🧹 Second block removed after STOP");
    }
  }

  // ===============================
  // CROSS → ISOLATED
  // ===============================
  if (_lastIsIsolated == false && isIsolated == true) {
    if (secondBlockAdded) {
      setState(() {
        secondBlockAdded = false;
      });

      debugPrint("🧹 Second block removed (Cross → Isolated)");
    }
  }

  // ===============================
// START → восстановление состояния
// ===============================
if (_lastSimulationState == false && isActive == true) {

  final p1 = stateService.data.position1;
  final p2 = stateService.data.position2;

  final bool secondHasData =
      p2.entry != 0 ||
      p2.margin != 0 ||
      p2.size != 0;

  setState(() {
    firstIsLong = p1.isLong;
    secondIsLong = p2.isLong;

    if (secondHasData) {
      secondBlockAdded = true;
      debugPrint("🔄 Second block restored from simulation state");
    }
  });

  debugPrint("🔄 Directions synced with simulation");
}

_lastSimulationState = isActive;
_lastIsIsolated = isIsolated;
}

  @override
  Widget build(BuildContext context) {
     context.watch<LanguageProvider>();
    return Row(
      children: [
        const Expanded(
          flex: 3,
          child: _LandscapeLeft(),
        ),

        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  /// =============================
    /// БЛОК АКТИВНЫХ ОРДЕРОВ
    /// =============================
    const SizedBox(height: 8),
    const _ActiveOrdersBlock(),
    const SizedBox(height: 16),

                  /// =============================
                  /// ПЕРВЫЙ БЛОК
                  /// =============================
                  ControlSection(
                    key: ValueKey(
    context.watch<SimulationStateService>().isIsolated,
  ),
                    isLong: firstIsLong,
                    onToggleDirection: () {
                      setState(() {
                        firstIsLong = !firstIsLong;

                        if (secondBlockAdded) {
                          secondIsLong = !firstIsLong;
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  /// =============================
                  /// ВТОРОЙ БЛОК
                  /// =============================
                  if (secondBlockAdded)
                    ControlSection(
                      isSecondary: true,
                      isLong: secondIsLong,
                      onToggleDirection: () {
                        setState(() {
                          secondIsLong = !secondIsLong;
                          firstIsLong = !secondIsLong;
                        });
                      },
                      onClose: () {
                        setState(() {
                          secondBlockAdded = false;
                        });
                      },
                    ),

                  /// =============================
                  /// КНОПКА +
                  /// =============================
                  if (!secondBlockAdded)
                    Consumer<SimulationStateService>(
                      builder: (context, stateService, _) {
                        final bool showPlus =
                            stateService.isActive ||
                            !stateService.isIsolated;

                        if (!showPlus) {
                          return const SizedBox();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Center(
                            child: FloatingActionButton(
                              heroTag: "add_position_landscape",
                              onPressed: () {
                                setState(() {
                                  secondBlockAdded = true;

                                  // автоматически противоположное направление
                                  secondIsLong = !firstIsLong;
                                });
                              },
                              child: const Icon(Icons.add),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}


class _LandscapeLeft extends StatelessWidget {
  const _LandscapeLeft();

  @override
  Widget build(BuildContext context) {
     context.watch<LanguageProvider>();
    return Column(
      children: const [
        TopBarSection(),
        Expanded(child: GraphSection()),
      ],
    );
  }
}


///////////////////////////////////////////////////////////////
/// TOP BAR
///////////////////////////////////////////////////////////////

class TopBarSection extends StatelessWidget {
  const TopBarSection({super.key});

  @override
  Widget build(BuildContext context) {
     context.watch<LanguageProvider>();
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: 
      Row(
  children: [
    Flexible(
      flex: 3,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: const _SimulationButton(),
      ),
    ),

    const SizedBox(width: 12),

    Expanded(
      flex: 4,
      child: const _PriceInput(),
    ),

    const SizedBox(width: 12),

    Flexible(
      flex: 3,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: const _ScenarioButton(),
      ),
    ),
  ],
)
    );
  }
}


class _SimulationButton extends StatefulWidget {
  const _SimulationButton();

  @override
  State<_SimulationButton> createState() => _SimulationButtonState();
}

class _SimulationButtonState extends State<_SimulationButton>
    with SingleTickerProviderStateMixin {



  
  bool _isPro = false;
  bool _freeUsed = false;

  double scale = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadState();
    });
  }

  Future<void> _showStopSimulationDialog() async {

  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(AppLocalization.t("simulation_finished")),
      content: Text(
  "${AppLocalization.t("simulation_saved_file")}\n"
  "${AppLocalization.t("download_pdf_report")}",
),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(AppLocalization.t("no")),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(AppLocalization.t("yes")),
        ),
      ],
    ),
  );

  if (result != true) return;

  final stateService = context.read<SimulationStateService>();

  final path = stateService.currentJournalPath;

  if (path == null) {
    debugPrint("Journal file not found");
    return;
  }

  final file = File(path);

  await _generatePdfReport(file);
}
Future<void> _generatePdfReport(File file) async {

  final lines = await file.readAsLines();

  String scenario = "";
  int ticks = 0;

  double startPrice = 0;
  double finalPrice = 0;

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
      finalPrice = (json["finalState"]?["price"] ?? 0).toDouble();
    }
  }

  if (scenario.isEmpty) {
    throw Exception("Scenario not found in journal");
  }

  final deltas = await ScenarioLoader.loadDeltas(scenario);

  final pdf = await SimulationReportService.generateReport(
    journalFile: file,
    deltas: deltas,
    startPrice: startPrice,
    ticks: ticks,
  );

  ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text("${AppLocalization.t("pdf_created")}: ${pdf.path}"),
  ),
);
}
  Future<void> _loadState() async {
  final stateService = context.read<SimulationStateService>();
  final simulationService = context.read<SimulationService>();

  setState(() {
    
    _isPro = simulationService.isProUser;
    _freeUsed = simulationService.isFreeSimulationUsed;
  });
}

   Future<void> _handleTap() async {
  final stateService = context.read<SimulationStateService>();
  final simulationService = context.read<SimulationService>();

  final bool isActive = stateService.isActive;
  final bool isPro = simulationService.isProUser;

  if (isActive) {
    final hasSimulationData = stateService.simMinutes > 0;

    // ✅ 1. Сначала всегда останавливаем симуляцию
    await _stopSimulation();

    // ✅ 2. Потом показываем диалог (если есть данные)
    if (hasSimulationData) {
      await _showStopSimulationDialog();
    }

    return;
  }

  if (isPro) {
    await _startSimulation();
    return;
  }

  _openDialog();
}

 Future<void> _openDialog() async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => SimulationProDialog(
      freeAvailable: !_freeUsed,
      onFreeTry: () {},
    ),
  );

  if (result == "free") {
    await _startSimulation();
  }

  if (result == "pro") {
    final proResult = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProScreen(),
      ),
    );

    if (proResult == true) {
      await _loadState(); // ← ВАЖНО
      setState(() {});    // обновляем кнопку
    }
  }
}






  void _showProRequiredDialog() {
    showDialog(
      context: context,
      builder: (_) => const CrossProDialog(),
    );
  }

  Future<void> _startSimulation() async {
    final simulationService = context.read<SimulationService>();

    if (!_isPro && !_freeUsed) {
      await simulationService.markFreeUsed();
      _freeUsed = simulationService.isFreeSimulationUsed;
    }

    await context.read<SimulationStateService>().startSimulation();


  }

  Future<void> _stopSimulation() async {
  debugPrint("🛑 STOP BUTTON PRESSED");
  await context.read<SimulationStateService>().stopSimulation();
}


@override
Widget build(BuildContext context) {
   context.watch<LanguageProvider>();
  final theme = Theme.of(context);

  final simulationService = context.watch<SimulationService>();
  final stateService = context.watch<SimulationStateService>();

  final bool isActive = stateService.isActive;
  final bool isPro = simulationService.isProUser;

  final Color buttonColor =
      isActive ? Colors.redAccent : theme.colorScheme.primary;

  String text;

  if (isActive) {
    text = AppLocalization.t("stop");
  } else {
    text = isPro
        ? AppLocalization.t("simulation_pro")
        : AppLocalization.t("simulation");
  }

  // 🔹 измеряем ширину самой длинной фразы
  final longestText = AppLocalization.t("simulation_pro");

  final textPainter = TextPainter(
    text: TextSpan(
      text: longestText,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout();

  final minWidth = textPainter.width + 20; // padding

  return GestureDetector(
    onTapDown: (_) => setState(() => scale = 0.95),
    onTapUp: (_) async {
      setState(() => scale = 1.0);
      await _handleTap();
    },
    onTapCancel: () => setState(() => scale = 1.0),
    child: AnimatedScale(
      duration: const Duration(milliseconds: 100),
      scale: scale,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ),
  );
}
}



class _PriceInput extends StatefulWidget {
  const _PriceInput();

  @override
  State<_PriceInput> createState() => _PriceInputState();
}

class _PriceInputState extends State<_PriceInput> {
  late TextEditingController _controller;
  bool _lastIsActive = false;

  @override
  void initState() {
    super.initState();

    final stateService =
        context.read<SimulationStateService>();

    _lastIsActive = stateService.isActive;

    _controller = TextEditingController(
      text: stateService.startPrice == 0
          ? ""
          : stateService.startPrice.toStringAsFixed(2),
    );
  }

  @override
void didChangeDependencies() {
  super.didChangeDependencies();

  final stateService =
      context.watch<SimulationStateService>();

  final isActive = stateService.isActive;
  final startPrice = stateService.startPrice;

  // ===============================
  // ⛔ STOP → очистка
  // ===============================
  if (_lastIsActive == true && isActive == false) {
    _controller.clear();
    _lastIsActive = isActive;
    return;
  }

  // ===============================
  // 🔥 CLEAR PRICE WHEN ZERO
  // ===============================
  if (startPrice == 0 && _controller.text.isNotEmpty) {
    _controller.clear();
  }

  // ===============================
  // ▶ SIMULATION → динамическое обновление
  // ===============================
  if (isActive && startPrice > 0) {
    final newText = startPrice.toStringAsFixed(2);

    if (_controller.text != newText) {
      _controller.text = newText;
    }
  }

  // ===============================
  // 🧮 CALCULATOR → обновление извне
  // ===============================
  if (!isActive && startPrice > 0) {
    final newText = startPrice.toStringAsFixed(2);

    if (_controller.text != newText) {
      _controller.text = newText;
    }
  }

  _lastIsActive = isActive;
}

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ===============================
  // 🔥 ДИАЛОГ ВВОДА
  // ===============================
  void _openPriceDialog(BuildContext context) {
    final stateService =
        context.read<SimulationStateService>();

    final storage =
        context.read<DialogStorageService>();

    final controller = TextEditingController(
      text: stateService.startPrice == 0
          ? ""
          : stateService.startPrice.toString(),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:  Text(AppLocalization.t("enter_price")),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:  Text(AppLocalization.t("cancel")),
          ),
          TextButton(
            onPressed: () async {
              final parsed =
                  double.tryParse(controller.text);

              if (parsed != null) {

                // 🔥 Обновляем сервис
                await stateService.setStartPrice(parsed);

                // 🔥 Обновляем storage
                storage.save(
                  field: StoredField.currentPrice,
                  value: parsed,
                  source: FieldSource.manual,
                );

                // 🔥 Обновляем локальный контроллер
                _controller.text =
                    parsed.toStringAsFixed(2);
              }

              Navigator.pop(context);
            },
            child:  Text(AppLocalization.t("ok")),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
     context.watch<LanguageProvider>();
    final theme = Theme.of(context);
    final stateService =
        context.watch<SimulationStateService>();
    final locked = stateService.priceLocked;    

    return SizedBox(
      height: 36,
      child: TextField(
        controller: _controller,
        readOnly: true, // 🔥 запрет прямого ввода
        textAlign: TextAlign.center,
        style: TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.bold,
  color: locked ? Colors.grey : null,
),
        onTap: locked
    ? null
    : () {
        _openPriceDialog(context);
      },
        decoration: InputDecoration(
          hintText: AppLocalization.t("current_price"),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}






class _ScenarioButton extends StatelessWidget {
  const _ScenarioButton();

  void _openRealDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _EmptyDialog(
  title: AppLocalization.t("scenario"),
),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
  final simulationService = context.read<SimulationService>();
  final stateService = context.read<SimulationStateService>();
  // ✅ БЛОКИРОВКА СЦЕНАРИЯ
if (stateService.priceLocked) {
  _showScenarioLockedDialog(context);
  return;
}

  final bool isPro = simulationService.isProUser;
  final bool isActive = stateService.isActive;

  // ✅ PRO всегда может открыть сценарий
  if (isPro) {
    _openRealDialog(context);
    return;
  }

  // ✅ Если идёт бесплатная симуляция — тоже можно
  if (isActive) {
    _openRealDialog(context);
    return;
  }

  // ❌ Иначе показываем PRO-диалог
  final result = await showDialog<String>(
    context: context,
    builder: (_) => SimulationProDialog(
      freeAvailable: !simulationService.isFreeSimulationUsed,
      onFreeTry: () {},
    ),
  );

  if (result == "free") {
    if (!simulationService.isFreeSimulationUsed) {
      await simulationService.markFreeUsed();
    }
    await stateService.startSimulation();
  }

  if (result == "pro") {
    final proResult = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProScreen()),
    );

    if (proResult == true) {
      _openRealDialog(context);
    }
  }
}
  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
             Text(
              AppLocalization.t("scenario"),
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: theme.iconTheme.color,
            ),
          ],
        ),
      ),
    );
  }

  void _showScenarioLockedDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(AppLocalization.t("scenario_locked")),
      content: Text(
        AppLocalization.t("scenario_locked_text"),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalization.t("understood")),
        ),
      ],
    ),
  );
}
}
///////////////////////////////////////////////////////////////
/// ACTIVE ORDERS BLOCK
///////////////////////////////////////////////////////////////

class _ActiveOrdersBlock extends StatelessWidget {
  const _ActiveOrdersBlock();

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    final state = context.watch<SimulationStateService>();

    if (!state.isActive || state.data.activeOrders.isEmpty) {
      return const SizedBox();
    }

    final orders = state.data.activeOrders;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (int i = 0; i < orders.length; i++)
            _OrderCard(
              order: orders[i],
              index: i,
            ),
        ],
      ),
    );
  }
}

///////////////////////////////////////////////////////////////
/// ORDER CARD
///////////////////////////////////////////////////////////////

class _OrderCard extends StatelessWidget {
  final OrderData order;
  final int index;

  const _OrderCard({
    required this.order,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    final bool isLong = order.isLong;

    final Color sideColor = isLong ? Colors.green : Colors.red;

    final String actionText =
        order.action == OrderAction.buy ? "BUY" : "SELL";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          //////////////////////////////////////////////////////////
          /// HEADER
          //////////////////////////////////////////////////////////

           Text(
            AppLocalization.t("open_orders"),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Divider(),

          const SizedBox(height: 8),

          //////////////////////////////////////////////////////////
          /// TOP ROW
          //////////////////////////////////////////////////////////

          Row(
  children: [

    /// LONG / SHORT
    Text(
  order.isLong
      ? AppLocalization.t("long")
      : AppLocalization.t("short"),
  style: TextStyle(
    fontWeight: FontWeight.bold,
    color: order.isLong ? Colors.green : Colors.red,
    fontSize: 15,
  ),
),

const Spacer(),

/// BUY / SELL
Text(
  order.action == OrderAction.buy
      ? AppLocalization.t("buy")
      : AppLocalization.t("sell"),
  style: TextStyle(
    fontWeight: FontWeight.w600,
    color: order.action == OrderAction.buy
        ? Colors.green
        : Colors.red,
  ),
),

    const Spacer(),

    /// EDIT BUTTON
    Container(
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          _showEditDialog(context, order);
        },
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(
            Icons.edit,
            size: 20,
            color: Colors.green,
          ),
        ),
      ),
    ),

    const SizedBox(width: 8),

    /// DELETE BUTTON
    Container(
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          context
              .read<SimulationStateService>()
              .cancelOrder(order.id);
        },
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(
            Icons.delete,
            size: 20,
            color: Colors.red,
          ),
        ),
      ),
    ),
  ],
),

          const SizedBox(height: 8),

          //////////////////////////////////////////////////////////
          /// PRICE ROW
          //////////////////////////////////////////////////////////

          Row(
            children: [
              Text(AppLocalization.t("price")),
              const Spacer(),
              Text(
                order.price.toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: 6),

          //////////////////////////////////////////////////////////
          /// AMOUNT ROW
          //////////////////////////////////////////////////////////

          Row(
            children: [
              Text(AppLocalization.t("quantity")),
              const Spacer(),
              Text(
                order.margin.toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),

const Divider(
  thickness: 0.6,
),

const SizedBox(height: 8),
        ],
      ),
    );
  }

  //////////////////////////////////////////////////////////////
  /// EDIT DIALOG
  //////////////////////////////////////////////////////////////

  void _showEditDialog(
    BuildContext context,
    OrderData order,
  ) {
    final priceController =
        TextEditingController(text: order.price.toString());

    final marginController =
        TextEditingController(text: order.margin.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title:  Text(AppLocalization.t("edit_order")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            TextField(
              controller: priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: AppLocalization.t("price")),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: marginController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:  InputDecoration(labelText: AppLocalization.t("quantity")),
            ),
          ],
        ),
        actions: [

          TextButton(
            onPressed: () => Navigator.pop(context),
            child:  Text(AppLocalization.t("cancel")),
          ),

          TextButton(
            onPressed: () {
              final newPrice =
                  double.tryParse(priceController.text);
              final newMargin =
                  double.tryParse(marginController.text);

              if (newPrice != null && newMargin != null) {
                order.price = newPrice;
                order.margin = newMargin;

                context
                    .read<SimulationStateService>()
                    .notifyListeners();
              }

              Navigator.pop(context);
            },
            child:  Text(AppLocalization.t("save")),
          ),
        ],
      ),
    );
  }
}

///////////////////////////////////////////////////////////////
/// GRAPH
///////////////////////////////////////////////////////////////
enum ChartTimeframe {
  h1,
  h4,
  d1,
}


class GraphSection extends StatefulWidget {
  const GraphSection({super.key});

  @override
  State<GraphSection> createState() => _GraphSectionState();
}

class _GraphSectionState extends State<GraphSection> {
  double? _currentPrice;

  bool _restoreTriggered = false;
  bool _lastIsActive = false;
  

  // ✅ Базовые минутные свечи
  final List<Candle> _m1 = [];

  // ✅ Агрегированные таймфреймы
  final List<Candle> _h1 = [];
  final List<Candle> _h4 = [];
  final List<Candle> _d1 = [];

  int _counterH1 = 0;
  int _counterH4 = 0;
  int _counterD1 = 0;

  ChartTimeframe _timeframe = ChartTimeframe.h1;

  List<Candle> get _visibleCandles {
    switch (_timeframe) {
      case ChartTimeframe.h1:
        return _h1;
      case ChartTimeframe.h4:
        return _h4;
      case ChartTimeframe.d1:
        return _d1;
    }
  }

  int get _minutesPerCandle {
    switch (_timeframe) {
      case ChartTimeframe.h1:
        return 60;
      case ChartTimeframe.h4:
        return 240;
      case ChartTimeframe.d1:
        return 1440;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final isActive = context.watch<SimulationStateService>().isActive;

    // 🔥 ACTIVE → STOP
    if (_lastIsActive == true && isActive == false) {
      _clearChart();
      _restoreTriggered = false; // важно, чтобы авто-restore мог снова сработать
    }

    _lastIsActive = isActive;
  }

  void _clearChart() {
    setState(() {
      _currentPrice = null;

      _m1.clear();
      _h1.clear();
      _h4.clear();
      _d1.clear();

      _counterH1 = 0;
      _counterH4 = 0;
      _counterD1 = 0;
    });
  }


void _changeTimeframe(ChartTimeframe tf) {
  setState(() {
    _timeframe = tf;
  });
}



void _updatePrice(double price) {
  setState(() {
    _currentPrice = price;

    final open = _m1.isEmpty ? price : _m1.last.close;

    final m1 = Candle(
      open: open,
      high: max(open, price),
      low: min(open, price),
      close: price,
      volume: 0.5 + Random().nextDouble() * 2,
    );

    _m1.add(m1);

    if (_m1.length > 5000) {
      _m1.removeAt(0);
    }

    _aggregateH1(m1);
    _aggregateH4(m1);
    _aggregateD1(m1);
  });

  final state = context.read<SimulationStateService>();

  // ✅ каждое обновление цены = 1 минута симуляции
  if (state.isActive) {
    state.addSimMinute();
  }

  state.setStartPrice(price);
}
void _aggregateH1(Candle m1) {
  if (_h1.isEmpty || _counterH1 == 0) {
    _h1.add(Candle(
      open: m1.open,
      high: m1.high,
      low: m1.low,
      close: m1.close,
      volume: m1.volume,
    ));
    _counterH1 = 1;
    return;
  }

  final last = _h1.last;

  last.high = max(last.high, m1.high);
  last.low = min(last.low, m1.low);
  last.close = m1.close;
  last.volume += m1.volume;

  _counterH1++;

  if (_counterH1 >= 60) {
    _counterH1 = 0;
  }
}
void _aggregateH4(Candle m1) {
  if (_h4.isEmpty || _counterH4 == 0) {
    _h4.add(Candle(
      open: m1.open,
      high: m1.high,
      low: m1.low,
      close: m1.close,
      volume: m1.volume,
    ));
    _counterH4 = 1;
    return;
  }

  final last = _h4.last;

  last.high = max(last.high, m1.high);
  last.low = min(last.low, m1.low);
  last.close = m1.close;
  last.volume += m1.volume;

  _counterH4++;

  if (_counterH4 >= 240) {
    _counterH4 = 0;
  }
}
void _aggregateD1(Candle m1) {
  if (_d1.isEmpty || _counterD1 == 0) {
    _d1.add(Candle(
      open: m1.open,
      high: m1.high,
      low: m1.low,
      close: m1.close,
      volume: m1.volume,
    ));
    _counterD1 = 1;
    return;
  }

  final last = _d1.last;

  last.high = max(last.high, m1.high);
  last.low = min(last.low, m1.low);
  last.close = m1.close;
  last.volume += m1.volume;

  _counterD1++;

  if (_counterD1 >= 1440) {
    _counterD1 = 0;
  }
}



  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    final theme = Theme.of(context);
    final isActive =
        context.watch<SimulationStateService>().isActive;

    

    return Container(
      margin:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: theme.brightness == Brightness.light
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ]
            : [],
      ),
      child: Column(
        children: [
          _TimeframeBar(
  timeframe: _timeframe,
  onChanged: _changeTimeframe,
),


          Expanded(
            flex: 6,
            child: _ChartArea(
  currentPrice: _currentPrice,
  candles: _visibleCandles,
  currentCandle: null,
),

          ),

          Expanded(
  flex: 2,
  child: _VolumeArea(
    candles: _visibleCandles,
    currentCandle: null,
  ),
),



          _ChartControls(
            onPrice: _updatePrice,
          ),
        ],
      ),
    );
  }
}


class Candle {
  final double open;
  double high;
  double low;
  double close;
  double volume;

  Candle({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume = 0,
  });
}


class _TimeframeBar extends StatelessWidget {
  final ChartTimeframe timeframe;
  final ValueChanged<ChartTimeframe> onChanged;

  const _TimeframeBar({
    required this.timeframe,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _TimeButton(
            label: "1H",
            active: timeframe == ChartTimeframe.h1,
            onTap: () => onChanged(ChartTimeframe.h1),
          ),
          const SizedBox(width: 16),
          _TimeButton(
            label: "4H",
            active: timeframe == ChartTimeframe.h4,
            onTap: () => onChanged(ChartTimeframe.h4),
          ),
          const SizedBox(width: 16),
          _TimeButton(
            label: "1D",
            active: timeframe == ChartTimeframe.d1,
            onTap: () => onChanged(ChartTimeframe.d1),
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TimeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: active
              ? theme.colorScheme.primary.withOpacity(0.15)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: active
                ? theme.colorScheme.primary
                : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

class _ChartArea extends StatelessWidget {
  final double? currentPrice;
  final List<Candle> candles;
  final Candle? currentCandle;

  const _ChartArea({
    this.currentPrice,
    required this.candles,
    required this.currentCandle,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    if (currentPrice == null) {
      return const SizedBox.expand();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

return CustomPaint(
  painter: _ChartPainter(
    price: currentPrice!,
    candles: candles,
    currentCandle: currentCandle,
    isDark: isDark, // ← ВАЖНО
  ),
  child: const SizedBox.expand(),
);
  }
}



class _ChartPainter extends CustomPainter {
  final double price;
  final List<Candle> candles;
  final Candle? currentCandle;
  final bool isDark;

  const _ChartPainter({
    required this.price,
    required this.candles,
    required this.currentCandle,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (price <= 0) return;

    const candleWidth = 8.0;
    const spacing = 6.0;
    const rightPadding = 24.0;
    const gridLines = 6;

    // ============================================================
    // 1. Собираем ВСЕ свечи (без дублирования!)
    // ============================================================

    final allCandles = <Candle>[
      ...candles,
      if (currentCandle != null) currentCandle!,
    ];

    if (allCandles.isEmpty) return;

    final visibleCount =
        ((size.width - rightPadding) / (candleWidth + spacing)).floor();

    final visibleCandles = allCandles.length > visibleCount
        ? allCandles.sublist(allCandles.length - visibleCount)
        : allCandles;

    // ============================================================
    // 2. Диапазон цен
    // ============================================================

    double highest = visibleCandles.first.high;
    double lowest = visibleCandles.first.low;

    for (final c in visibleCandles) {
      if (c.high > highest) highest = c.high;
      if (c.low < lowest) lowest = c.low;
    }

    double range = highest - lowest;

    if (range <= 0) {
      highest *= 1.01;
      lowest *= 0.99;
      range = highest - lowest;
    }

    // Добавляем 10% паддинг сверху и снизу
    final padding = range * 0.1;
    highest += padding;
    lowest -= padding;
    range = highest - lowest;

    double priceToY(double p) {
      return size.height * (1 - (p - lowest) / range);
    }

    // ============================================================
    // 3. Сетка
    // ============================================================

    final gridPaint = Paint()
  ..color = isDark
      ? const Color(0xFF1F1F1F)
      : const Color(0xFFE0E0E0)
  ..strokeWidth = 1;

    for (int i = 0; i <= gridLines; i++) {
      final y = size.height * i / gridLines;

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );

      final level = highest - (range * i / gridLines);

      final textPainter = TextPainter(
        text: TextSpan(
          text: level.toStringAsFixed(2),
          style: TextStyle(
  color: isDark
      ? const Color(0xFFAAAAAA)
      : Colors.black87,
  fontSize: 10,
),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width - 4, y - 6),
      );
    }

    // ============================================================
    // 4. Рисуем свечи
    // ============================================================

    double x = size.width - rightPadding;

    for (int i = visibleCandles.length - 1; i >= 0; i--) {
      final c = visibleCandles[i];

      final centerX = x - candleWidth / 2;

      final openY = priceToY(c.open);
      final closeY = priceToY(c.close);
      final highY = priceToY(c.high);
      final lowY = priceToY(c.low);

      final isBull = c.close >= c.open;

      final bodyPaint = Paint()
        ..color = isBull
            ? const Color(0xFF00C853)
            : const Color(0xFFD50000);

      final wickPaint = Paint()
        ..color = bodyPaint.color
        ..strokeWidth = 1;

      // Фитиль
      canvas.drawLine(
        Offset(centerX, highY),
        Offset(centerX, lowY),
        wickPaint,
      );

      final top = min(openY, closeY);
      final bottom = max(openY, closeY);
      final bodyHeight = bottom - top;

      if (bodyHeight < 1.5) {
        canvas.drawLine(
          Offset(centerX - candleWidth / 2, top),
          Offset(centerX + candleWidth / 2, top),
          bodyPaint..strokeWidth = 1,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTRB(
            centerX - candleWidth / 2,
            top,
            centerX + candleWidth / 2,
            bottom,
          ),
          bodyPaint,
        );
      }

      x -= (candleWidth + spacing);
      if (x < 0) break;
    }

    // ============================================================
    // 5. Пунктирная линия текущей цены
    // ============================================================

    final priceY = priceToY(price);

    final priceLinePaint = Paint()
      ..color = const Color(0xFF2979FF)
      ..strokeWidth = 1;

    const dashWidth = 6;
    const dashSpace = 4;

    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, priceY),
        Offset(startX + dashWidth, priceY),
        priceLinePaint,
      );
      startX += dashWidth + dashSpace;
    }

    // ============================================================
    // 6. Лейбл цены справа
    // ============================================================

    final priceText = TextPainter(
      text: TextSpan(
        text: price.toStringAsFixed(2),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    priceText.layout();

    final labelWidth = priceText.width + 8;

    canvas.drawRect(
      Rect.fromLTWH(
        size.width - labelWidth,
        priceY - 10,
        labelWidth,
        20,
      ),
      Paint()..color = const Color(0xFF2979FF),
    );

    priceText.paint(
      canvas,
      Offset(size.width - priceText.width - 4, priceY - 6),
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}



class _VolumeArea extends StatelessWidget {
  final List<Candle> candles;
  final Candle? currentCandle;

  const _VolumeArea({
    required this.candles,
    required this.currentCandle,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    return CustomPaint(
      painter: _VolumePainter(
        candles: candles,
        currentCandle: currentCandle,
      ),
      child: const SizedBox.expand(),
    );
  }
}
class _VolumePainter extends CustomPainter {
  final List<Candle> candles;
  final Candle? currentCandle;

  const _VolumePainter({
    required this.candles,
    required this.currentCandle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barWidth = 8.0;
    const spacing = 6.0;
    const rightPadding = 24.0;

    final allCandles = <Candle>[
      ...candles,
      if (currentCandle != null) currentCandle!,
    ];

    if (allCandles.isEmpty) return;

    final visibleCount =
        ((size.width - rightPadding) / (barWidth + spacing)).floor();

    final visible = allCandles.length > visibleCount
        ? allCandles.sublist(allCandles.length - visibleCount)
        : allCandles;

    if (visible.isEmpty) return;

    // =============================
    // 1️⃣ Находим max и average
    // =============================

    double maxVolume = 0;
    double totalVolume = 0;

    for (final c in visible) {
      if (c.volume > maxVolume) maxVolume = c.volume;
      totalVolume += c.volume;
    }

    if (maxVolume == 0) return;

    final avgVolume = totalVolume / visible.length;

    // =============================
    // 2️⃣ Рисуем среднюю линию
    // =============================

    final avgHeight =
        sqrt(avgVolume / maxVolume) * size.height * 0.8;

    canvas.drawLine(
      Offset(0, size.height - avgHeight),
      Offset(size.width, size.height - avgHeight),
      Paint()
        ..color = const Color(0xFF666666)
        ..strokeWidth = 1,
    );

    // =============================
    // 3️⃣ Рисуем столбцы
    // =============================

    double x = size.width - rightPadding;

    for (int i = visible.length - 1; i >= 0; i--) {
      final c = visible[i];

      final centerX = x - barWidth / 2;

      final normalized = sqrt(c.volume / maxVolume);
      final height = normalized * size.height * 0.8;

      final isBull = c.close >= c.open;

      final rect = Rect.fromLTRB(
        centerX - barWidth / 2,
        size.height - height,
        centerX + barWidth / 2,
        size.height,
      );

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isBull
            ? [
                const Color(0xFF00C853).withOpacity(0.2),
                const Color(0xFF00C853).withOpacity(0.9),
              ]
            : [
                const Color(0xFFD50000).withOpacity(0.2),
                const Color(0xFFD50000).withOpacity(0.9),
              ],
      );

      final paint = Paint()
        ..shader = gradient.createShader(rect);

      canvas.drawRect(rect, paint);

      x -= (barWidth + spacing);
      if (x < 0) break;
    }
  }

  @override
  bool shouldRepaint(covariant _VolumePainter oldDelegate) => true;
}


class _ChartControls extends StatefulWidget {
  final Function(double) onPrice;

  const _ChartControls({
    super.key,
    required this.onPrice,
  });

  @override
  State<_ChartControls> createState() => _ChartControlsState();
}


class _ChartControlsState extends State<_ChartControls> {
  bool _isPlaying = false;
bool _autoStarted = false;
  SimulationEngine? _engine;

  int _speedLevel = 1; // 1,2,4,8
@override
void didChangeDependencies() {
  super.didChangeDependencies();

  final state = context.read<SimulationStateService>();

  if (!_autoStarted &&
      state.isActive &&
      state.simMinutes > 0) {

    _autoStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePlay(context);
    });
  }
}

  // ============================================================
  // PLAY
  // ============================================================

  Future<void> _handlePlay(BuildContext context) async {
  final stateService = context.read<SimulationStateService>();

  final bool isActive = stateService.isActive;
  final String? scenario = stateService.scenarioFile;
  final double price = stateService.startPrice;
  final savedMinute = stateService.simMinutes;

  if (!isActive) return;

  if (scenario == null || price == 0) {
    _showWarning(context);
    return;
  }

  if (_engine != null) {
    _engine!.resume();

    setState(() {
      _isPlaying = true;
    });

    debugPrint("▶️ Resume engine");
    return;
  }

  final deltas = await ScenarioLoader.loadDeltas(scenario);

  _engine = SimulationEngine(
    deltas: deltas,
    startPrice: price,
  );

  if (savedMinute > 0) {
    _engine!.restoreToIndex(savedMinute);

    double tempPrice = price;

    for (int i = 0; i < savedMinute; i++) {
      final delta = deltas[i];
      tempPrice = tempPrice * (1 + delta / 100);
      widget.onPrice(tempPrice);
    }
  }

  _engine!.priceStream.listen((newPrice) {
    widget.onPrice(newPrice);
  });

  _engine!.start();

  stateService.lockPrice();

  setState(() {
    _isPlaying = true;
  });

  debugPrint("🚀 Engine started");
}

  // ============================================================
  // PAUSE
  // ============================================================

  void _handlePause() {
  if (_engine == null) return;

  _engine!.pause();

  setState(() {
    _isPlaying = false;
  });

  debugPrint("⏸ Engine paused");
}



  // ============================================================
  // SPEED
  // ============================================================

  void _handleSpeed() {
    if (_engine == null) return;

    if (_speedLevel == 1) {
      _speedLevel = 2;
    } else if (_speedLevel == 2) {
      _speedLevel = 4;
    } else if (_speedLevel == 4) {
      _speedLevel = 8;
    } else {
      _speedLevel = 1;
    }

    _engine!.setSpeed(_speedLevel);

    debugPrint("⚡ Speed x$_speedLevel");
    setState(() {});
  }


  // ============================================================
  // WARNING
  // ============================================================

  void _showWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) =>  AlertDialog(
        title: Text(AppLocalization.t("insufficient_data")),
        content: Text(AppLocalization.t("enter_margin_and_price"),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 

final isActive = context.watch<SimulationStateService>().isActive;

if (!isActive && _engine != null) {
  debugPrint("🔥 UI state says STOP → stopping engine");

  _engine!.stop();
  _engine!.dispose();
  _engine = null;

  _speedLevel = 1; // ← СБРОС СКОРОСТИ

  final stateService = context.read<SimulationStateService>();
  stateService.clearScenario();
  stateService.setStartPrice(0.0);
  stateService.resetSimMinutes();

  setState(() {}); // ← чтобы обновился badge x1
}




   return Padding(
  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [

      // ===== ЛЕВАЯ ЧАСТЬ — КНОПКИ =====
      Row(
  children: [

    GestureDetector(
  onTap: () async => await _handlePlay(context),
  child: _ControlButton(
    icon: Icons.play_arrow,
    active: _isPlaying,
  ),
),

const SizedBox(width: 20),

GestureDetector(
  onTap: _handlePause,
  child: _ControlButton(
    icon: Icons.pause,
    active: !_isPlaying,
  ),
),
          const SizedBox(width: 20),

          GestureDetector(
            onTap: _handleSpeed,
            child: const _ControlButton(icon: Icons.fast_forward),
          ),
        ],
      ),

      // ===== ПРАВАЯ ЧАСТЬ — СКОРОСТЬ =====
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.bolt,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              "x$_speedLevel",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);

  }
}
class _SpeedBadge extends StatelessWidget {
  final int speed;

  const _SpeedBadge({required this.speed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    context.watch<LanguageProvider>(); 

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bolt,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            "x$speed",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}



class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool active;

  const _ControlButton({
    required this.icon,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    final theme = Theme.of(context);

    final primary = theme.colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),

        color: active
            ? primary.withOpacity(0.1)
            : theme.colorScheme.surfaceVariant,

        border: Border.all(
          color: active
              ? primary.withOpacity(0.4)
              : Colors.transparent,
        ),
      ),
      child: Icon(
        icon,
        color: active
            ? primary
            : theme.iconTheme.color,
      ),
    );
  }
}


///////////////////////////////////////////////////////////////
/// CONTROL
///////////////////////////////////////////////////////////////

class ControlSection extends StatefulWidget {
  final bool isSecondary;
  final bool isLong;
  final VoidCallback? onToggleDirection;
  final VoidCallback? onClose;

  const ControlSection({
    super.key,
    this.isSecondary = false,
    required this.isLong,
    this.onToggleDirection,
    this.onClose,
  });

  @override
  State<ControlSection> createState() => _ControlSectionState();
}

enum ProfitInputType { roi, pnl }

class _ControlSectionState extends State<ControlSection> {
  bool _previousSimulationState = false;
  int leverage = 5;

  String entryPrice = "";
  String margin = "";
  String positionSize = "";
  String positionCoef = "";

  String liquidationPrice = "";
  String roi = "";
  String pnlValue = "";

  /// 🔹 ДОБАВИТЬ ЭТО
  bool get positionCalculated {
    final stateService = context.read<SimulationStateService>();

    final pos = widget.isSecondary
        ? stateService.data.position2
        : stateService.data.position1;

    return pos.entry > 0 &&
           pos.margin > 0 &&
           pos.size > 0;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 

    final theme = Theme.of(context);

    final simulationService = context.watch<SimulationService>();
    final stateService = context.watch<SimulationStateService>();
    
    final storage = context.watch<DialogStorageService>();

    final bool isCross = !stateService.isIsolated;
    final bool isPro = simulationService.isProUser;
    final simData = stateService.data;

final simPosition = widget.isSecondary
    ? simData.position2
    : simData.position1;

final bool positionCalculated =
    simPosition.entry > 0 &&
    simPosition.margin > 0 &&
    simPosition.size > 0;

final bool isSimulationActive = stateService.isActive;
if (_previousSimulationState != isSimulationActive) {
  _previousSimulationState = isSimulationActive;
  _clearLocalUI();
}
    // ===== CROSS VALUES =====

    final crossTotalSize = widget.isSecondary
    ? storage.getValue(StoredField.sizeSecond)
    : storage.getValue(StoredField.sizeFirst);

final crossMarginRatio =
    storage.getValue(StoredField.marginRatio);

final crossLiquidation =
    storage.getValue(StoredField.liquidation);

final crossRoi = widget.isSecondary
    ? storage.getValue(StoredField.roiSecond)
    : storage.getValue(StoredField.roiFirst);

final crossPnl = widget.isSecondary
    ? storage.getValue(StoredField.pnlSecond)
    : storage.getValue(StoredField.pnlFirst);

    final bool showBalance =
        !widget.isSecondary &&
        isPro &&
        (isSimulationActive || !stateService.isIsolated);

        final entryFromStorage = widget.isSecondary
    ? storage.getValue(StoredField.entrySecond)
    : storage.getValue(StoredField.entryFirst);

final marginFromStorage = widget.isSecondary
    ? storage.getValue(StoredField.marginSecond)
    : storage.getValue(StoredField.marginFirst);

String displayEntry;
String displayMargin;

if (isSimulationActive) {
  displayEntry = simPosition.entry > 0
      ? simPosition.entry.toStringAsFixed(2)
      : "";

  displayMargin = simPosition.margin > 0
      ? simPosition.margin.toStringAsFixed(2)
      : "";
} else {
  displayEntry = isCross
      ? (entryFromStorage?.toStringAsFixed(2) ?? "")
      : entryPrice;

  displayMargin = isCross
      ? (marginFromStorage?.toStringAsFixed(2) ?? "")
      : margin;
}

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// HEADER
          Row(
            children: [
              Expanded(
                child: !isSimulationActive
                    ? Text(AppLocalization.t("calculater"),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : const SizedBox(),
              ),
              if (showBalance)
                const _BalanceView(),
            ],
          ),

          const SizedBox(height: 16),

          _topRow(),

          const SizedBox(height: 24),

          _editableRow(
  AppLocalization.t("enter_price"),
  displayEntry,
  (v) => entryPrice = v,
  StoredField.entryFirst,
  StoredField.entrySecond,
  AppLocalization.t("margin"),
  displayMargin,
  (v) => margin = v,
  StoredField.marginFirst,
  StoredField.marginSecond,
  positionCalculated,
),

          
            const SizedBox(height: 16),
            _staticRow(
  isCross: isCross,
  isSimulationActive: isSimulationActive,
  crossTotalSize: crossTotalSize,
  crossMarginRatio: crossMarginRatio,
),
          

          
  Row(
    children: [
      Expanded(
  child: (isCross || isSimulationActive)
      ? _staticBox(
          AppLocalization.t("liquidation_price"),
          isSimulationActive
    ? (simPosition.liquidation > 0
        ? simPosition.liquidation.toStringAsFixed(2)
        : "")
    : (isCross
        ? crossLiquidation?.toStringAsFixed(2) ?? ""
        : liquidationPrice),
        )
      : _inputBox(
    AppLocalization.t("liquidation_price"),
    liquidationPrice,
    (v) => setState(() => liquidationPrice = v),
    StoredField.liquidation,
    StoredField.liquidation,
    positionCalculated, // ← добавить
),
),
      const SizedBox(width: 16),
      Expanded(
  child: GestureDetector(
    onTap: () {
  final storage = context.read<DialogStorageService>();
  final marginMode = storage.getValue(StoredField.marginMode);
  final isCross = marginMode == 0;

  if (!isSimulationActive && !isCross) {
    _openProfitDialog();
  }
},
    child: Opacity(
      opacity: isSimulationActive ? 0.6 : 1,
      child: _profitCombinedBox(
        isCross: isCross,
        crossRoi: crossRoi,
        crossPnl: crossPnl,
      ),
    ),
  ),
),
    ],
  ),
          const SizedBox(height: 24),

          _actionButtons(),
        ],
      ),
    );
  }

  // ================= STATIC ROW =================

  Widget _staticRow({
  required bool isCross,
  required bool isSimulationActive,
  required double? crossTotalSize,
  required double? crossMarginRatio,
}) {

  final stateService = context.watch<SimulationStateService>();

  final simPosition = widget.isSecondary
      ? stateService.data.position2
      : stateService.data.position1;

  return Row(
    children: [
      Expanded(
        child: _staticBox(
          AppLocalization.t("position_size"),
          isSimulationActive
              ? (simPosition.size > 0
                  ? simPosition.size.toStringAsFixed(2)
                  : "")
              : isCross
                  ? crossTotalSize?.toStringAsFixed(2) ?? ""
                  : positionSize,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _staticBox(
          AppLocalization.t("position_coefficient"),
          isSimulationActive
              ? (simPosition.coef > 0
                  ? simPosition.coef.toStringAsFixed(2)
                  : "")
              : isCross
                  ? crossMarginRatio?.toStringAsFixed(2) ?? ""
                  : positionCoef,
        ),
      ),
    ],
  );
}

  // ================= PROFIT BOX =================

  Widget _profitCombinedBox({
  required bool isCross,
  required double? crossRoi,
  required double? crossPnl,
}) {

  final stateService = context.watch<SimulationStateService>();
  final isSimulationActive = stateService.isActive;

  final simPosition = widget.isSecondary
      ? stateService.data.position2
      : stateService.data.position1;

  String displayRoi;
  String displayPnl;

  if (isSimulationActive) {
    displayRoi = simPosition.roi != 0
        ? simPosition.roi.toStringAsFixed(2)
        : "";

    displayPnl = simPosition.pnl != 0
        ? simPosition.pnl.toStringAsFixed(2)
        : "";
  } else {
    displayRoi = isCross
        ? crossRoi?.toStringAsFixed(2) ?? ""
        : roi;

    displayPnl = isCross
        ? crossPnl?.toStringAsFixed(2) ?? ""
        : pnlValue;
  }

  final bool isNegative = displayRoi.startsWith("-");
  final Color valueColor =
      isNegative ? Colors.redAccent : Colors.green;

  final theme = Theme.of(context);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(AppLocalization.t("roi_pnl"), style: theme.textTheme.bodySmall),
      const SizedBox(height: 6),
      Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium,
            children: [
              TextSpan(
                text: displayRoi.isEmpty ? "—" : displayRoi,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: "  /  "),
              TextSpan(
                text: displayPnl.isEmpty ? "—" : displayPnl,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

  // ================= STATIC ROW =================



  Widget _staticBox(String label, String value) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(value.isEmpty ? "—" : value),
        ),
      ],
    );
  }

void _clearLocalUI() {
  entryPrice = "";
  margin = "";
  positionSize = "";
  positionCoef = "";
  liquidationPrice = "";
  roi = "";
  pnlValue = "";

  debugPrint("🧹 ControlSection UI cleared due to simulation mode change");
}
void _showClosePositionDialog() {
  final stateService = context.read<SimulationStateService>();

  final int positionIndex = widget.isSecondary ? 2 : 1;

  final amountController = TextEditingController();
  final priceController = TextEditingController();

  /// по умолчанию
  priceController.text = AppLocalization.t("market_price");

  final theme = Theme.of(context);

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title:  Text(AppLocalization.t("close_position")),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          /// СУММА
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:  InputDecoration(labelText: AppLocalization.t("amount")),
          ),

          const SizedBox(height: 12),

          /// ЦЕНА
          TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),

            onTap: () {
              if (priceController.text == AppLocalization.t("market_price")) {
                priceController.clear();
              }
            },

            decoration: InputDecoration(
              labelText: AppLocalization.t("price"),
            ),
          ),
        ],
      ),
      actions: [

        TextButton(
          onPressed: () => Navigator.pop(context),
          child:  Text(AppLocalization.t("cancel")),
        ),

        TextButton(
          onPressed: () async {

            final double? amount =
                double.tryParse(amountController.text);

            final double? price =
                priceController.text == AppLocalization.t("market_price")
                    ? null
                    : double.tryParse(priceController.text);

            if (amount == null) return;

            try {

              await stateService.closePosition(
                index: positionIndex,
                amount: amount,
                price: price,
              );

            } catch (e) {

              debugPrint("Ошибка закрытия позиции $e");

            }

            Navigator.pop(context);
          },
          child:  Text(AppLocalization.t("close")),
        ),
      ],
    ),
  );
}

void _handleMarginModeTap() {
  final simulationService = context.read<SimulationService>();
  final stateService = context.read<SimulationStateService>();

  if (simulationService.isProUser) {
    stateService.toggleMarginMode();   // ← ВАЖНО
  } else {
    _showCrossProDialog();
  }
}
void _showCrossProDialog() {
  showDialog(
    context: context,
    builder: (_) => const CrossProDialog(),
  );
}

  // ================= TOP ROW =================

  Widget _topRow() {
  if (widget.isSecondary) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _positionButton(),
          ),
        ),

        if (widget.onClose != null)
  GestureDetector(
    onTap: () async {
  final simulation =
      context.read<SimulationStateService>();

  // 🔥 Если симуляция активна
  if (simulation.isActive) {
    final pos = simulation.data.position2;

    final hasPositionData =
        pos.margin != 0 ||
        pos.entry != 0 ||
        pos.size != 0;

    final hasOrders =
        simulation.data.activeOrders.isNotEmpty;

    // 👉 Если пустой блок — можно закрывать
    if (!hasPositionData && !hasOrders) {
      await simulation.clearPosition(
        2,
        reason: "ui_close_second_empty",
      );

      widget.onClose?.call();
      return;
    }

    // 👉 Если есть данные — показать предупреждение
    showDialog(
      context: context,
      builder: (_) =>  AlertDialog(
        title: Text(AppLocalization.t("cannot_close_block")),
        content: Text(AppLocalization.t("block_has_data"),
        ),
      ),
    );

    return;
  }

  // 🔵 Обычный калькулятор
  final storage =
      context.read<DialogStorageService>();

  storage.clearSecondPosition();

  debugPrint("SECOND BLOCK CLOSED");

  widget.onClose?.call();
},
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.close,
        size: 18,
        color: Colors.white,
      ),
    ),
  ),
      ],
    );
  }

  return Row(
    children: [
      Flexible(
        flex: 3,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _positionButton(),
          ),
        ),
      ),
      Flexible(
        flex: 4,
        child: Center(child: _marginModeText()),
      ),
      Flexible(
        flex: 3,
        child: Align(
          alignment: Alignment.centerRight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _leverageButton(),
          ),
        ),
      ),
    ],
  );
}


Widget _positionButton() {

  final stateService = context.watch<SimulationStateService>();

  final pos = widget.isSecondary
    ? stateService.data.position2
    : stateService.data.position1;

final bool locked =
    stateService.isActive &&
    pos.entry > 0 &&
    pos.margin > 0 &&
    pos.size > 0;
  return GestureDetector(
    onTap: locked
        ? null
        : () async {

  final newSide = !widget.isLong;

  widget.onToggleDirection?.call();

  final storage = context.read<DialogStorageService>();
  final simulation = context.read<SimulationStateService>();

  final field = widget.isSecondary
      ? StoredField.positionSideSecond
      : StoredField.positionSideFirst;

  final oppositeField = widget.isSecondary
      ? StoredField.positionSideFirst
      : StoredField.positionSideSecond;

  if (simulation.isActive) {
    // 🔥 В симуляции всегда хедж
    storage.save(
      field: field,
      value: newSide ? 1 : -1,
      source: FieldSource.manual,
    );

    storage.save(
      field: oppositeField,
      value: newSide ? -1 : 1,
      source: FieldSource.calculation,
    );

    await simulation.setPositionSide(
      widget.isSecondary ? 2 : 1,
      newSide,
      reason: "ui_manual",
    );
  } else {
    // обычное поведение вне симуляции
    storage.save(
      field: field,
      value: newSide ? 1 : -1,
      source: FieldSource.manual,
    );
  }

  debugPrint("POSITION TOGGLED");
  debugPrint("BLOCK: ${widget.isSecondary ? "SECOND" : "FIRST"}");
  debugPrint("NEW SIDE: ${newSide ? "LONG" : "SHORT"}");
},
    child: AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  width: 110,
  padding: const EdgeInsets.symmetric(vertical: 12),
  decoration: BoxDecoration(
    color: widget.isLong
        ? AppColors.positive
        : AppColors.negative,
    borderRadius: BorderRadius.circular(14),
  ),
  alignment: Alignment.center,
  child: Text(
    widget.isLong
        ? AppLocalization.t("long")
        : AppLocalization.t("short"),
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.2,
      color: Colors.white,
    ),
  ),
),
  );
}



Widget _marginModeText() {
  final theme = Theme.of(context);
  final stateService = context.watch<SimulationStateService>();
  final storage = context.read<DialogStorageService>();

  return GestureDetector(
    onTap: () {
      final simulationService = context.read<SimulationService>();
      final stateService =
          context.read<SimulationStateService>();

      // 🔒 Блокировка если уже есть позиция
      if (stateService.isActive && stateService.hasPosition) {
        debugPrint("❌ Margin mode locked after position open");
        return;
      }

      // 🔒 PRO ограничение
      if (!simulationService.isProUser) {
        _showCrossProDialog();
        return;
      }

      // 1️⃣ Очистить данные перед переключением
      storage.clearForModeSwitch();

      // 2️⃣ Переключить режим
      stateService.toggleMarginMode();

      // 3️⃣ Сохранить новый режим
      final newIsolated = stateService.isIsolated;

      storage.save(
        field: StoredField.marginMode,
        value: newIsolated ? 1 : 0,
        source: FieldSource.manual,
      );

      debugPrint("MARGIN MODE TOGGLED");
      debugPrint("NEW MODE: ${newIsolated ? "ISOLATED" : "CROSS"}");
    },
    child: Text(
      stateService.isIsolated ? AppLocalization.t("isolated") : AppLocalization.t("cross"),
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}


  Widget _leverageButton() {
  final theme = Theme.of(context);

  final simulation = context.watch<SimulationStateService>();
  final storage = context.watch<DialogStorageService>();

  final isSimulation = simulation.isActive;

  /// 🔥 ЕДИНЫЙ SOURCE OF TRUTH
  final double lev = isSimulation
      ? simulation.data.leverage
      : (storage.getValue(StoredField.leverage) ?? 5);

  return GestureDetector(
    onTap: _showLeverageDialog,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("${AppLocalization.t("leverage")} ${lev}x"),
          const SizedBox(width: 6),
          Icon(Icons.keyboard_arrow_down,
              size: 20, color: theme.iconTheme.color),
        ],
      ),
    ),
  );
}
void _openProfitDialog() {
  ProfitInputType selectedType = ProfitInputType.roi;
  final controller = TextEditingController();
  final theme = Theme.of(context);

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setLocalState) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(AppLocalization.t("enter_profit")),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(
                    label: Text(AppLocalization.t("roi_percent")),
                    selected: selectedType == ProfitInputType.roi,
                    onSelected: (_) {
                      setLocalState(() {
                        selectedType = ProfitInputType.roi;
                      });
                    },
                  ),
                  ChoiceChip(
                    label: Text(AppLocalization.t("pnl")),
                    selected: selectedType == ProfitInputType.pnl,
                    onSelected: (_) {
                      setLocalState(() {
                        selectedType = ProfitInputType.pnl;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: selectedType == ProfitInputType.roi
                      ? AppLocalization.t("enter_roi")
                      : AppLocalization.t("enter_pnl"),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalization.t("cancel")),
            ),
            TextButton(
              onPressed: () {
                final textValue = controller.text;
                final parsed = double.tryParse(textValue);

                if (parsed != null) {
                  final simulation =
                      context.read<SimulationStateService>();

                  final storage =
                      context.read<DialogStorageService>();

                  final marginMode =
                      storage.getValue(StoredField.marginMode);
                  final bool isCross = marginMode == 0;

                  /// только для isolated и вне симуляции
                  if (!simulation.isActive && !isCross) {
                    /// очищаем текущую цену
                    if (simulation.startPrice != 0) {
                      simulation.setStartPrice(0);
                    }

                    /// очищаем альтернативное поле прибыли
                    setState(() {
                      if (selectedType == ProfitInputType.roi) {
                        pnlValue = "";
                      } else {
                        roi = "";
                      }
                    });
                  }

                  /// записываем введённое значение
                  setState(() {
                    if (selectedType == ProfitInputType.roi) {
                      roi = textValue;
                    } else {
                      pnlValue = textValue;
                    }
                  });

                  final field = selectedType == ProfitInputType.roi
                      ? (widget.isSecondary
                          ? StoredField.roiSecond
                          : StoredField.roiFirst)
                      : (widget.isSecondary
                          ? StoredField.pnlSecond
                          : StoredField.pnlFirst);

                  storage.save(
                    field: field,
                    value: parsed,
                    source: FieldSource.manual,
                  );

                  debugPrint("PROFIT UPDATED");
                  debugPrint(
                    "TYPE: ${selectedType == ProfitInputType.roi ? "ROI" : "PNL"}",
                  );
                  debugPrint(
                    "BLOCK: ${widget.isSecondary ? "SECOND" : "FIRST"}",
                  );
                  debugPrint("VALUE: $parsed");
                }

                Navigator.pop(context);
              },
              child: Text(AppLocalization.t("ok")),
            ),
          ],
        );
      },
    ),
  );
}

void _showLeverageDialog() {
  final controller =
      TextEditingController(text: leverage.toString());

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title:  Text(AppLocalization.t("enter_leverage")),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:  Text(AppLocalization.t("cancel")),
        ),
        TextButton(
          onPressed: () async {
  final value = int.tryParse(controller.text);

  final simulation =
    context.read<SimulationStateService>();

if (value != null && value > 0) {

  if (simulation.isActive &&
      simulation.hasPosition &&
      value < leverage) {

    debugPrint("❌ Cannot reduce leverage after position open");
    Navigator.pop(context);
    return;
  }

    // 1️⃣ Локально
    setState(() => leverage = value);

    // 2️⃣ Storage (как было)
    final storage = context.read<DialogStorageService>();

    storage.save(
      field: StoredField.leverage,
      value: value.toDouble(),
      source: FieldSource.manual,
    );

    if (simulation.isActive) {
      await simulation.setLeverage(
        value.toDouble(),
        reason: "ui_manual",
      );
    }

    debugPrint("LEVERAGE UPDATED");
    debugPrint("VALUE: $value");
  }

  Navigator.pop(context);
},
          child:  Text(AppLocalization.t("ok")),
        ),
      ],
    ),
  );
}

void _showAverageDialog(int positionIndex) {
  final theme = Theme.of(context);
  final storage = context.read<DialogStorageService>();
  final stateService = context.read<SimulationStateService>();

  final bool isSimulationActive = stateService.isActive;

  final marginMode = storage.getValue(StoredField.marginMode);
  final bool isCross = marginMode == 0;

  final marginController = TextEditingController();
final priceController = TextEditingController();

// ✅ ДОБАВИТЬ
if (isSimulationActive) {
  priceController.text = AppLocalization.t("market_price");
}

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(AppLocalization.t("average")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            /// МАРЖА
            TextField(
              controller: marginController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppLocalization.t("margin"),
              ),
            ),

            const SizedBox(height: 12),

            /// ЦЕНА
            TextField(
  controller: priceController,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  onTap: () {
    if (priceController.text ==
        AppLocalization.t("market_price")) {
      priceController.clear();
    }
  },
  decoration: InputDecoration(
    labelText: AppLocalization.t("price"),
    
    // ✅ ДОБАВИТЬ
    hintText: isSimulationActive
        ? AppLocalization.t("market_price")
        : null,
  ),
),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalization.t("cancel")),
          ),

          TextButton(
            onPressed: () async {

              final double? newMargin =
                  double.tryParse(marginController.text);

              final double? newPrice =
                  priceController.text ==
                          AppLocalization.t("market_price")
                      ? null
                      : double.tryParse(priceController.text);

              if (newMargin == null) return;

              /// ==========================
              /// СИМУЛЯЦИЯ
              /// ==========================
              if (isSimulationActive) {

                await stateService.averagePosition(
                  index: positionIndex,
                  margin: newMargin,
                  price: newPrice,
                );

                Navigator.pop(context);
                return;
              }

              /// ==========================
              /// ОБЫЧНЫЙ КАЛЬКУЛЯТОР
              /// ==========================
              if (newPrice == null) return;

              if (isCross) {

                _handleCrossAverage(
                  positionIndex: positionIndex,
                  margin: newMargin,
                  price: newPrice,
                );

              } else {

                _handleAverage(newMargin, newPrice);

              }

              Navigator.pop(context);
            },
            child: Text(AppLocalization.t("average")),
          ),
        ],
      ),
    ),
  );
}
void _handleCrossAverage({
  required int positionIndex,
  required double margin,
  required double price,
}) {
  final storage = context.read<DialogStorageService>();

  final lev =
      storage.getValue(StoredField.leverage) ?? leverage.toDouble();

  final entryField = positionIndex == 1
      ? StoredField.entryFirst
      : StoredField.entrySecond;

  final marginField = positionIndex == 1
      ? StoredField.marginFirst
      : StoredField.marginSecond;

  final oldEntry = storage.getValue(entryField);
  final oldMargin = storage.getValue(marginField);

  /// если позиция новая
  if (oldEntry == null || oldMargin == null) {
    storage.save(
      field: entryField,
      value: price,
      source: FieldSource.manual,
    );

    storage.save(
      field: marginField,
      value: margin,
      source: FieldSource.manual,
    );

    _handleCrossCalculate();
    return;
  }

  /// weighted average
  final oldSize = oldMargin * lev;
  final addSize = margin * lev;
  final totalSize = oldSize + addSize;

  if (totalSize <= 0) return;

  final newEntry =
      (oldEntry * oldSize + price * addSize) / totalSize;

  final newMargin = oldMargin + margin;

  storage.save(
    field: entryField,
    value: newEntry,
    source: FieldSource.calculation,
  );

  storage.save(
    field: marginField,
    value: newMargin,
    source: FieldSource.calculation,
  );

  _handleCrossCalculate();
}

  // ================= EDITABLE ROW =================

 Widget _editableRow(
  String label1,
  String value1,
  Function(String) setter1,
  StoredField firstField1,
  StoredField secondField1,

  String label2,
  String value2,
  Function(String) setter2,
  StoredField firstField2,
  StoredField secondField2,

  bool positionCalculated,
) {
  return Row(
    children: [
      Expanded(
        child: _inputBox(
          label1,
          value1,
          setter1,
          firstField1,
          secondField1,
          positionCalculated,
          isEntryField: true,
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _inputBox(
          label2,
          value2,
          setter2,
          firstField2,
          secondField2,
          positionCalculated,
        ),
      ),
    ],
  );
}


Widget _inputBox(
  String label,
  String value,
  Function(String) setter,
  StoredField firstField,
  StoredField secondField,
  bool positionCalculated, // ← добавить
  {bool isEntryField = false}
) {
  final theme = Theme.of(context);
  final stateService = context.watch<SimulationStateService>();
final isActive = stateService.isActive;

final bool locked =
    stateService.isActive &&
    positionCalculated &&
    isEntryField;

  return GestureDetector(
    onTap: locked
    ? null
    : () => _openInputDialog(
  label,
  setter,
  firstField,
  secondField,
  widget.isSecondary,
  isEntryField: isEntryField,
),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
  value.isEmpty
      ? (isEntryField && isActive
          ? AppLocalization.t("market_price")
          : AppLocalization.t("enter_value"))
      : value,
),
        ),
      ],
    ),
  );
}

  void _handleAverage(double addMargin, double addPrice) {
  final double? oldEntry = double.tryParse(entryPrice);
  final double? oldMargin = double.tryParse(margin);

  if (oldEntry == null || oldMargin == null) return;

  final double oldSize = oldMargin * leverage;
  final double newSize = addMargin * leverage;

  final double totalSize = oldSize + newSize;

  final double newEntry =
      (oldEntry * oldSize + addPrice * newSize) / totalSize;

  final double totalMargin = oldMargin + addMargin;

  final calculator = PositionCalculator(
    type: widget.isLong
        ? PositionType.long
        : PositionType.short,
    leverage: leverage.toDouble(),
  );

  calculator.setEntry(newEntry);
  calculator.setMargin(totalMargin);

  setState(() {
    entryPrice = newEntry.toStringAsFixed(2);
    margin = totalMargin.toStringAsFixed(2);
    positionSize =
        calculator.positionSize?.toStringAsFixed(2) ?? "";
    liquidationPrice =
        calculator.liquidation?.toStringAsFixed(2) ?? "";
  });
}

void _handleCalculate() {
  final stateService = context.read<SimulationStateService>();

  if (stateService.isIsolated) {
    _handleIsolatedCalculate();
  } else {
    _handleCrossCalculate(); // 🚧 пока заглушка
  }
}
void _handleIsolatedCalculate() {
  final double? entryVal = double.tryParse(entryPrice);
  final double? marginVal = double.tryParse(margin);
  if (entryVal == null || marginVal == null) {
  debugPrint("❌ INVALID INPUT");
  _showWarning(context);
  return;
}
  final double? liquidationVal = double.tryParse(liquidationPrice);

  final double? roiVal = double.tryParse(roi);
  final double? pnlVal = double.tryParse(pnlValue);

  final stateService = context.read<SimulationStateService>();
  final double? currentPrice =
      stateService.startPrice > 0 ? stateService.startPrice : null;

  final calculator = PositionCalculator(
    type: widget.isLong
        ? PositionType.long
        : PositionType.short,
    leverage: leverage.toDouble(),
  );

  if (entryVal != null) calculator.setEntry(entryVal);
  if (marginVal != null) calculator.setMargin(marginVal);

  if (entryVal != null &&
      liquidationVal != null &&
      marginVal == null) {
    calculator.setLiquidation(liquidationVal);
  }

  if (marginVal != null &&
      liquidationVal != null &&
      entryVal == null) {
    calculator.setLiquidation(liquidationVal);
  }

  if (currentPrice != null) {
    calculator.setCurrent(currentPrice);
  } else if (roiVal != null) {
    calculator.setROI(roiVal);
  } else if (pnlVal != null) {
    calculator.setPNL(pnlVal);
  } else {
    calculator.clearProfit();
  }

  // 🔥 ВАЖНО: калькулятор режим
  if (!stateService.isActive && calculator.current != null) {
    stateService.setStartPrice(calculator.current!);
  }

  setState(() {
    entryPrice = calculator.entry?.toStringAsFixed(2) ?? "";
    margin = calculator.margin?.toStringAsFixed(2) ?? "";
    liquidationPrice =
        calculator.liquidation?.toStringAsFixed(2) ?? "";
    positionSize =
        calculator.positionSize?.toStringAsFixed(2) ?? "";
    positionCoef =
        calculator.positionCoef.toStringAsFixed(2);
    roi =
        calculator.roi?.toStringAsFixed(2) ?? "";
    pnlValue =
        calculator.pnl?.toStringAsFixed(2) ?? "";
  });
}

void _handleSimulationCalculate() {
  final stateService = context.read<SimulationStateService>();
  final positionIndex = widget.isSecondary ? 2 : 1;

  final pos = positionIndex == 2
      ? stateService.data.position2
      : stateService.data.position1;

  if (!stateService.isActive) {
    debugPrint("❌ Not in simulation - skip engine");
    return;
  }

  final hasPrice = stateService.data.currentPrice > 0;
  final hasMargin = pos.margin > 0;

  if (!hasPrice || !hasMargin) {
    _showWarning(context);
    return;
  }

  /// =========================
  /// 🔥 CROSS MODE
  /// =========================
  if (!stateService.isIsolated) {
    debugPrint("🔥 Running cross mode for position $positionIndex");

    stateService.calculateCrossForPosition(
      positionIndex,
      reason: "ui_calculate_button_cross",
    );

    return;
  }

  /// =========================
  /// ✅ ISOLATED MODE
  /// =========================
  debugPrint("✅ Running isolated engine for position $positionIndex");

  stateService.calculateIsolatedForPosition(
    positionIndex,
    reason: "ui_calculate_button",
  );
}

void _showWarning(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) =>  AlertDialog(
      title: Text(AppLocalization.t("insufficient_data")),
      content: Text(
        AppLocalization.t("enter_margin_and_price"),
      ),
    ),
  );
}
void _handleCrossCalculate() {

  debugPrint("=========== CROSS CLICK ===========");

  final storage = context.read<DialogStorageService>();
  final stateService = context.read<SimulationStateService>();

  final balance = stateService.balance;

  final leverage =
      storage.getValue(StoredField.leverage);

  final firstSide =
      storage.getValue(StoredField.positionSideFirst);

  final firstEntry =
      storage.getValue(StoredField.entryFirst);

  final firstMargin =
      storage.getValue(StoredField.marginFirst);

  final secondSide =
      storage.getValue(StoredField.positionSideSecond);

  final secondEntry =
      storage.getValue(StoredField.entrySecond);

  final secondMargin =
      storage.getValue(StoredField.marginSecond);

  final current = stateService.data.currentPrice;

  // ================= VALIDATION =================

  if (
      leverage == null ||
      firstSide == null ||
      firstEntry == null ||
      firstMargin == null ||
      current == null) {

    debugPrint("❌ INVALID INPUT");
    _showWarning(context);
    return;
  }

  // ================= CREATE CALCULATOR =================

  final calc = CrossAccountCalculator(
    firstSide: firstSide.toInt(),
    leverage: leverage,
  );

  calc.setBalance(balance);
  calc.setEntry(firstEntry);
  calc.setMargin(firstMargin);
  calc.setCurrent(current);

  final hasSecond =
      secondSide != null &&
      secondEntry != null &&
      secondMargin != null;

  if (hasSecond) {
    calc.setSecondPosition(
      side: secondSide!.toInt(),
      entry: secondEntry!,
      margin: secondMargin!,
    );
  }

  // ================= POSITION 1 =================

  final sizeFirst = calc.firstPositionSize;
  final pnlFirst = calc.firstPnl;
  final roiFirst = calc.firstRoi;

  if (sizeFirst != null) {
    storage.save(
      field: StoredField.sizeFirst,
      value: sizeFirst,
      source: FieldSource.calculation,
    );
  }

  if (pnlFirst != null) {
    storage.save(
      field: StoredField.pnlFirst,
      value: pnlFirst,
      source: FieldSource.calculation,
    );
  }

  if (roiFirst != null) {
    storage.save(
      field: StoredField.roiFirst,
      value: roiFirst,
      source: FieldSource.calculation,
    );
  }

  // ================= POSITION 2 =================

  if (hasSecond) {

    final sizeSecond = calc.secondPositionSize;
    final pnlSecond = calc.secondPnl;
    final roiSecond = calc.secondRoi;

    if (sizeSecond != null) {
      storage.save(
        field: StoredField.sizeSecond,
        value: sizeSecond,
        source: FieldSource.calculation,
      );
    }

    if (pnlSecond != null) {
      storage.save(
        field: StoredField.pnlSecond,
        value: pnlSecond,
        source: FieldSource.calculation,
      );
    }

    if (roiSecond != null) {
      storage.save(
        field: StoredField.roiSecond,
        value: roiSecond,
        source: FieldSource.calculation,
      );
    }
  }

  // ================= ACCOUNT MARGIN RATIO =================

  final marginRatio = calc.marginRatio;

  if (marginRatio != null) {
    storage.save(
      field: StoredField.marginRatio,
      value: marginRatio,
      source: FieldSource.calculation,
    );
  }

  // ================= LIQUIDATION =================

  final liquidation = calc.liquidation;

  if (liquidation != null) {
    storage.save(
      field: StoredField.liquidation,
      value: liquidation,
      source: FieldSource.calculation,
    );
  }

  debugPrint("=========== END CALC ===========");
}


void _openInputDialog(
  String title,
  Function(String) setter,
  StoredField firstField,
  StoredField secondField,
  bool isSecondary, {
  bool isEntryField = false,
}) {
  final simulation = context.read<SimulationStateService>();

  final actualField =
      isSecondary ? secondField : firstField;

  final bool isMarginField =
      actualField == StoredField.marginFirst ||
      actualField == StoredField.marginSecond;

  final bool isLiquidationField =
      actualField == StoredField.liquidation;

  final pos = isSecondary
    ? simulation.data.position2
    : simulation.data.position1;

final bool positionLocked =
    simulation.isActive &&
    pos.entry > 0 &&
    pos.margin > 0 &&
    pos.size > 0 &&
    isMarginField;

  if (positionLocked) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalization.t("margin_locked")),
        content: Text(
          AppLocalization.t("margin_locked_text"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalization.t("understood")),
          ),
        ],
      ),
    );
    return;
  }

  final controller = TextEditingController();
  String? errorText;

  showDialog(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          void validateBalance() {
            final parsed = double.tryParse(controller.text);

            if (isMarginField &&
                simulation.isActive &&
                parsed != null &&
                parsed > simulation.balance) {
              errorText =
                  AppLocalization.t("insufficient_balance");
            } else {
              errorText = null;
            }

            setLocalState(() {});
          }

          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      errorText!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (simulation.isActive && isEntryField)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      AppLocalization.t("simulation_limit_order_hint"),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.orangeAccent),
                    ),
                  ),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => validateBalance(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalization.t("cancel")),
              ),
              TextButton(
                onPressed: () async {
                  final parsed =
                      double.tryParse(controller.text);

                  if (parsed == null) return;
                  if (errorText != null) return;

                  final storage =
                      context.read<DialogStorageService>();

                  /// isolated calculator:
                  /// если вводится liquidation,
                  /// и уже заполнены entry + margin,
                  /// очищаем entry
                  if (!simulation.isActive && isLiquidationField) {
                    final hasEntry = entryPrice.trim().isNotEmpty;
                    final hasMargin = margin.trim().isNotEmpty;

                    if (hasEntry && hasMargin) {
                      setState(() {
                        entryPrice = "";
                      });

                      debugPrint(
                        "ISOLATED CALC: entryPrice cleared because liquidation entered",
                      );
                    }
                  }

                  if (simulation.isActive) {
                    if (isEntryField) {
                      simulation.updatePosition(
                        isSecondary ? 2 : 1,
                        entry: parsed,
                        reason: "ui_entry_input",
                      );
                    }

                    if (isMarginField) {
                      await simulation.addMargin(
                        isSecondary ? 2 : 1,
                        parsed,
                        reason: "ui_input",
                      );
                    }
                  } else {
                    storage.save(
                      field: actualField,
                      value: parsed,
                      source: FieldSource.manual,
                    );
                  }

                  setState(() {
                    setter(controller.text);
                  });

                  Navigator.pop(context);
                },
                child: Text(AppLocalization.t("ok")),
              ),
            ],
          );
        },
      );
    },
  );
}
  // ================= ACTION BUTTONS =================

Widget _actionButtons() {
  final stateService = context.watch<SimulationStateService>();
  final bool isSimulationActive = stateService.isActive;

  // определяем из какого блока вызов
  final int positionIndex = widget.isSecondary ? 2 : 1;

  if (isSimulationActive) {

  if (!positionCalculated) {
    /// ДО расчета
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
  text: AppLocalization.t("average"),
  type: ActionButtonType.secondary,
  onTap: () {
    _showAverageHint(); // ✅ вместо диалога
  },
),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            text: AppLocalization.t("calculate"),
            type: ActionButtonType.primary,
            onTap: _handleSimulationCalculate,
          ),
        ),
      ],
    );
  }

  /// ПОСЛЕ расчета
  return Row(
    children: [
      Expanded(
        child: _ActionButton(
          text: AppLocalization.t("average"),
          type: ActionButtonType.secondary,
          onTap: () => _showAverageDialog(positionIndex),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _ActionButton(
          text: AppLocalization.t("close_position"),
          type: ActionButtonType.danger,
          onTap: _showClosePositionDialog,
        ),
      ),
    ],
  );
}

  return Row(
    children: [
      Expanded(
        child: _ActionButton(
          text: AppLocalization.t("average"),
          type: ActionButtonType.secondary,
          onTap: () => _showAverageDialog(positionIndex),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _ActionButton(
          text: AppLocalization.t("calculate"),
          type: ActionButtonType.primary,
          onTap: _handleCalculate,
        ),
      ),
    ],
  );
}
void _showAverageHint() {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(AppLocalization.t("average_locked")),
      content: Text(
        AppLocalization.t("average_locked_text"),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalization.t("understood")),
        ),
      ],
    ),
  );
}
}

enum ActionButtonType { primary, secondary, danger }


class _ActionButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final ActionButtonType type;

  const _ActionButton({
    required this.text,
    required this.onTap,
    required this.type,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  double scale = 1.0;

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    final theme = Theme.of(context);
    final isPrimary = widget.type == ActionButtonType.primary;
final isDanger = widget.type == ActionButtonType.danger;


    return GestureDetector(
      onTapDown: (_) => setState(() => scale = 0.96),
      onTapUp: (_) {
        setState(() => scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => scale = 1.0),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: scale,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
           color: isPrimary
    ? theme.colorScheme.primary
    : isDanger
        ? Colors.redAccent
        : theme.cardColor,

            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isPrimary || isDanger
    ? Colors.white
    : theme.textTheme.bodyMedium?.color,

            ),
          ),
        ),
      ),
    );
  }






  Widget _primaryWideButton(BuildContext context, String text) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(text),
    );
  }

  Widget _secondaryWideButton(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(text),
      ),
    );
  }


}


class _BalanceView extends StatefulWidget {
  const _BalanceView({super.key});

  @override
  State<_BalanceView> createState() => _BalanceViewState();
}

class _BalanceViewState extends State<_BalanceView> {

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    final theme = Theme.of(context);
    final stateService = context.watch<SimulationStateService>();

    final double balance = stateService.balance;

    return GestureDetector(
      onTap: () => _openBalanceDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
  "${AppLocalization.t("balance")}: ${balance.toStringAsFixed(2)}",
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

 void _openBalanceDialog(BuildContext context) {
  final stateService =
      context.read<SimulationStateService>();

  final controller =
      TextEditingController(
          text: stateService.balance.toStringAsFixed(2));

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title:  Text(AppLocalization.t("balance_edit")),
      content: TextField(
        controller: controller,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalization.t("cancel")),
        ),
        TextButton(
          onPressed: () async {
            final value =
                double.tryParse(controller.text);

            if (value != null && value >= 0) {

              // ✅ Сохраняем ТОЛЬКО в SimulationStateService
              await stateService.setBalance(value);

              debugPrint("BALANCE UPDATED");
              debugPrint("VALUE: $value");
            }

            Navigator.pop(context);
          },
          child: Text(AppLocalization.t("ok")),
        ),
      ],
    ),
  );
}

}




///////////////////////////////////////////////////////////////
/// EmptyDialog
///////////////////////////////////////////////////////////////


class _EmptyDialog extends StatelessWidget {
  final String title;

  const _EmptyDialog({required this.title});

  Future<List<dynamic>> _loadScenarios() async {
    final raw = await rootBundle
        .loadString('assets/scenarios/scenarios.json');
    return json.decode(raw);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        height: 400,
        child: FutureBuilder<List<dynamic>>(
          future: _loadScenarios(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final scenarios = snapshot.data!;

            return ListView.builder(
              itemCount: scenarios.length + 1,
              itemBuilder: (context, index) {

  /// =========================
  /// СЛУЧАЙНЫЙ СЦЕНАРИЙ
  /// =========================
  if (index == 0) {
    return ListTile(
      leading: const Icon(Icons.shuffle),
      title:  Text(AppLocalization.t("random_scenario")),
      subtitle:  Text(AppLocalization.t("choose_random_scenario")),
      onTap: () async {

        final random = Random();
        final scenario =
            scenarios[random.nextInt(scenarios.length)];

        final stateService =
            context.read<SimulationStateService>();

        final String fileName = scenario['file'];

        await stateService.setScenario(fileName);

        debugPrint("🎲 RANDOM SCENARIO: $fileName");

        Navigator.pop(context);
      },
    );
  }

  /// =========================
  /// ОБЫЧНЫЕ СЦЕНАРИИ
  /// =========================

  final scenario = scenarios[index - 1];

  return ListTile(
    leading: const Icon(Icons.show_chart),
    title: Text(scenario['name']),
    subtitle: Text(scenario['type']),
    onTap: () async {

      final stateService =
          context.read<SimulationStateService>();

      final String fileName = scenario['file'];

      await stateService.setScenario(fileName);

      debugPrint("Сценарий сохранён: $fileName");

      Navigator.pop(context);
    },
  );
},
            );
          },
        ),
      ),
    );
  }
}


///////////////////////////////////////////////////////////////
/// Simulation PRO Dialog
///////////////////////////////////////////////////////////////

class SimulationProDialog extends StatelessWidget {
  final bool freeAvailable;
  final VoidCallback onFreeTry;

  const SimulationProDialog({
    super.key,
    required this.freeAvailable,
    required this.onFreeTry,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                 Text(AppLocalization.t("pro_feature"),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
  freeAvailable
      ? AppLocalization.t("simulation_pro_text_free")
      : AppLocalization.t("simulation_pro_text_paid"),
      style: const TextStyle(height: 1.4),
),

                const SizedBox(height: 28),

                Row(
                  children: [

                    Expanded(
                      child: _DialogSecondaryButton(
                        text: AppLocalization.t("cancel"),
                        onTap: () => Navigator.pop(context),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: _DialogPrimaryButton(
                        text: freeAvailable
                            ? AppLocalization.t("simulation_try")
                            : AppLocalization.t("get_pro"),
                       onTap: () {
  if (freeAvailable) {
    Navigator.pop(context, "free");
  } else {
    Navigator.pop(context, "pro");
  }
},



                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _DialogPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _DialogPrimaryButton({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
class _DialogSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _DialogSecondaryButton({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ),
    );
  }
}
class CrossProDialog extends StatelessWidget {
  const CrossProDialog({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); 
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

             Text(
              AppLocalization.t("pro_feature"),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

             Text(AppLocalization.t("cross_pro_text"),
             style: const TextStyle(height: 1.4),
            ),

            const SizedBox(height: 24),

            Row(
              children: [

                Expanded(
                  child: _DialogSecondaryButton(
                    text: AppLocalization.t("close"),
                    onTap: () => Navigator.pop(context),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _DialogPrimaryButton(
                    text: AppLocalization.t("get_pro"),
                    onTap: () async {
  Navigator.pop(context);

  final result = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => const ProScreen(),
    ),
  );

  // если пользователь активировал PRO
  if (result == true) {
    // можно ничего не делать — Provider сам обновит UI
  }
},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
