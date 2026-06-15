import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simulation_lab/core/services/simulation_journal_writer.dart';
import 'dart:convert';
import 'package:simulation_lab/core/engine/simulation_calc_engine.dart';



enum OrderStatus { pending, executed, canceled }

enum OrderType { limit }

enum OrderAction { buy, sell }

extension _EnumSer on Enum {
  String get s => name; // Dart 2.15+ (у тебя ok)
}

OrderStatus _orderStatusFrom(String? v) {
  switch (v) {
    case "executed":
      return OrderStatus.executed;
    case "canceled":
      return OrderStatus.canceled;
    case "pending":
    default:
      return OrderStatus.pending;
  }
}

OrderAction _orderActionFrom(String? v) {
  switch (v) {
    case "sell":
      return OrderAction.sell;
    case "buy":
    default:
      return OrderAction.buy;
  }
}

class OrderData {
  final String id;

  bool isLong;
  OrderAction action;
  double price;
  double margin;

  int createdMinute;
  int? executedMinute;

  OrderStatus status;

  OrderData({
    required this.id,
    required this.isLong,
    required this.action,
    required this.price,
    required this.margin,
    required this.createdMinute,
    this.executedMinute,
    this.status = OrderStatus.pending,
  });

  Map<String, dynamic> toJson() => {
        "id": id,
        "isLong": isLong,
        "action": action.s,
        "price": price,
        "margin": margin,
        "createdMinute": createdMinute,
        "executedMinute": executedMinute,
        "status": status.s,
      };

  factory OrderData.fromJson(Map<String, dynamic> json) {
    return OrderData(
      id: json["id"] ?? "",
      isLong: json["isLong"] ?? true,
      action: _orderActionFrom(json["action"]),
      price: (json["price"] ?? 0).toDouble(),
      margin: (json["margin"] ?? 0).toDouble(),
      createdMinute: (json["createdMinute"] ?? 0).toInt(),
      executedMinute: json["executedMinute"] == null
          ? null
          : (json["executedMinute"] ?? 0).toInt(),
      status: _orderStatusFrom(json["status"]),
    );
  }
}
class PositionData {
  bool isLong;
  double margin;
  double entry;
  double size;
  double coef;
  double liquidation;
  double roi;
  double pnl;

  PositionData({
    this.isLong = true,
    this.margin = 0,
    this.entry = 0,
    this.size = 0,
    this.coef = 0,
    this.liquidation = 0,
    this.roi = 0,
    this.pnl = 0,
  });

  Map<String, dynamic> toJson() => {
        "isLong": isLong,
        "margin": margin,
        "entry": entry,
        "size": size,
        "coef": coef,
        "liquidation": liquidation,
        "roi": roi,
        "pnl": pnl,
      };

  factory PositionData.fromJson(Map<String, dynamic> json) {
    return PositionData(
      isLong: json["isLong"] ?? true,
      margin: json["margin"] ?? 0,
      entry: json["entry"] ?? 0,
      size: json["size"] ?? 0,
      coef: json["coef"] ?? 0,
      liquidation: json["liquidation"] ?? 0,
      roi: json["roi"] ?? 0,
      pnl: json["pnl"] ?? 0,
    );
  }
}
class SimulationData {
  final String id; // session id

  // ✅ добавили
  bool isActive;
  String? scenarioFile;

  bool isIsolated;
  double leverage;

  double balance;
  double lockedBalance;
  double get totalBalance => balance + lockedBalance;
  double currentPrice;
  int simMinute;

  PositionData position1;
  PositionData position2;

  List<OrderData> activeOrders;
  List<OrderData> closedOrders;

  SimulationData({
    required this.id,

    // ✅ добавили
    this.isActive = false,
    this.scenarioFile,

    this.isIsolated = true,
    this.leverage = 5.0,
    this.balance = 0,
    this.lockedBalance = 0,
    this.currentPrice = 0,
    this.simMinute = 0,
    PositionData? position1,
    PositionData? position2,
    List<OrderData>? activeOrders,
    List<OrderData>? closedOrders,
  })  : position1 = position1 ?? PositionData(),
        position2 = position2 ?? PositionData(),
        activeOrders = activeOrders ?? [],
        closedOrders = closedOrders ?? [];
}



// ADD THIS import in the file (top):
// import 'dart:convert';

class SimulationStateService extends ChangeNotifier {
  final SimulationJournalWriter _journal = SimulationJournalWriter();
  
  String? get currentJournalPath => _journal.path;

  SimulationData _data = SimulationData(id: "initial");
  SimulationData get data => _data;

  // OLD (existing) keys
  static const _simulationActiveKey = "simulation_active";
  static const _startPriceKey = "simulation_start_price";
  static const _scenarioFileKey = "simulation_scenario_file";
  static const _balanceKey = "simulation_balance";
  static const _simMinutesKey = "simulation_minutes";
  static const _activeSessionIdKey = "active_session_id";

  // NEW (full model) keys — additional layer ONLY for persistence, old logic stays
  static const _mPrefix = "sim_model_";
  static const _mId = "${_mPrefix}id";
  static const _mIsActive = "${_mPrefix}isActive";
  static const _mScenarioFile = "${_mPrefix}scenarioFile";
  static const _mIsIsolated = "${_mPrefix}isIsolated";
  static const _mLeverage = "${_mPrefix}leverage";
  static const _mBalance = "${_mPrefix}balance";
  static const _mCurrentPrice = "${_mPrefix}currentPrice";
  static const _mSimMinute = "${_mPrefix}simMinute";

  static const _mP1Prefix = "${_mPrefix}p1_";
  static const _mP2Prefix = "${_mPrefix}p2_";
  static const _mPIsLong = "isLong";
  static const _mPMargin = "margin";
  static const _mPEntry = "entry";
  static const _mPSize = "size";
  static const _mPCoef = "coef";
  static const _mPLiq = "liquidation";
  static const _mPRoi = "roi";
  static const _mPPnl = "pnl";

  static const _mActiveOrders = "${_mPrefix}activeOrders";
  static const _mClosedOrders = "${_mPrefix}closedOrders";

  bool get hasPosition {
  return _data.position1.margin > 0 ||
         _data.position2.margin > 0;
}

  bool _isActive = false;
  bool get isActive => _isActive;

  bool _isIsolated = true;
  bool get isIsolated => _isIsolated;

  double _startPrice = 0.0;
  double get startPrice => _startPrice;

  double _balance = 0.0;
  double get balance => _balance;
  

  String? _scenarioFile;
  String? get scenarioFile => _scenarioFile;

  int _simMinutes = 0;
  int get simMinutes => _simMinutes;

  SimulationStateService() {
    _load();
  }
bool _priceLocked = false;
bool get priceLocked => _priceLocked;

void lockPrice() {
  if (_priceLocked) return;
  _priceLocked = true;
  notifyListeners();
}

void unlockPrice() {
  if (!_priceLocked) return;
  _priceLocked = false;
  notifyListeners();
}
  // =========================================================
  // FULL MODEL (additional) SAVE / LOAD / CLEAR
  // =========================================================

