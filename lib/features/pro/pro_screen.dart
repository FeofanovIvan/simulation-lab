import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:simulation_lab/core/localization/app_localization.dart';
import 'package:simulation_lab/features/pro/subscription_ids.dart';
import 'package:simulation_lab/features/pro/subscription_plan.dart';
import 'package:simulation_lab/features/pro/subscription_service.dart';

class ProScreen extends StatefulWidget {
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  String _selectedPlanId = SubscriptionIds.threeMonths;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<SubscriptionService>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SubscriptionService>();
    final t = AppLocalization.t;

    final plans = [
      SubscriptionPlan(
        id: SubscriptionIds.monthly,
        title: t('pro_monthly_title'),
        subtitle: t('pro_monthly_subtitle'),
        badge: null,
        highlighted: false,
        product: service.productById(SubscriptionIds.monthly),
      ),
      SubscriptionPlan(
        id: SubscriptionIds.threeMonths,
        title: t('pro_3months_title'),
        subtitle: t('pro_3months_subtitle'),
        badge: t('pro_most_popular'),
        highlighted: true,
        product: service.productById(SubscriptionIds.threeMonths),
      ),
      SubscriptionPlan(
        id: SubscriptionIds.yearly,
        title: t('pro_yearly_title'),
        subtitle: t('pro_yearly_subtitle'),
        badge: t('pro_best_value'),
        highlighted: false,
        product: service.productById(SubscriptionIds.yearly),
      ),
    ];

    final selectedPlan = plans.firstWhere((e) => e.id == _selectedPlanId);

    final footnote = service.subscriptionFootnote(
      monthlyPrice: service.productById(SubscriptionIds.monthly)?.price ?? '—',
      threeMonthsPrice:
          service.productById(SubscriptionIds.threeMonths)?.price ?? '—',
      yearlyPrice: service.productById(SubscriptionIds.yearly)?.price ?? '—',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(t('pro_title')),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await service.loadProducts();
                await service.refreshEntitlementsSilently();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeaderCard(isPro: service.isPro),
                  const SizedBox(height: 16),

                  if (service.errorMessage != null)
                    _ErrorCard(message: service.errorMessage!),

                  if (service.notFoundIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${t('products_not_found')}: ${service.notFoundIds.join(', ')}',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),

                  ...plans.map(
                    (plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PlanCard(
                        plan: plan,
                        isSelected: _selectedPlanId == plan.id,
                        isCurrentStorePlan: service.activeProductId == plan.id,
                        onTap: () {
                          setState(() {
                            _selectedPlanId = plan.id;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: service.purchasePending ||
                              selectedPlan.product == null
                          ? null
                          : () => service.buy(selectedPlan.id),
                      child: Text(
                        selectedPlan.product == null
                            ? t('pro_store_unavailable')
                            : t('pro_subscribe'),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const _ActionButtons(),

                  const SizedBox(height: 16),

                  const _LegalLinks(),

                  const SizedBox(height: 16),

                  Text(
                    footnote,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (service.loading || service.purchasePending)
            const _BlockingLoader(),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.isPro,
  });

  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalization.t;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.workspace_premium, size: 48),
            const SizedBox(height: 12),
            Text(
              t('pro_unlock_title'),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              t('pro_unlock_subtitle'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (isPro)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.green.withOpacity(0.12),
                ),
                child: Text(
                  t('pro_active'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.isCurrentStorePlan,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool isSelected;
  final bool isCurrentStorePlan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalization.t;
    final cs = Theme.of(context).colorScheme;

    final borderColor = isSelected ? cs.primary : Colors.transparent;
    final borderWidth = isSelected ? 1.8 : 1.0;
    final backgroundColor =
        isSelected ? cs.primary.withOpacity(0.06) : null;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Card(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: borderColor,
            width: borderWidth,
          ),
        ),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (plan.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: cs.primary.withOpacity(0.10),
                      ),
                      child: Text(
                        plan.badge!,
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(plan.subtitle),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  plan.displayPrice,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                    color: isSelected ? cs.primary : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCurrentStorePlan
                        ? t('pro_current')
                        : isSelected
                            ? t('pro_selected')
                            : t('pro_tap_to_select'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    final service = context.read<SubscriptionService>();
    final t = AppLocalization.t;

    return Column(
      children: [
        TextButton(
          onPressed: service.restorePurchases,
          child: Text(t('pro_restore')),
        ),
        TextButton(
          onPressed: service.openManageSubscriptions,
          child: Text(t('pro_manage')),
        ),
      ],
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    final service = context.read<SubscriptionService>();
    final t = AppLocalization.t;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: service.openTermsOfUse,
          child: Text(t('terms')),
        ),
        OutlinedButton(
          onPressed: service.openPrivacyPolicy,
          child: Text(t('privacy')),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}

class _BlockingLoader extends StatelessWidget {
  const _BlockingLoader();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalization.t;

    return ColoredBox(
      color: Colors.black26,
      child: Center(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(t('please_wait')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}