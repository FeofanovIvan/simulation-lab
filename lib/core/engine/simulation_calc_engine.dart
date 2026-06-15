// lib/core/services/simulation_calc_engine.dart
import 'package:flutter/foundation.dart';

class IsolatedCalcInput {
  final bool isLong;
  final double leverage;
  final double currentPrice;
  final double margin;
  final double entryInput; // 0 => market

  const IsolatedCalcInput({
    required this.isLong,
    required this.leverage,
    required this.currentPrice,
    required this.margin,
    required this.entryInput,
  });
}

class IsolatedCalcResult {
  final bool shouldCreateLimitOrder;
  final double effectiveEntry;
  final double size; // NOTIONAL
  final double coef;
  final double liquidation;
  final double roi;
  final double pnl;

  final double? orderPrice;

  const IsolatedCalcResult({
    required this.shouldCreateLimitOrder,
    required this.effectiveEntry,
    required this.size,
    required this.coef,
    required this.liquidation,
    required this.roi,
    required this.pnl,
    this.orderPrice,
  });
}

class SimulationCalcEngine {

  // ===== Exchange params =====

  static const double maintenanceMarginRate = 0.004;
  static const double maintenanceAmount = 0;
  static const double feeRate = 0.0004;

  // =========================================================
  // MAIN ENTRY
  // =========================================================

  static IsolatedCalcResult computeIsolated(IsolatedCalcInput input) {

    final double lev = input.leverage <= 0 ? 1.0 : input.leverage;
    final double margin = input.margin <= 0 ? 0.0 : input.margin;
    final double cp = input.currentPrice;

    if (cp <= 0 || margin <= 0) {
      return const IsolatedCalcResult(
        shouldCreateLimitOrder: false,
        effectiveEntry: 0,
        size: 0,
        coef: 0,
        liquidation: 0,
        roi: 0,
        pnl: 0,
      );
    }

    final bool isLong = input.isLong;
    final double entryRaw = input.entryInput;

    // ===== MARKET ENTRY =====

    if (entryRaw <= 0) {
      final effectiveEntry = cp;

      return _calcFilled(
        isLong: isLong,
        leverage: lev,
        entry: effectiveEntry,
        currentPrice: cp,
        margin: margin,
      );
    }

    // ===== BUSINESS RULE =====

    final bool shortWantsSwitchToMarket = (!isLong && cp > entryRaw);
    final bool longWantsSwitchToMarket = (isLong && cp < entryRaw);

    if (shortWantsSwitchToMarket || longWantsSwitchToMarket) {

      final effectiveEntry = cp;

      return _calcFilled(
        isLong: isLong,
        leverage: lev,
        entry: effectiveEntry,
        currentPrice: cp,
        margin: margin,
      );
    }

    // ===== CREATE LIMIT ORDER =====

    return IsolatedCalcResult(
      shouldCreateLimitOrder: true,
      effectiveEntry: 0,
      size: 0,
      coef: 0,
      liquidation: 0,
      roi: 0,
      pnl: 0,
      orderPrice: entryRaw,
    );
  }

  // =========================================================
  // POSITION CALCULATION
  // =========================================================

  static IsolatedCalcResult _calcFilled({
    required bool isLong,
    required double leverage,
    required double entry,
    required double currentPrice,
    required double margin,
  }) {

    /// NOTIONAL VALUE
    final double size = margin * leverage;

    /// CONTRACTS (quantity)
    final double quantity = size / entry;

    /// PNL
    final double pnl = isLong
        ? (currentPrice - entry) * quantity
        : (entry - currentPrice) * quantity;

    /// ROI
    final double roi = (pnl / margin) * 100;

    /// NOTIONAL AT CURRENT PRICE
    final double notional = quantity * currentPrice;

    /// MAINTENANCE MARGIN
    final double maintenanceMargin =
        notional * maintenanceMarginRate - maintenanceAmount;

    /// MARGIN BALANCE
    final double marginBalance = margin + pnl;

    /// COEF (MARGIN RATIO)
    final double coef = marginBalance == 0
        ? 0
        : (maintenanceMargin / marginBalance) * 100;

    /// LIQUIDATION PRICE
    final double mmr = maintenanceMarginRate;

    final double liquidation = isLong
        ? entry * (1 - 1 / leverage) / (1 - mmr)
        : entry * (1 + 1 / leverage) / (1 + mmr);

    return IsolatedCalcResult(
      shouldCreateLimitOrder: false,
      effectiveEntry: entry,
      size: size,
      coef: coef,
      liquidation: liquidation,
      roi: roi,
      pnl: pnl,
    );
  }
}