  Future<void> _saveFullModel(String reason) async {
    final prefs = await SharedPreferences.getInstance();

    // core
    await prefs.setString(_mId, _data.id);
    await prefs.setBool(_mIsActive, _data.isActive);
    if (_data.scenarioFile == null) {
      await prefs.remove(_mScenarioFile);
    } else {
      await prefs.setString(_mScenarioFile, _data.scenarioFile!);
    }
    await prefs.setBool(_mIsIsolated, _data.isIsolated);
    await prefs.setDouble(_mLeverage, _data.leverage);
    await prefs.setDouble(_mBalance, _data.balance);
    await prefs.setDouble(_mCurrentPrice, _data.currentPrice);
    await prefs.setInt(_mSimMinute, _data.simMinute);

    // positions
    Future<void> savePos(String prefix, PositionData p) async {
      await prefs.setBool("$prefix$_mPIsLong", p.isLong);
      await prefs.setDouble("$prefix$_mPMargin", p.margin);
      await prefs.setDouble("$prefix$_mPEntry", p.entry);
      await prefs.setDouble("$prefix$_mPSize", p.size);
      await prefs.setDouble("$prefix$_mPCoef", p.coef);
      await prefs.setDouble("$prefix$_mPLiq", p.liquidation);
      await prefs.setDouble("$prefix$_mPRoi", p.roi);
      await prefs.setDouble("$prefix$_mPPnl", p.pnl);
    }

    await savePos(_mP1Prefix, _data.position1);
    await savePos(_mP2Prefix, _data.position2);

    // orders (service-level json only; models untouched)
    final activeRaw = jsonEncode(_data.activeOrders.map((e) => e.toJson()).toList());
    final closedRaw = jsonEncode(_data.closedOrders.map((e) => e.toJson()).toList());
    await prefs.setString(_mActiveOrders, activeRaw);
    await prefs.setString(_mClosedOrders, closedRaw);

    debugPrint(
      "[SIM][FULL_SAVE][$reason] id=${_data.id} active=${_data.isActive} "
      "scenario=${_data.scenarioFile} iso=${_data.isIsolated} lev=${_data.leverage} "
      "bal=${_data.balance} price=${_data.currentPrice} min=${_data.simMinute} "
      "orders=${_data.activeOrders.length}/${_data.closedOrders.length}",
    );
  }

  Future<bool> _tryLoadFullModel() async {
    final prefs = await SharedPreferences.getInstance();

    final id = prefs.getString(_mId);
    if (id == null || id.isEmpty) {
      debugPrint("[SIM][FULL_LOAD] no full model stored");
      return false;
    }

    PositionData loadPos(String prefix) {
      return PositionData(
        isLong: prefs.getBool("$prefix$_mPIsLong") ?? true,
        margin: prefs.getDouble("$prefix$_mPMargin") ?? 0,
        entry: prefs.getDouble("$prefix$_mPEntry") ?? 0,
        size: prefs.getDouble("$prefix$_mPSize") ?? 0,
        coef: prefs.getDouble("$prefix$_mPCoef") ?? 0,
        liquidation: prefs.getDouble("$prefix$_mPLiq") ?? 0,
        roi: prefs.getDouble("$prefix$_mPRoi") ?? 0,
        pnl: prefs.getDouble("$prefix$_mPPnl") ?? 0,
      );
    }

    List<OrderData> loadOrders(String key) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];
      try {
        final list = (jsonDecode(raw) as List).cast<dynamic>();
        return list
            .whereType<Map>()
            .map((m) => OrderData.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      } catch (_) {
        return [];
      }
    }

    final loaded = SimulationData(
      id: id,
      isActive: prefs.getBool(_mIsActive) ?? false,
      scenarioFile: prefs.getString(_mScenarioFile),
      isIsolated: prefs.getBool(_mIsIsolated) ?? true,
      leverage: prefs.getDouble(_mLeverage) ?? 1.0,
      balance: prefs.getDouble(_mBalance) ?? 0,
      currentPrice: prefs.getDouble(_mCurrentPrice) ?? 0,
      simMinute: prefs.getInt(_mSimMinute) ?? 0,
      position1: loadPos(_mP1Prefix),
      position2: loadPos(_mP2Prefix),
      activeOrders: loadOrders(_mActiveOrders),
      closedOrders: loadOrders(_mClosedOrders),
    );

    _data = loaded;

    debugPrint(
      "[SIM][FULL_LOAD] id=${_data.id} active=${_data.isActive} "
      "scenario=${_data.scenarioFile} iso=${_data.isIsolated} lev=${_data.leverage} "
      "bal=${_data.balance} price=${_data.currentPrice} min=${_data.simMinute} "
      "orders=${_data.activeOrders.length}/${_data.closedOrders.length}",
    );
    return true;
  }

  Future<void> _clearFullModel() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_mId);
    await prefs.remove(_mIsActive);
    await prefs.remove(_mScenarioFile);
    await prefs.remove(_mIsIsolated);
    await prefs.remove(_mLeverage);
    await prefs.remove(_mBalance);
    await prefs.remove(_mCurrentPrice);
    await prefs.remove(_mSimMinute);

    Future<void> clearPos(String prefix) async {
      await prefs.remove("$prefix$_mPIsLong");
      await prefs.remove("$prefix$_mPMargin");
      await prefs.remove("$prefix$_mPEntry");
      await prefs.remove("$prefix$_mPSize");
      await prefs.remove("$prefix$_mPCoef");
      await prefs.remove("$prefix$_mPLiq");
      await prefs.remove("$prefix$_mPRoi");
      await prefs.remove("$prefix$_mPPnl");
    }

    await clearPos(_mP1Prefix);
    await clearPos(_mP2Prefix);

    await prefs.remove(_mActiveOrders);
    await prefs.remove(_mClosedOrders);

    debugPrint("[SIM][FULL_CLEAR] cleared");
  }

  // =========================================================
  // DIFF HELPERS
  // =========================================================

  Map<String, dynamic> _diffPosition(PositionData oldP, PositionData newP) {
    final diff = <String, dynamic>{};

    void putNum(String k, double a, double b) {
      if (a != b) diff[k] = {"from": a, "to": b};
    }

    if (oldP.isLong != newP.isLong) {
      diff["isLong"] = {"from": oldP.isLong, "to": newP.isLong};
    }
    putNum("margin", oldP.margin, newP.margin);
    putNum("entry", oldP.entry, newP.entry);
    putNum("size", oldP.size, newP.size);
    putNum("coef", oldP.coef, newP.coef);
    putNum("liquidation", oldP.liquidation, newP.liquidation);
    putNum("roi", oldP.roi, newP.roi);
    putNum("pnl", oldP.pnl, newP.pnl);

    return diff;
  }

  PositionData _copyPosition(PositionData p) => PositionData(
        isLong: p.isLong,
        margin: p.margin,
        entry: p.entry,
        size: p.size,
        coef: p.coef,
        liquidation: p.liquidation,
        roi: p.roi,
        pnl: p.pnl,
      );

  PositionData _getPos(int index) {
    if (index == 1) return _data.position1;
    if (index == 2) return _data.position2;
    throw ArgumentError("Position index must be 1 or 2");
  }

  // =========================================================
  // UPDATE POSITION
  // =========================================================

  void updatePosition(
    int index, {
    bool? isLong,
    double? margin,
    double? entry,
    double? size,
    double? coef,
    double? liquidation,
    double? roi,
    double? pnl,
    String reason = "manual",
  }) {
    final pos = _getPos(index);
    final before = _copyPosition(pos);

    if (isLong != null) pos.isLong = isLong;
    if (margin != null) pos.margin = margin;
    if (entry != null) pos.entry = entry;
    if (size != null) pos.size = size;
    if (coef != null) pos.coef = coef;
    if (liquidation != null) pos.liquidation = liquidation;
    if (roi != null) pos.roi = roi;
    if (pnl != null) pos.pnl = pnl;

    final diff = _diffPosition(before, pos);

    if (_isActive && diff.isNotEmpty) {
      _journal.appendEvent(
        minute: _data.simMinute,
        type: "position_updated",
        data: {
          "position": index,
          "reason": reason,
          "changes": diff,
        },
      );
    }

    _saveFullModel("updatePosition:$index/$reason");
    notifyListeners();
  }

  // =========================================================
  // ORDERS
  // =========================================================

  String _generateOrderId() => DateTime.now().microsecondsSinceEpoch.toString();

  OrderData createLimitOrder({
  required bool isLong,
  required OrderAction action,
  required double price,
  required double margin,
  bool reserveFromBalance = true,
}) {
  if (margin <= 0) {
    throw Exception("invalid_margin");
  }

  if (reserveFromBalance) {
    if (_data.balance < margin) {
      throw Exception("not_enough_balance");
    }

    _data.balance -= margin;
    _balance = _data.balance;
  }

  final order = OrderData(
    id: _generateOrderId(),
    isLong: isLong,
    action: action,
    price: price,
    margin: margin,
    createdMinute: _data.simMinute,
    status: OrderStatus.pending,
  );

  _data.activeOrders.add(order);

  if (_isActive) {
    _journal.appendEvent(
      minute: _data.simMinute,
      type: "order_created",
      data: {
        "order": order.toJson(),
        "reserveFromBalance": reserveFromBalance,
        "balance": _data.balance,
      },
    );
  }

  _saveFullModel("orderCreated");
  notifyListeners();
  return order;
}

  bool executeOrder(String orderId) {
    final idx = _data.activeOrders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return false;

    final order = _data.activeOrders.removeAt(idx);

    order.status = OrderStatus.executed;
    order.executedMinute = _data.simMinute;

    _data.closedOrders.add(order);

    if (_isActive) {
      _journal.appendEvent(
        minute: _data.simMinute,
        type: "order_executed",
        data: {
          "orderId": order.id,
          "executedMinute": order.executedMinute,
          "final": order.toJson(),
        },
      );
    }

    _saveFullModel("orderExecuted");
    notifyListeners();
    return true;
  }

  bool cancelOrder(String orderId) {
    final order = _data.activeOrders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => OrderData(
        id: "",
        isLong: true,
        action: OrderAction.buy,
        price: 0,
        margin: 0,
        createdMinute: 0,
      ),
    );

    if (order.id.isEmpty) return false;
    if (order.status != OrderStatus.pending) return false;

    order.status = OrderStatus.canceled;
    order.executedMinute = _data.simMinute;

    _data.activeOrders.removeWhere((o) => o.id == orderId);
