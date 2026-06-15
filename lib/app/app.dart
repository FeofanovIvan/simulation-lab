import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/simulator/simulator_screen.dart';
import '../theme/app_theme.dart';
import '../core/localization/language_provider.dart';

class SimulationLabApp extends StatefulWidget {
  const SimulationLabApp({super.key});

  @override
  State<SimulationLabApp> createState() => _SimulationLabAppState();
}

class _SimulationLabAppState extends State<SimulationLabApp> {
  bool isDark = true;

  void toggleTheme() {
    setState(() {
      isDark = !isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Simulation Lab',

          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

          home: SimulatorScreen(
            onToggleTheme: toggleTheme,
          ),
        );

      },
    );
  }
}