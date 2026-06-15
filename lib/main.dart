import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:simulation_lab/core/services/simulation_service.dart';
import 'package:simulation_lab/core/services/simulation_state_service.dart';
import 'package:simulation_lab/core/services/dialog_storage_service.dart';

import 'package:simulation_lab/core/localization/app_localization.dart';
import 'package:simulation_lab/core/localization/language_provider.dart';

/// 🔥 ДОБАВЬ ЭТО
import 'package:simulation_lab/features/pro/subscription_service.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// язык устройства
  await AppLocalization.loadDeviceLanguage();

  runApp(
    MultiProvider(
      providers: [

        /// 🌍 язык
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(),
        ),

        /// 🧠 симуляция
        ChangeNotifierProvider(
          create: (_) => SimulationService(),
        ),

        /// 🔗 состояние симуляции
        ChangeNotifierProvider(
          create: (_) => SimulationStateService(),
        ),

        /// 💬 диалоги
        ChangeNotifierProvider(
          create: (_) => DialogStorageService(),
        ),

        /// 💰 ПОДПИСКА (🔥 ГЛАВНОЕ ДОБАВЛЕНИЕ)
        ChangeNotifierProxyProvider<SimulationService, SubscriptionService>(
          create: (context) => SubscriptionService(
            simulationService: context.read<SimulationService>(),
          ),
          update: (context, simService, previous) =>
              previous ?? SubscriptionService(simulationService: simService),
        ),
      ],
      child: const SimulationLabApp(),
    ),
  );
}