_data.closedOrders.add(order);

// 💰 вернуть деньги
_data.balance += order.margin;
_balance = _data.balance;

    if (_isActive) {
      _journal.appendEvent(
        minute: _data.simMinute,
        type: "order_canceled",
        data: {
          "orderId": order.id,
          "canceledMinute": order.executedMinute,
          "final": order.toJson(),
        },
      );
    }

    _saveFullModel("orderCanceled");
    notifyListeners();
    return true;
  }

  // =========================================================
  // SYNC CORE STATE → ENGINE DATA
  // =========================================================

  void _syncCoreStateToEngine() {
    _data.balance = _balance;
    _data.simMinute = _simMinutes;
    _data.currentPrice = _startPrice;
    _data.isIsolated = _isIsolated;

    _data.isActive = _isActive;
    _data.scenarioFile = _scenarioFile;
  }

  // =========================================================
  // LOAD STATE
  // =========================================================

  Future<void> _load() async {
  final prefs = await SharedPreferences.getInstance();

  // 1) old storage
  _isActive = prefs.getBool(_simulationActiveKey) ?? false;
  final activeSessionId = prefs.getString(_activeSessionIdKey);

  _startPrice = prefs.getDouble(_startPriceKey) ?? 0.0;
  _scenarioFile = prefs.getString(_scenarioFileKey);
  _balance = prefs.getDouble(_balanceKey) ?? 0.0;
  _simMinutes = prefs.getInt(_simMinutesKey) ?? 0;

  // 2) try load full model
  final loadedFull = await _tryLoadFullModel();

  if (!loadedFull) {
    _syncCoreStateToEngine();
  } else {
    // align service fields with full model
    _isActive = _data.isActive;
    _scenarioFile = _data.scenarioFile;
    _isIsolated = _data.isIsolated;
    _balance = _data.balance;
    _startPrice = _data.currentPrice;
    _simMinutes = _data.simMinute;
  }

  // 3) FIXED: proper id sync (no == nonsense)
  if (_isActive && activeSessionId != null) {
    if (_data.id != activeSessionId) {
      _data = SimulationData(
        id: activeSessionId,
        isActive: _data.isActive,
        scenarioFile: _data.scenarioFile,
        isIsolated: _data.isIsolated,
        leverage: _data.leverage,
        balance: _data.balance,
        currentPrice: _data.currentPrice,
        simMinute: _data.simMinute,
        position1: _data.position1,
        position2: _data.position2,
        activeOrders: _data.activeOrders,
        closedOrders: _data.closedOrders,
      );
    }

    await _journal.resume(sessionId: activeSessionId);
  }

  await _saveFullModel("load");
  notifyListeners();
}
  // =========================================================
  // SIMULATION
  // =========================================================

  String _generateSessionId() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> startSimulation() async {
    final prefs = await SharedPreferences.getInstance();

    _isActive = true;

   _data = SimulationData(
  id: _generateSessionId(),
  isActive: true,
  scenarioFile: _scenarioFile,
  isIsolated: _isIsolated,
  balance: _balance,
  currentPrice: _startPrice,
  simMinute: _simMinutes,
  position1: PositionData(isLong: true),
  position2: PositionData(isLong: false),
);

    await prefs.setString(_activeSessionIdKey, _data.id);
    await prefs.setBool(_simulationActiveKey, true);

   await _journal.start(
  sessionId: _data.id,
  scenario: _scenarioFile,
  initialState: {
    "isIsolated": _data.isIsolated,
    "balance": _data.balance,
    "price": _data.currentPrice,
    "minute": _data.simMinute,
  },
);

    await _saveFullModel("startSimulation");
    notifyListeners();
  }

  Future<void> stopSimulation() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_simulationActiveKey, false);
    await prefs.remove(_activeSessionIdKey);

    await _journal.stop(
  ticks: _data.simMinute,
  finalState: {
    "balance": _data.balance,
    "price": _data.currentPrice,
    "minute": _data.simMinute,
    "isIsolated": _data.isIsolated,
  },
);

    // old keys cleanup (as-is)
    await prefs.remove(_startPriceKey);
    await prefs.remove(_scenarioFileKey);
    await prefs.remove(_simMinutesKey);
    await prefs.remove(_balanceKey); // 🔥 ДОБАВИЛИ


    // full model cleanup (new)
    await _clearFullModel();

    _isActive = false;
    _startPrice = 0.0;
    _scenarioFile = null;
    _simMinutes = 0;
    _balance = 0.0;

    // keep data object but reflect cleared state
    _data.isActive = false;
    _data.scenarioFile = null;
    _data.balance = 0;
    _data.currentPrice = 0;
    _data.simMinute = 0;

    // 🔥 очищаем позиции
  _data.position1 = PositionData();
  _data.position2 = PositionData();

  // 🔥 очищаем ордера
  _data.activeOrders.clear();
  _data.closedOrders.clear();

    _syncCoreStateToEngine();
    unlockPrice();
    notifyListeners();
  }

  // =========================================================
  // PRICE
  // =========================================================

