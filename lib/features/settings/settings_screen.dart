import 'package:flutter/material.dart';
import 'package:simulation_lab/features/pro/pro_screen.dart';
import 'package:simulation_lab/features/settings/simulation_history_screen.dart';
import 'package:simulation_lab/core/localization/app_localization.dart';
import 'package:simulation_lab/core/localization/app_language.dart';
import 'package:simulation_lab/features/settings/language_screen.dart' hide languages;

class SettingsScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const SettingsScreen({
    super.key,
    required this.onToggleTheme,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  String _getCurrentLanguageName() {

    final current = AppLocalization.currentLanguage;

    final lang = languages.firstWhere(
      (e) => e.code == current,
      orElse: () => languages.first,
    );

    return "${lang.flag} ${lang.name}";
  }

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title:  Text(AppLocalization.t("settings")),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          _SettingsCard(
            children: [

              _SettingsTile(
                icon: Icons.language,
                title: AppLocalization.t("language"),
                subtitle: _getCurrentLanguageName(),
                onTap: () async {

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LanguageScreen(),
                    ),
                  );

                  setState(() {});
                },
              ),

              _SettingsTile(
                icon: Icons.brightness_6,
                title: AppLocalization.t("theme"),
                subtitle: AppLocalization.t("theme_light_dark"),
                onTap: widget.onToggleTheme,
              ),
            ],
          ),

          const SizedBox(height: 16),

          _SettingsCard(
            children: [

              _SettingsTile(
                icon: Icons.star,
                title: AppLocalization.t("pro_version"),
                subtitle: AppLocalization.t("open_pro_features"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          _SettingsCard(
            children: [

              _SettingsTile(
                icon: Icons.history,
                title: AppLocalization.t("simulation_history"),
                subtitle: AppLocalization.t("view_trades"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SimulationHistoryScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          _SettingsCard(
            children: [

               _PolicyTile(),

              _SettingsTile(
                icon: Icons.mail_outline,
                title: AppLocalization.t("contact"),
                subtitle: "support.simulationlab@gmail.com",
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 30),

          Center(
            child: Text(
              AppLocalization.t("app_version"),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        child: Row(
          children: [

            Icon(
              icon,
              color: theme.colorScheme.primary,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Icon(
              Icons.chevron_right,
              color: theme.iconTheme.color?.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyTile extends StatefulWidget {
  const _PolicyTile();

  @override
  State<_PolicyTile> createState() => _PolicyTileState();
}

class _PolicyTileState extends State<_PolicyTile> {

  bool expanded = false;

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(

        tilePadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 0,
        ),

        childrenPadding: EdgeInsets.zero,

        onExpansionChanged: (value) {
          setState(() {
            expanded = value;
          });
        },

        leading: Icon(
          Icons.privacy_tip_outlined,
          color: expanded
              ? Colors.grey
              : theme.colorScheme.primary,
        ),

        title: Text(
          AppLocalization.t("privacy_policy"),
          style: TextStyle(fontWeight: FontWeight.w600),
        ),

        children: [
          Padding(
            padding:  EdgeInsets.all(16),
            child: Text(AppLocalization.t("privacy_policy_text"),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}