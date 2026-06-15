class SubscriptionIds {
  static const String monthly = 'pro_monthly';
  static const String threeMonths = 'pro_3months';
  static const String yearly = 'pro_yearly';

  static const Set<String> all = {
    monthly,
    threeMonths,
    yearly,
  };

  static bool isKnown(String id) => all.contains(id);
}