Future<void> setStartPrice(double value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(_startPriceKey, value);

  final old = _startPrice;

  _startPrice = value;
  _data.currentPrice = value;

  if (_isActive && old != value) {
    _journal.appendEvent(
      minute: _data.simMinute,
      type: "start_price_set",
      data: {
        "from": old,
        "to": value,
      },
    );
  }

  await _processOrdersFromPriceTick();
  await recalcPnLFromPriceTick();
  await _checkLiquidationAndProfit();

  await _saveFullModel("setStartPrice");
  notifyListeners();
}

  // =========================================================
  // BALANCE
  // =========================================================

  Future<void> setBalance(double value) async {
    final old = _balance;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_balanceKey, value);

    _balance = value;
    _data.balance = value;
    _onBalanceChanged("setBalance");

    if (_isActive && old != value) {
      _journal.appendEvent(
        minute: _simMinutes,
        type: "balance_changed",
        data: {"from": old, "to": value},
      );
    }

    await _saveFullModel("setBalance");
    notifyListeners();
  }

  // =========================================================
  // SCENARIO
  // =========================================================

  Future<void> setScenario(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scenarioFileKey, fileName);

    final old = _scenarioFile;
    _scenarioFile = fileName;
    _data.scenarioFile = fileName;

   if (_isActive && old != fileName) {
  _journal.appendEvent(
    minute: _data.simMinute,
    type: "scenario_set",
    data: {
      "scenario": fileName
    },
  );
}

    await _saveFullModel("setScenario");
    notifyListeners();
  }

  // =========================================================
  // MARGIN MODE
  // =========================================================

Future<void> toggleMarginMode() async {
  final old = _isIsolated;

  _isIsolated = !_isIsolated;
  _data.isIsolated = _isIsolated;

  final isCross = !_data.isIsolated;

  if (isCross) {
    _data.position2.isLong = !_data.position1.isLong;
  }

  if (_isActive && old != _isIsolated) {
    _journal.appendEvent(
      minute: _simMinutes,
      type: "margin_mode_changed",
      data: {
        "from": old ? "isolated" : "cross",
        "to": _isIsolated ? "isolated" : "cross",
        "autoHedgeApplied": isCross,
        "p1": _data.position1.isLong,
        "p2": _data.position2.isLong,
      },
    );
  }

  await _saveFullModel("toggleMarginMode");
  notifyListeners();
}
  // =========================================================
  // CLEAR SCENARIO
  // =========================================================

  Future<void> clearScenario() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scenarioFileKey);

    _scenarioFile = null;
    _data.scenarioFile = null;

    await _saveFullModel("clearScenario");
    notifyListeners();
  }

  // =========================================================
  // MINUTES
  // =========================================================

  Future<void> resetSimMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_simMinutesKey, 0);

    _simMinutes = 0;
    _data.simMinute = 0;

    await _saveFullModel("resetSimMinutes");
    notifyListeners();
  }

  Future<void> addSimMinute() async {
    _simMinutes++;
    _data.simMinute = _simMinutes;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_simMinutesKey, _simMinutes);

    await _saveFullModel("addSimMinute");
    notifyListeners();
  }

  // =========================================================
  // Leverage
  // =========================================================

Future<void> setLeverage(double value, {String reason = "manual"}) async {
  final old = _data.leverage;
  if (old == value) return;

  _data.leverage = value;

  /// 🔥 ПЕРЕСЧЕТ ПОЗИЦИЙ
  if (_data.position1.margin > 0 && _data.position1.entry > 0) {
    _recalculatePosition(1);
  }

  if (_data.position2.margin > 0 && _data.position2.entry > 0) {
    _recalculatePosition(2);
  }

  if (_isActive) {
    _journal.appendEvent(
      minute: _data.simMinute,
      type: "leverage_changed",
      data: {
        "from": old,
        "to": value,
        "reason": reason,
      },
    );
  }

  await _saveFullModel("setLeverage:$reason");
  notifyListeners();
}
// =========================================================
  // PositionSide
  // =========================================================

Future<void> setPositionSide(
  int index,
  bool isLong, {
  String reason = "manual",
}) async {
  if (index != 1 && index != 2) {
    throw ArgumentError("Position index must be 1 or 2");
  }

  final p1 = _data.position1;
  final p2 = _data.position2;

  final old1 = p1.isLong;
  final old2 = p2.isLong;

  // 🔥 ВСЕГДА поддерживаем противоположность
  if (index == 1) {
    p1.isLong = isLong;
    p2.isLong = !isLong;
  } else {
    p2.isLong = isLong;
    p1.isLong = !isLong;
  }

  final changed1 = old1 != p1.isLong;
  final changed2 = old2 != p2.isLong;

  if (_isActive && (changed1 || changed2)) {
    _journal.appendEvent(
      minute: _data.simMinute,
      type: "side_changed",
      data: {
        "reason": reason,
        "p1": {"from": old1, "to": p1.isLong},
        "p2": {"from": old2, "to": p2.isLong},
        "requested": {"index": index, "isLong": isLong},
      },
    );
  }

  await _saveFullModel("setPositionSide:$index/$reason");
  notifyListeners();
}
// =========================================================
// ADD MARGIN
// =========================================================

Future<void> addMargin(
  int index,
  double amount, {
  String reason = "manual_add",
}) async {

  if (index != 1 && index != 2) {
    throw ArgumentError("Position index must be 1 or 2");
  }

  if (amount <= 0) return;

  // 🔴 Проверка баланса
  if (_data.balance < amount) {
    throw Exception("not_enough_balance");
  }

  final pos = _getPos(index);

  final oldMargin = pos.margin;
  final oldBalance = _data.balance;

  // 💰 списываем из баланса
  _data.balance -= amount;
  _balance = _data.balance;
  _onBalanceChanged("addMargin");

  // ➕ добавляем в маржу
  pos.margin += amount;

  if (_isActive) {
    _journal.appendEvent(
      minute: _data.simMinute,
      type: "margin_added",
      data: {
        "position": index,
        "reason": reason,
        "added": amount,
        "marginFrom": oldMargin,
        "marginTo": pos.margin,
        "balanceFrom": oldBalance,
        "balanceTo": _data.balance,
      },
    );
  }

  await _saveFullModel("addMargin:$index/$reason");
  notifyListeners();
}
// =========================================================
// ADD MARGIN
// =========================================================


