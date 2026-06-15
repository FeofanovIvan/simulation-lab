import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:simulation_lab/core/services/language_service.dart';
import 'package:simulation_lab/core/localization/app_localization.dart';
import 'package:simulation_lab/core/localization/language_provider.dart';

class AppLanguage {
  final String name;
  final String code;
  final String flag;

  const AppLanguage(this.name, this.code, this.flag);
}

const List<AppLanguage> languages = [

  AppLanguage("English", "en", "🇬🇧"),
  AppLanguage("Русский", "ru", "🇷🇺"),
  AppLanguage("Português", "pt", "🇧🇷"),
  AppLanguage("Español", "es", "🇪🇸"),
  AppLanguage("Deutsch", "de", "🇩🇪"),
  AppLanguage("Français", "fr", "🇫🇷"),
  AppLanguage("Italiano", "it", "🇮🇹"),
  AppLanguage("中文", "zh", "🇨🇳"),
  AppLanguage("日本語", "ja", "🇯🇵"),
  AppLanguage("한국어", "ko", "🇰🇷"),
  AppLanguage("Türkçe", "tr", "🇹🇷"),
  AppLanguage("Hindi", "hi", "🇮🇳"),
];

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalization.t("language")),
      ),
      body: ListView.builder(
        itemCount: languages.length,
        itemBuilder: (context, index) {

          final lang = languages[index];

          return ListTile(
            leading: Text(
              lang.flag,
              style: const TextStyle(fontSize: 22),
            ),
            title: Text(lang.name),
            onTap: () async {

              /// сохраняем язык
              await LanguageService.saveLanguage(lang.code);

              /// меняем язык через provider
              await context.read<LanguageProvider>()
                  .changeLanguage(lang.code);

              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}