// core/engine/position_calculator.dart

enum PositionType { long, short }

class PositionCalculator {
  PositionType type;
  double leverage;

  // ===== Биржевые параметры (новые) =====

  /// maintenance margin rate (пример: 0.005 = 0.5%)
  double maintenanceMarginRate;

  /// maintenance margin amount (для простого режима можно 0)
  double maintenanceAmount;

  /// taker fee rate (например 0.0004)
  double feeRate;

  // ===== Position block =====

  double? entry;
  double? margin;

  // liquidation вычисляется автоматически
  double? get liquidation {
    if (entry == null || leverage <= 0) return null;
    return _calculateLiquidation(entry!);
  }

  // ===== Profit block =====

  double? current;
  double? roi; // %
  double? pnl;

  PositionCalculator({
    required this.type,
    required this.leverage,
    this.maintenanceMarginRate = 0.004,
    this.maintenanceAmount = 0,
    this.feeRate = 0.0004,
  });

  // ================= DERIVED VALUES =================

  /// Notional size
  double? get positionSize {
    if (margin == null) return null;
    return margin! * leverage;
  }

  /// Quantity (размер позиции в монете)
  double? get quantity {
    if (entry == null || positionSize == null) return null;
    return positionSize! / entry!;
  }

  /// Margin coefficient (UI использует старое имя)
  /// Теперь это Initial Margin %
  double get positionCoef {
  final mm = maintenanceMargin;
  final mb = marginBalance;

  if (mm == null || mb == null || mb == 0) return 0;

  return (mm / mb) * 100;
}

  /// Maintenance margin
  double? get maintenanceMargin {
    final q = quantity;
    final price = current ?? entry;

    if (q == null || price == null) return null;

    final notional = q * price;
    return notional * maintenanceMarginRate - maintenanceAmount;
  }

  /// Margin balance
  double? get marginBalance {
    if (margin == null) return null;
    final upnl = pnl ?? 0;
    return margin! + upnl;
  }

  /// Margin ratio
  double? get marginRatio {
    final mm = maintenanceMargin;
    final mb = marginBalance;

    if (mm == null || mb == null || mb == 0) return null;

    return (mm / mb) * 100;
  }

  // ================= HELPERS =================

  void clearProfit() {
    current = null;
    roi = null;
    pnl = null;
  }

  // ================= ENTRY FROM PNL =================

  void calculateEntryFromPNL() {
    if (current == null || pnl == null || margin == null) return;

    final posSize = positionSize!;
    final priceChange = pnl! / posSize;

    if (type == PositionType.long) {
      entry = current! / (1 + priceChange);
    } else {
      entry = current! / (1 - priceChange);
    }

    _recalculateProfit();
  }

  // ================= ENTRY FROM ROI =================

  void calculateEntryFromROI() {
    if (current == null || roi == null) return;

    final r = roi! / 100;

    if (type == PositionType.long) {
      entry = current! / (1 + r / leverage);
    } else {
      entry = current! / (1 - r / leverage);
    }

    _recalculateProfit();
  }

  void setLiquidation(double value) {
    if (entry != null && margin == null) {
      margin = _calculateMarginFromLiquidation(entry!, value);
    }

    if (margin != null && entry == null) {
      entry = _calculateEntryFromLiquidation(margin!, value);
    }
  }

  // ================= POSITION INPUTS =================

  void setEntry(double value) {
    entry = value;
    _recalculateProfit();
  }

  void setMargin(double value) {
    margin = value;
  }

  void clearPositionInputs() {
    entry = null;
    margin = null;
    current = null;
    roi = null;
    pnl = null;
  }

  // ================= PROFIT INPUTS =================

  void setCurrent(double value) {
    current = value;
    roi = null;
    pnl = null;
    _recalculateProfit();
  }

  void setROI(double value) {
    roi = value;
    current = null;
    pnl = null;
    _recalculateProfit();
  }

  void setPNL(double value) {
    pnl = value;
    current = null;
    roi = null;
    _recalculateProfit();
  }

  // ================= PROFIT LOGIC =================

  void _recalculateProfit() {
    if (entry == null || leverage <= 0) return;

    // Current → ROI + PNL
    if (current != null) {
      final computedPNL = _calculatePNL(entry!, current!);
      pnl = computedPNL;
      roi = _calculateROIFromPNL(computedPNL);
      return;
    }

    // ROI → Current + PNL
    if (roi != null) {
      current = _calculatePriceFromROI(entry!, roi!);
      final computedPNL = _calculatePNL(entry!, current!);
      pnl = computedPNL;
      roi = _calculateROIFromPNL(computedPNL);
      return;
    }

    // PNL → Current + ROI
    if (pnl != null && margin != null) {
      current = _calculatePriceFromPNL(entry!, pnl!);
      roi = _calculateROIFromPNL(pnl!);
    }
  }

  // ================= FORMULAS =================

  double _calculateMarginFromLiquidation(double entry, double liquidation) {
    final diff = (entry - liquidation).abs();
    final positionSize = entry / diff;
    return positionSize / leverage;
  }

  double _calculateEntryFromLiquidation(double margin, double liquidation) {
    if (type == PositionType.long) {
      return liquidation * (1 - maintenanceMarginRate) / (1 - 1 / leverage);
    } else {
      return liquidation * (1 + maintenanceMarginRate) / (1 + 1 / leverage);
    }
  }

  double _calculateLiquidation(double entry) {
    final mmr = maintenanceMarginRate;

    if (type == PositionType.long) {
      final denom = 1 - mmr;
      if (denom <= 0) return 0;
      return entry * (1 - 1 / leverage) / denom;
    } else {
      return entry * (1 + 1 / leverage) / (1 + mmr);
    }
  }

  double _calculateROIFromPNL(double pnl) {
    if (margin == null || margin == 0) return 0;
    return (pnl / margin!) * 100;
  }

  double _calculatePNL(double entry, double current) {
    final q = quantity;

    if (q == null) return 0;

    if (type == PositionType.long) {
      return q * (current - entry);
    } else {
      return q * (entry - current);
    }
  }

  double _calculatePriceFromPNL(double entry, double pnlValue) {
    final q = quantity;

    if (q == null || q == 0) return entry;

    if (type == PositionType.long) {
      return entry + pnlValue / q;
    } else {
      return entry - pnlValue / q;
    }
  }

  double _calculateROI(double entry, double current) {
    if (type == PositionType.long) {
      return ((current - entry) / entry) * leverage * 100;
    } else {
      return ((entry - current) / entry) * leverage * 100;
    }
  }

  double _calculatePriceFromROI(double entry, double roiPercent) {
    final r = roiPercent / 100;

    if (type == PositionType.long) {
      return entry * (1 + r / leverage);
    } else {
      return entry * (1 - r / leverage);
    }
  }
}