Future<void> clearPosition(
  int index, {
  String reason = "manual_clear",
}) async {
  if (index != 1 && index != 2) {
    throw ArgumentError("Position index must be 1 or 2");
  }

  final pos = _getPos(index);
  final before = _copyPosition(pos);

  pos.margin = 0;
  pos.entry = 0;
  pos.size = 0;
  pos.coef = 0;
  pos.liquidation = 0;
  pos.roi = 0;
  pos.pnl = 0;

  if (_isActive) {
    _journal.appendEvent(
      minute: _data.simMinute,
      type: "position_cleared",
      data: {
        "position": index,
        "reason": reason,
        "before": before.toJson(),
      },
    );
  }

  await _saveFullModel("clearPosition:$index/$reason");
  notifyListeners();
}


// =========================================================
// calculate
// =========================================================


Future<void> calculateIsolatedForPosition(
  int index, {
  String reason = "ui_calculate",
}) async {
  if (index != 1 && index != 2) {
    throw ArgumentError("Position index must be 1 or 2");
  }

  final pos = _getPos(index);

  final input = IsolatedCalcInput(
    isLong: pos.isLong,
    leverage: _data.leverage,
    currentPrice: _data.currentPrice,
    margin: pos.margin,
    entryInput: pos.entry, // 0 => market
  );

  final res = SimulationCalcEngine.computeIsolated(input);

  // Если нужно создать лимитку — создаём ордер и очищаем позицию (entry+margin)
  if (res.shouldCreateLimitOrder) {
    final double orderPrice = res.orderPrice ?? pos.entry;

    createLimitOrder(
      isLong: pos.isLong,
      action: OrderAction.buy,
      price: orderPrice,
      margin: pos.margin,
    );

    // очищаем entry/margin как ты просила
    pos.entry = 0;
    pos.margin = 0;

    // Можно также очистить derived поля, чтобы UI был чистый
    pos.size = 0;
    pos.coef = 0;
    pos.liquidation = 0;
    pos.roi = 0;
    pos.pnl = 0;

    if (_isActive) {
      _journal.appendEvent(
        minute: _data.simMinute,
        type: "limit_order_created_from_entry",
        data: {
          "position": index,
          "reason": reason,
          "price": orderPrice,
          "margin": input.margin,
          "side": pos.isLong ? "long" : "short",
        },
      );
    }

    await _saveFullModel("calculateIsolated:$index/$reason/order");
    notifyListeners();
    return;
  }

  // Иначе — считаем позицию “исполненной” по effectiveEntry и записываем расчёты
  pos.entry = res.effectiveEntry;
  pos.size = res.size;
  pos.coef = res.coef;
  pos.liquidation = res.liquidation;
  pos.roi = res.roi;
  pos.pnl = res.pnl;

  if (_isActive) {
    _journal.appendEvent(
      minute: _data.simMinute,
      type: "isolated_calculated",
      data: {
        "position": index,
        "reason": reason,
        "entry": pos.entry,
        "margin": pos.margin,
        "size": pos.size,
        "liq": pos.liquidation,
        "roi": pos.roi,
        "pnl": pos.pnl,
      },
    );
  }

  await _saveFullModel("calculateIsolated:$index/$reason/fill");
  notifyListeners();
}
// =========================================================
// calculate
// =========================================================



Future<void> recalcPnLFromPriceTick() async {
  if (!_isActive) return;

  final current = _data.currentPrice;

  // =========================
  // POSITION 1
  // =========================

  final p1 = _data.position1;

  if (p1.margin > 0 && p1.entry > 0) {

    final contracts = p1.size / p1.entry;

    final pnl = p1.isLong
        ? (current - p1.entry) * contracts
        : (p1.entry - current) * contracts;

    final roi = (pnl / p1.margin) * 100;

    p1.pnl = pnl;
    p1.roi = roi;

    /// ✅ ISOLATED ONLY
    if (_data.isIsolated) {
      final notional = contracts * current;

      final maintenanceMargin =
          notional * SimulationCalcEngine.maintenanceMarginRate -
          SimulationCalcEngine.maintenanceAmount;

      final marginBalance = p1.margin + pnl;

      p1.coef = marginBalance == 0
          ? 0
          : (maintenanceMargin / marginBalance) * 100;
    }
  }

  // =========================
  // POSITION 2
  // =========================

  final p2 = _data.position2;

  if (p2.margin > 0 && p2.entry > 0) {

    final contracts = p2.size / p2.entry;

    final pnl = p2.isLong
        ? (current - p2.entry) * contracts
        : (p2.entry - current) * contracts;

    final roi = (pnl / p2.margin) * 100;

    p2.pnl = pnl;
    p2.roi = roi;

    /// ✅ ISOLATED ONLY
    if (_data.isIsolated) {
      final notional = contracts * current;

      final maintenanceMargin =
          notional * SimulationCalcEngine.maintenanceMarginRate -
          SimulationCalcEngine.maintenanceAmount;

      final marginBalance = p2.margin + pnl;

      p2.coef = marginBalance == 0
          ? 0
          : (maintenanceMargin / marginBalance) * 100;
    }
  }

  // =========================
  // 🔥 CROSS MODE (ГЛАВНОЕ)
  // =========================

  if (!_data.isIsolated) {
    final coef = _computeCrossCoefStub(1);
    final liq = _computeCrossLiquidationStub(1);

    _data.position1.coef = coef;
    _data.position2.coef = coef;

    _data.position1.liquidation = liq;
    _data.position2.liquidation = liq;
  }

  if (!_data.isIsolated) {
  _checkCrossLiquidationStub(1);
}

  notifyListeners();

}

// =========================================================
// average
// =========================================================


Future<void> averagePosition({
  required int index,
  required double margin,
  double? price,
  String reason = "ui_average",
}) async {

  final pos = _getPos(index);

  debugPrint("===== AVERAGE START =====");
  debugPrint("index=$index");
  debugPrint("input margin=$margin price=$price");
  debugPrint("current price=${_data.currentPrice}");
  debugPrint("balance before=${_data.balance}");
  debugPrint("position BEFORE=${pos.toJson()}");

  if (margin <= 0) return;

  if (_data.balance < margin) {
    throw Exception("not_enough_balance");
  }

  final current = _data.currentPrice;
  final bool isLong = pos.isLong;

  final bool marketExecution = price == null;

  /// =========================
  /// MARKET
  /// =========================
  if (marketExecution) {

    // 💰 списываем баланс
    _data.balance -= margin;
    _balance = _data.balance;

    final oldMargin = pos.margin;
    final oldEntry = pos.entry;

    final newMargin = oldMargin + margin;

    final newEntry = oldMargin == 0
        ? current
        : ((oldEntry * oldMargin) + (current * margin)) / newMargin;

    debugPrint("oldMargin=$oldMargin oldEntry=$oldEntry");
    debugPrint("newMargin=$newMargin newEntry=$newEntry");

    pos.margin = newMargin;
pos.entry = newEntry;

_recalculatePosition(index);

    /// 🔥 ENGINE
    final res = SimulationCalcEngine.computeIsolated(
      IsolatedCalcInput(
        isLong: pos.isLong,
        leverage: _data.leverage,
        currentPrice: _data.currentPrice,
        margin: pos.margin,
        entryInput: pos.entry,
      ),
    );

    debugPrint("===== ENGINE RESULT =====");
    debugPrint("size=${res.size}");
    debugPrint("coef=${res.coef}");
    debugPrint("liq=${res.liquidation}");
    debugPrint("roi=${res.roi}");
    debugPrint("pnl=${res.pnl}");

    /// ❗ защита от обнуления
    if (res.size > 0) {
      pos.size = res.size;
      pos.coef = res.coef;
      pos.liquidation = res.liquidation;
      pos.roi = res.roi;
      pos.pnl = res.pnl;
    } else {
      debugPrint("⚠️ ENGINE RETURNED ZERO — SKIPPED UPDATE");
    }

    if (_isActive) {
      _journal.appendEvent(
        minute: _data.simMinute,
        type: "position_averaged_market",
        data: {
          "position": index,
          "marginAdded": margin,
          "price": current,
          "newEntry": newEntry,
          "newMargin": newMargin,
        },
      );
    }

  }

  /// =========================
  /// LIMIT
  /// =========================
  else {

    debugPrint("LIMIT ORDER CREATED");

    createLimitOrder(
      isLong: isLong,
      action: OrderAction.buy,
      price: price!,
      margin: margin,
    );

    if (_isActive) {
      _journal.appendEvent(
        minute: _data.simMinute,
        type: "average_limit_order_created",
        data: {
          "position": index,
          "price": price,
          "margin": margin,
        },
      );
    }
  }

  debugPrint("position AFTER=${pos.toJson()}");
  debugPrint("balance AFTER=${_data.balance}");
  debugPrint("===== AVERAGE END =====");

  await _saveFullModel("averagePosition:$index/$reason");
  notifyListeners();
}

