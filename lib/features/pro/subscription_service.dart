import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:simulation_lab/core/services/simulation_service.dart';
import 'package:simulation_lab/features/pro/subscription_ids.dart';

class SubscriptionService extends ChangeNotifier {
  SubscriptionService({
    required SimulationService simulationService,
  }) : _simulationService = simulationService;

  final InAppPurchase _iap = InAppPurchase.instance;
  final SimulationService _simulationService;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _initialized = false;
  bool _storeAvailable = false;
  bool _loading = false;
  bool _purchasePending = false;

  String? _errorMessage;
  Set<String> _notFoundIds = {};
  List<ProductDetails> _products = [];
  String? _activeProductId;

  bool get initialized => _initialized;
  bool get storeAvailable => _storeAvailable;
  bool get loading => _loading;
  bool get purchasePending => _purchasePending;
  String? get errorMessage => _errorMessage;
  Set<String> get notFoundIds => _notFoundIds;
  List<ProductDetails> get products => List.unmodifiable(_products);
  String? get activeProductId => _activeProductId;

  bool get hasActiveStoreSubscription => _activeProductId != null;
  bool get isPro => hasActiveStoreSubscription;

  Future<void> init() async {
    if (_initialized) return;

    _setLoading(true);

    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () => _purchaseSub?.cancel(),
      onError: (Object error) {
        _errorMessage = error.toString();
        _purchasePending = false;
        notifyListeners();
      },
    );

    _storeAvailable = await _iap.isAvailable();

    if (_storeAvailable) {
      await loadProducts();
      await refreshEntitlementsSilently();
    } else {
      _errorMessage = null;
      _notFoundIds = {};
      _products = [];
      _activeProductId = null;
    }

    await _syncSimulationProFlag();

    _initialized = true;
    _setLoading(false);
  }

  Future<void> loadProducts() async {
    final response = await _iap.queryProductDetails(SubscriptionIds.all);

    _notFoundIds = response.notFoundIDs.toSet();
    _products = [...response.productDetails]
      ..sort((a, b) => _sortIndex(a.id).compareTo(_sortIndex(b.id)));

    if (response.error != null) {
      _errorMessage = response.error!.message;
    } else {
      _errorMessage = null;
    }

    notifyListeners();
  }

  ProductDetails? productById(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  Future<void> buy(String productId) async {
    final product = productById(productId);
    if (product == null) {
      _errorMessage = 'Product not loaded: $productId';
      notifyListeners();
      return;
    }

    _purchasePending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final purchaseParam = _buildPurchaseParam(product);

      // Для подписок в in_app_purchase используется buyNonConsumable.
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _purchasePending = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  PurchaseParam _buildPurchaseParam(ProductDetails product) {
    if (Platform.isAndroid && product is GooglePlayProductDetails) {
      return GooglePlayPurchaseParam(
        productDetails: product,
        offerToken: product.offerToken,
      );
    }

    return PurchaseParam(productDetails: product);
  }

  Future<void> restorePurchases() async {
    if (!_storeAvailable) return;

    _errorMessage = null;
    _setLoading(true);

    try {
      await _iap.restorePurchases();

      // На Android дополнительно подтягиваем прошлые покупки.
      if (Platform.isAndroid) {
        await refreshEntitlementsSilently();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    await _syncSimulationProFlag();
    _setLoading(false);
  }

  Future<void> refreshEntitlementsSilently() async {
    if (!_storeAvailable) return;

    try {
      if (Platform.isAndroid) {
        final addition =
            _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();

        final response = await addition.queryPastPurchases();

        if (response.error != null) {
          _errorMessage = response.error!.message;
          notifyListeners();
          return;
        }

        String? latestKnownProduct;
        for (final purchase in response.pastPurchases) {
          if (SubscriptionIds.isKnown(purchase.productID)) {
            latestKnownProduct = purchase.productID;
          }
        }

        _activeProductId = latestKnownProduct;
      }

      // На iOS активная подписка обычно приходит через purchaseStream / restorePurchases.
    } catch (e) {
      _errorMessage = e.toString();
    }

    await _syncSimulationProFlag();
    notifyListeners();
  }

  Future<void> _onPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _purchasePending = true;
          notifyListeners();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final valid = await _verifyPurchaseLocally(purchaseDetails);

          if (valid) {
            _activeProductId = purchaseDetails.productID;
            await _syncSimulationProFlag();
            _errorMessage = null;
          } else {
            _errorMessage = 'Purchase verification failed.';
          }

          if (purchaseDetails.pendingCompletePurchase) {
            await _iap.completePurchase(purchaseDetails);
          }

          _purchasePending = false;
          notifyListeners();
          break;

        case PurchaseStatus.error:
          _purchasePending = false;
          _errorMessage = purchaseDetails.error?.message ?? 'Purchase error';

          if (purchaseDetails.pendingCompletePurchase) {
            await _iap.completePurchase(purchaseDetails);
          }

          notifyListeners();
          break;

        case PurchaseStatus.canceled:
          _purchasePending = false;
          notifyListeners();
          break;
      }
    }
  }

  Future<bool> _verifyPurchaseLocally(PurchaseDetails purchaseDetails) async {
    return SubscriptionIds.isKnown(purchaseDetails.productID);
  }

  Future<void> _syncSimulationProFlag() async {
    if (isPro) {
      await _simulationService.activatePro();
    } else {
      await _simulationService.deactivatePro();
    }
  }

  Future<void> openManageSubscriptions() async {
    final uri = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/account/subscriptions')
        : Uri.parse('https://play.google.com/store/account/subscriptions');

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> openTermsOfUse() async {
    final uri = Uri.parse('https://feofanovamathtutor.com/terms_simlab.html');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> openPrivacyPolicy() async {
    final uri = Uri.parse('https://feofanovamathtutor.com/terms_simlab.html');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String subscriptionFootnote({
    required String monthlyPrice,
    required String threeMonthsPrice,
    required String yearlyPrice,
  }) {
    return '''
1 Month: $monthlyPrice
3 Months: $threeMonthsPrice
1 Year: $yearlyPrice

Auto-renewable subscription. Payment is charged to your store account at confirmation of purchase. Subscription renews automatically unless canceled at least 24 hours before the end of the current period. You can manage and cancel your subscription in your Apple ID / Google Play account settings. Restore is available for returning users.
''';
  }

  int _sortIndex(String id) {
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

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}