import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:simulation_lab/features/pro/subscription_ids.dart';

class SubscriptionPlan {
  final String id;
  final String title;
  final String subtitle;
  final String? badge;
  final bool highlighted;
  final ProductDetails? product;

  const SubscriptionPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.highlighted,
    required this.product,
  });

  String get displayPrice => product?.price ?? '...';

  static int sortIndex(String id) {
    switch (id) {
      case SubscriptionIds.monthly:
        return 0;
      case SubscriptionIds.threeMonths:
        return 1;
      case SubscriptionIds.yearly:
        return 2;
      default:
        return 99;
    }
  }
}