Future<void> closePosition({
  required int index,
  required double amount,
  double? price,
  String reason = "ui_close",
}) async {

  final pos = _getPos(index);

  if (amount <= 0) return;
  if (pos.margin < amount) {
    throw Exception("not_enough_margin");
  }

  final current = _data.currentPrice;
  final isLong = pos.isLong;

  /// =====================
  /// LIMIT CLOSE
  /// =====================
  if (price != null) {

    createLimitOrder(
  isLong: isLong,
  action: OrderAction.sell,
  price: price,
  margin: amount,
  reserveFromBalance: false,
);
    return;
  }

  /// =====================
  /// MARKET CLOSE
  /// =====================

  final double portion = amount / pos.margin;

  final double pnlPart = pos.pnl * portion;

  /// 💰 возврат
  _data.balance += amount + pnlPart;
  _balance = _data.balance;
_onBalanceChanged("closePosition");
  /// уменьшаем позицию
  pos.margin -= amount;

  if (pos.margin <= 0) {
    pos.margin = 0;
    pos.entry = 0;
    pos.size = 0;
    pos.coef = 0;
    pos.pnl = 0;
    pos.roi = 0;
    pos.liquidation = 0;
  } else {
    _recalculatePosition(index); // 🔥 ключ
  }

  if (_isActive) {
    _journal.appendEvent(
      minute: _data.simMinute,
      type: "position_closed_market",
      data: {
        "position": index,
        "amount": amount,
        "pnl": pnlPart,
        "balance": _data.balance,
      },
    );
  }

  await _saveFullModel("closePosition:$index/$reason");
  notifyListeners();
}
  /// =====================
  /// Orders
  /// =====================



Future<void> _processOrdersFromPriceTick() async {

  if (!_isActive) return;

  final current = _data.currentPrice;

  debugPrint("[ORDERS] checking priceTick price=$current orders=${_data.activeOrders.length}");

  final List<OrderData> executed = [];

  for (final order in _data.activeOrders) {

    bool shouldExecute = false;

    debugPrint(
      "[ORDER_CHECK] id=${order.id} "
      "side=${order.action.s} "
      "orderPrice=${order.price} "
      "currentPrice=$current"
    );

    /// 🔥 определяем позицию
    final pos = order.isLong
        ? (_data.position1.isLong ? _data.position1 : _data.position2)
        : (_data.position1.isLong ? _data.position2 : _data.position1);

    /// если позиции нет — пропускаем
    if (pos.entry <= 0) {
      debugPrint("[ORDER_SKIP] no position entry");
      continue;
    }

    /// =====================
    /// BUY
    /// =====================
    if (order.action == OrderAction.buy) {

      /// ниже входа → добор (limit)
      if (order.price <= pos.entry) {
        if (current <= order.price) {
          shouldExecute = true;
        }
      }

      /// выше входа → пробой (momentum)
      else {
        if (current >= order.price) {
          shouldExecute = true;
        }
      }
    }

    /// =====================
    /// SELL
    /// =====================
    if (order.action == OrderAction.sell) {

      /// выше входа → тейк
      if (order.price >= pos.entry) {
        if (current >= order.price) {
          shouldExecute = true;
        }
      }

      /// ниже входа → стоп
      else {
        if (current <= order.price) {
          shouldExecute = true;
        }
      }
    }

    debugPrint(
      "[ORDER_RESULT] id=${order.id} shouldExecute=$shouldExecute"
    );

    if (shouldExecute) {
      executed.add(order);
    }
  }

  /// =====================
  /// EXECUTION
  /// =====================
  for (final order in executed) {

    debugPrint(
      "[ORDER_EXECUTE] id=${order.id} "
      "side=${order.action.s} "
      "orderPrice=${order.price} "
      "currentPrice=$current"
    );

    _data.activeOrders.removeWhere((o) => o.id == order.id);

    order.status = OrderStatus.executed;
    order.executedMinute = _data.simMinute;

    _data.closedOrders.add(order);

    /// применяем к позиции
    _applyExecutedOrder(order);

    if (_isActive) {
      _journal.appendEvent(
        minute: _data.simMinute,
        type: "limit_order_triggered",
        data: {
          "orderId": order.id,
          "price": order.price,
          "margin": order.margin,
          "side": order.action.s,
        },
      );
    }
  }

  if (executed.isNotEmpty) {
    await _saveFullModel("ordersTriggered");
    notifyListeners();
  }
}
void _applyExecutedOrder(OrderData order) {

  final pos = order.isLong
      ? (_data.position1.isLong ? _data.position1 : _data.position2)
      : (_data.position1.isLong ? _data.position2 : _data.position1);

  final int index = pos == _data.position1 ? 1 : 2;

  /// =====================
  /// BUY → ДОБАВЛЯЕМ (усреднение)
  /// =====================
  if (order.action == OrderAction.buy) {

    final oldMargin = pos.margin;
    final oldEntry = pos.entry;

    final newMargin = oldMargin + order.margin;

    final newEntry = oldMargin == 0
        ? order.price
        : ((oldEntry * oldMargin) + (order.price * order.margin)) / newMargin;

    pos.margin = newMargin;
    pos.entry = newEntry;

    _recalculatePosition(index);
    return;
  }

  /// =====================
  /// SELL → ЗАКРЫВАЕМ
  /// =====================
  if (order.action == OrderAction.sell) {

    final amount = order.margin;

    if (pos.margin <= 0) return;

    final portion = amount / pos.margin;
    final pnlPart = pos.pnl * portion;

    /// 💰 возврат
    _data.balance += amount + pnlPart;
    _balance = _data.balance;
_onBalanceChanged("cancelOrder");
    pos.margin -= amount;

    if (pos.margin <= 0) {
      pos.margin = 0;
      pos.entry = 0;
      pos.size = 0;
      pos.coef = 0;
      pos.pnl = 0;
      pos.roi = 0;
      pos.liquidation = 0;
    } else {
      _recalculatePosition(index);
    }

    return;
  }
}
  /// =====================
  /// Liquidation
  /// =====================


Future<void> _checkLiquidationAndProfit() async {
  
  if (!_isActive) return;

  /// 🔥 ВАЖНО
  if (!_data.isIsolated) return;

  Future<void> checkPosition(int index) async {

    final pos = _getPos(index);

    if (pos.margin <= 0 || pos.entry <= 0) return;

    /// 💀 ЛИКВИДАЦИЯ (ROI <= -100%)
    if (pos.roi <= -100) {

      _logLiquidationEvent(
    "ISOLATED_ROI_100",
    extra: "position=$index roi=${pos.roi}",
  );

      final lostMargin = pos.margin;

      pos.margin = 0;
      pos.entry = 0;
      pos.size = 0;
      pos.coef = 0;
      pos.pnl = 0;
      pos.roi = 0;
      pos.liquidation = 0;

      if (_isActive) {
        _journal.appendEvent(
          minute: _data.simMinute,
          type: "position_liquidated",
          data: {
            "position": index,
            "lostMargin": lostMargin,
            "price": _data.currentPrice,
          },
        );
      }

      return;
    }

    /// 🚀 TAKE PROFIT (ROI >= 100%)
    if (pos.roi >= 100) {

      final profit = pos.margin * 2;

      _data.balance += profit;

      final closedMargin = pos.margin;

      pos.margin = 0;
      pos.entry = 0;
      pos.size = 0;
      pos.coef = 0;
      pos.pnl = 0;
      pos.roi = 0;
      pos.liquidation = 0;

      if (_isActive) {
        _journal.appendEvent(
          minute: _data.simMinute,
          type: "position_take_profit",
          data: {
            "position": index,
            "profit": profit,
            "closedMargin": closedMargin,
            "price": _data.currentPrice,
            "balance": _data.balance,
          },
        );
      }

    }

  }

  await checkPosition(1);
  await checkPosition(2);

}


void _recalculatePosition(int index) {
  final pos = _getPos(index);

  if (pos.margin <= 0 || pos.entry <= 0 || _data.currentPrice <= 0) {
    pos.size = 0;
    pos.pnl = 0;
    pos.roi = 0;

    /// ⚠️ сбрасываем только если isolated
    if (_data.isIsolated) {
      pos.coef = 0;
      pos.liquidation = 0;
    }

    return;
  }

  final double size = pos.margin * _data.leverage;
  final double quantity = size / pos.entry;

  final double pnl = pos.isLong
      ? (_data.currentPrice - pos.entry) * quantity
      : (pos.entry - _data.currentPrice) * quantity;

  final double roi = (pnl / pos.margin) * 100;

  pos.size = size;
  pos.pnl = pnl;
  pos.roi = roi;

  /// =========================
  /// ✅ ISOLATED ЛОГИКА
  /// =========================
  if (_data.isIsolated) {
    final double notional = quantity * _data.currentPrice;

    final double maintenanceMargin =
        notional * SimulationCalcEngine.maintenanceMarginRate -
        SimulationCalcEngine.maintenanceAmount;

    final double marginBalance = pos.margin + pnl;

    final double coef = marginBalance == 0
        ? 0
        : (maintenanceMargin / marginBalance) * 100;

    final double mmr = SimulationCalcEngine.maintenanceMarginRate;

    final double liquidation = pos.isLong
        ? pos.entry * (1 - 1 / _data.leverage) / (1 - mmr)
        : pos.entry * (1 + 1 / _data.leverage) / (1 + mmr);

    pos.coef = coef;
    pos.liquidation = liquidation;
  }

  /// =========================
  /// 🔥 CROSS ЛОГИКА
  /// =========================
  else {
    final coef = _computeCrossCoefStub(index);
    final liq = _computeCrossLiquidationStub(index);

    _data.position1.coef = coef;
    _data.position2.coef = coef;

    _data.position1.liquidation = liq;
    _data.position2.liquidation = liq;
  }
}







Future<void> calculateCrossForPosition(
  int index, {
  String reason = "ui_calculate_cross",
}) async {
  if (index != 1 && index != 2) {
    throw ArgumentError("Position index must be 1 or 2");
  }

  final pos = _getPos(index);

  /// =========================
  /// 1. СНАЧАЛА считаем саму позицию
  /// =========================
  final double effectiveEntry =
      pos.entry > 0 ? pos.entry : _data.currentPrice;

  final double size = pos.margin * _data.leverage;

  final double quantity =
      effectiveEntry == 0 ? 0 : size / effectiveEntry;

  final double pnl = pos.isLong
      ? (_data.currentPrice - effectiveEntry) * quantity
      : (effectiveEntry - _data.currentPrice) * quantity;

  final double roi =
      pos.margin == 0 ? 0 : (pnl / pos.margin) * 100;

  /// СНАЧАЛА записываем позицию в storage
  pos.entry = effectiveEntry;
  pos.size = size;
  pos.pnl = pnl;
  pos.roi = roi;

  /// =========================
  /// 2. ПОТОМ считаем общую liquidation
  /// =========================
  final double liquidation = _computeCrossLiquidationStub(index);

  final double coef = _computeCrossCoefStub(index);

  _checkCrossLiquidationStub(index);

  /// =========================
  /// 3. ПОТОМ записываем liquidation в обе позиции
  /// =========================
  _data.position1.liquidation = liquidation;
  _data.position2.liquidation = liquidation;

  /// coef пока оставляем как было задумано у тебя
  _data.position1.coef = coef;
  _data.position2.coef = coef;

  if (_isActive) {
    _journal.appendEvent(
      minute: _data.simMinute,
      type: "cross_calculated",
      data: {
        "position": index,
        "reason": reason,
        "entry": pos.entry,
        "margin": pos.margin,
        "size": pos.size,
        "roi": pos.roi,
        "pnl": pos.pnl,
        "liq": liquidation,
        "coef": coef,
      },
    );
  }

  await _saveFullModel("calculateCross:$index/$reason");
  notifyListeners();
}



double _computeCrossLiquidationStub(int index) {
  debugPrint("[CROSS][LIQUIDATION] START");

  final p1 = _data.position1;
  final p2 = _data.position2;

  final double balance = _data.totalBalance;
  final double lev = _data.leverage;

  const double mmr = SimulationCalcEngine.maintenanceMarginRate;

  final double size1 = (p1.margin > 0) ? p1.margin * lev : 0;
  final double size2 = (p2.margin > 0) ? p2.margin * lev : 0;

  if (size1 == 0 && size2 == 0) {
    debugPrint("[CROSS][LIQUIDATION] no positions");
    return 0.0;
  }

  final double totalPositionSize = size1 + size2;
  final double totalMargin = p1.margin + p2.margin;
  final double maintenanceMargin = totalPositionSize * mmr;

  double a = 0;
  double b = 0;

  /// ---- POSITION 1 ----
  if (size1 > 0 && p1.entry > 0) {
    if (p1.isLong) {
      a += size1 / p1.entry;
      b -= size1;
    } else {
      a -= size1 / p1.entry;
      b += size1;
    }
  }

  /// ---- POSITION 2 ----
  if (size2 > 0 && p2.entry > 0) {
    if (p2.isLong) {
      a += size2 / p2.entry;
      b -= size2;
    } else {
      a -= size2 / p2.entry;
      b += size2;
    }
  }

  debugPrint(
    "[CROSS][LIQUIDATION] "
    "p1={margin:${p1.margin},entry:${p1.entry},long:${p1.isLong}} "
    "p2={margin:${p2.margin},entry:${p2.entry},long:${p2.isLong}} "
    "balance=$balance totalMargin=$totalMargin mm=$maintenanceMargin a=$a b=$b"
  );

  if (a == 0) {
    debugPrint("[CROSS][LIQUIDATION] a=0 -> cannot solve");
    return 0.0;
  }

  final double liquidation =
      (maintenanceMargin - balance - totalMargin - b) / a;

  debugPrint("[CROSS][LIQUIDATION] result=$liquidation");

  return liquidation;
}



double _computeCrossCoefStub(int index) {
  debugPrint("[CROSS][COEF] START position=$index");

  final p1 = _data.position1;
  final p2 = _data.position2;

  final double lev = _data.leverage;
  final double current = _data.currentPrice;

  const double mmr = SimulationCalcEngine.maintenanceMarginRate;

  /// =========================
  /// SIZE
  /// =========================
  final double size1 =
      (p1.margin > 0) ? p1.margin * lev : 0;

  final double size2 =
      (p2.margin > 0) ? p2.margin * lev : 0;

  /// =========================
  /// PNL
  /// =========================
  double pnl1 = 0;
  double pnl2 = 0;

  if (size1 > 0 && p1.entry > 0 && current > 0) {
    pnl1 = p1.isLong
        ? size1 * ((current - p1.entry) / p1.entry)
        : size1 * ((p1.entry - current) / p1.entry);
  }

  if (size2 > 0 && p2.entry > 0 && current > 0) {
    pnl2 = p2.isLong
        ? size2 * ((current - p2.entry) / p2.entry)
        : size2 * ((p2.entry - current) / p2.entry);
  }

  final double totalPnl = pnl1 + pnl2;

  /// =========================
  /// TOTALS
  /// =========================
  final double totalPositionSize = size1 + size2;

  final double maintenanceMargin =
      totalPositionSize * mmr;

  /// =========================
  /// ✅ ПРАВИЛЬНАЯ EQUITY
  /// =========================
  final double equity = _data.totalBalance + totalPnl;

  debugPrint(
    "[CROSS][COEF] "
    "size=$totalPositionSize "
    "pnl=$totalPnl "
    "mm=$maintenanceMargin "
    "totalBalance=${_data.totalBalance} "
    "equity=$equity",
  );

  /// =========================
  /// RESULT
  /// =========================
  if (equity <= 0) {
    debugPrint("[CROSS][COEF] equity<=0 → 100%");
    return 100.0;
  }

  if (maintenanceMargin == 0) {
    debugPrint("[CROSS][COEF] mm=0 → 0%");
    return 0.0;
  }

  final double coef =
      (maintenanceMargin / equity) * 100;

  debugPrint("[CROSS][COEF] result=$coef");

  return coef;
}


void _checkCrossLiquidationStub(int index) {
  debugPrint("========== [CROSS][FLOW] START ==========");

  final p1 = _data.position1;
  final p2 = _data.position2;

  final double totalPnl = p1.pnl + p2.pnl;
  final double totalMargin = p1.margin + p2.margin;

  /// 🔥 1. считаем покрытие маржой
  final double afterMargin = totalMargin + totalPnl;

  debugPrint(
    "[FLOW] pnl=$totalPnl margin=$totalMargin afterMargin=$afterMargin"
  );

  /// =========================
  /// ✅ CASE 1: ВСЁ СНОВА ПОКРЫТО
  /// =========================
  if (afterMargin >= 0) {

    /// 🔥 ВОЗВРАТ ДЕНЕГ ИЗ LOCKED
    if (_data.lockedBalance > 0) {
      debugPrint(
        "[FLOW] recovery → unlock ${_data.lockedBalance}"
      );

      _data.balance += _data.lockedBalance;
      _data.lockedBalance = 0;

      /// синхронизация
      _balance = _data.balance;
    }

    debugPrint("[FLOW] margin absorbs loss → SAFE");
    debugPrint("========== [CROSS][FLOW] END ==========");

    notifyListeners();
    return;
  }

  /// =========================
  /// 🔥 CASE 2: НЕ ХВАТАЕТ МАРЖИ → ИДЕМ В БАЛАНС
  /// =========================

  final double neededFromBalance = -afterMargin;

  debugPrint(
    "[FLOW] margin exhausted → need $neededFromBalance from balance"
  );

  /// сколько уже "съели"
  final double alreadyLocked = _data.lockedBalance;

  /// 🔥 ВАЖНО: берём только ДЕЛЬТУ
  final double delta = neededFromBalance - alreadyLocked;

  if (delta > 0) {
    final double available = _data.balance;

    final double used = delta > available
        ? available
        : delta;

    _data.balance -= used;
    _data.lockedBalance += used;

    _balance = _data.balance;

    debugPrint(
      "[FLOW] transfer delta=$used balance=${_data.balance} locked=${_data.lockedBalance}"
    );
  } else {
    debugPrint("[FLOW] no additional transfer needed");
  }

  /// =========================
  /// 💀 LIQUIDATION
  /// =========================
  if (_data.balance <= 0) {
    debugPrint("[FLOW] BALANCE EMPTY → LIQUIDATION");

    _logLiquidationEvent("FINAL_LIQUIDATION");
    _liquidateAllPositions();
  }

  debugPrint("========== [CROSS][FLOW] END ==========");

  notifyListeners();
}




Future<void> _onBalanceChanged(String reason) async {
  debugPrint("[BALANCE_CHANGED] reason=$reason balance=${_data.balance}");

  if (!_isActive) return;

  await recalcPnLFromPriceTick();
}
void _liquidateAllPositions() {
  _logLiquidationEvent("FINAL_LIQUIDATION");
  final p1 = _data.position1;
  final p2 = _data.position2;

  p1.margin = 0;
  p1.entry = 0;
  p1.size = 0;
  p1.pnl = 0;
  p1.roi = 0;
  p1.coef = 0;
  p1.liquidation = 0;

  p2.margin = 0;
  p2.entry = 0;
  p2.size = 0;
  p2.pnl = 0;
  p2.roi = 0;
  p2.coef = 0;
  p2.liquidation = 0;

  debugPrint("[CROSS][RESET] all positions cleared");
}
void _logLiquidationEvent(String source, {String? extra}) {
  debugPrint("💀💀💀 LIQUIDATION TRIGGERED 💀💀💀");
  debugPrint("SOURCE = $source");
  debugPrint("price=${_data.currentPrice}");
  debugPrint("balance=${_data.balance}");
  debugPrint("locked=${_data.lockedBalance}");
  debugPrint("p1=${_data.position1.toJson()}");
  debugPrint("p2=${_data.position2.toJson()}");
  if (extra != null) debugPrint("extra=$extra");
}
}