class CrossAccountCalculator {
  // 1 = long, -1 = short
  final int firstSide;
  final double leverage;

  // ===== FIRST POSITION =====
  double? entry;
  double? margin;

  // ===== SECOND POSITION =====
  int? secondSide;
  double? secondEntry;
  double? secondMargin;

  // ===== COMMON =====
  double? balance;
  double? current;

  CrossAccountCalculator({
    required this.firstSide,
    required this.leverage,
  });

  static const double maintenanceMarginRate = 0.004; // 0.5%

double? get equity {
  if (balance != null && balance! > 0) {
    return balance! + totalPnl;
  }

  final m = totalMargin;
  if (m == null) return null;

  return m + totalPnl;
}

  // =========================================================
  // POSITION 1
  // =========================================================

  double? get firstPositionSize {
    if (margin == null) return null;
    return margin! * leverage;
  }



  double? get firstPnl {
  print("INPUTS => firstSide:$firstSide entry:$entry margin:$margin "
        "secondSide:$secondSide secondEntry:$secondEntry secondMargin:$secondMargin "
        "leverage:$leverage balance:$balance current:$current");

  if (current == null || current == 0 || entry == null || firstPositionSize == null) {
    return null;
  }

  return firstSide == 1
      ? firstPositionSize! * ((current! - entry!) / entry!)
      : firstPositionSize! * ((entry! - current!) / entry!);
}

  double? get firstRoi {
    if (firstPnl == null || margin == null || margin == 0) {
      return null;
    }

    return (firstPnl! / margin!) * 100;
  }

  // =========================================================
  // POSITION 2
  // =========================================================

  double? get secondPositionSize {
    if (secondMargin == null) return null;
    return secondMargin! * leverage;
  }



  double? get secondPnl {
    if (current == null ||
     current == 0 ||
        secondEntry == null ||
        secondPositionSize == null ||
        secondSide == null) {
      return null;
    }

    if (secondSide == 1) {
      return secondPositionSize! * ((current! - secondEntry!) / secondEntry!);
    } else {
      return secondPositionSize! * ((secondEntry! - current!) / secondEntry!);
    }
  }

  double? get secondRoi {
    if (secondPnl == null || secondMargin == null || secondMargin == 0) {
      return null;
    }

    return (secondPnl! / secondMargin!) * 100;
  }

  // =========================================================
  // ACCOUNT TOTALS
  // =========================================================

  double get totalPnl {
    return (firstPnl ?? 0) + (secondPnl ?? 0);
  }

  double get totalPositionSize {
    return (firstPositionSize ?? 0) + (secondPositionSize ?? 0);
  }

  double? get maintenanceMargin {
    if (totalPositionSize == 0) return null;
    return totalPositionSize * maintenanceMarginRate;
  }

  double? get totalMargin {
  return (margin ?? 0) + (secondMargin ?? 0);
}


  /// Это бывший marginRatio.
  /// Теперь можно использовать как общий account coefficient / risk metric,
  /// если он всё ещё нужен в UI или логике.
double? get accountRiskCoef {
  final mm = maintenanceMargin;
  final eq = equity;

  if (mm == null || eq == null) return null;
  if (eq <= 0) return 100.0;

  return (mm / eq) * 100;
}

double? get marginRatio {
  final mm = maintenanceMargin;
  final eq = equity;

  if (mm == null || eq == null) return null;
  if (eq <= 0) return 100.0;

  return (mm / eq) * 100;
}
  // =========================================================
  // LIQUIDATION
  // =========================================================

 double? get liquidation {
  if (maintenanceMargin == null ||
      firstPositionSize == null ||
      entry == null ||
      totalMargin == null) {
    return null;
  }

  double a = 0;
  double b = 0;

  // ===== FIRST POSITION =====
  final size1 = firstPositionSize!;
  final e1 = entry!;
  final s1 = firstSide;

  if (s1 == 1) {
    a += size1 / e1;
    b -= size1;
  } else {
    a -= size1 / e1;
    b += size1;
  }

  // ===== SECOND POSITION =====
  if (secondEntry != null &&
      secondPositionSize != null &&
      secondSide != null) {
    final size2 = secondPositionSize!;
    final e2 = secondEntry!;
    final s2 = secondSide!;

    if (s2 == 1) {
      a += size2 / e2;
      b -= size2;
    } else {
      a -= size2 / e2;
      b += size2;
    }
  }

  if (a == 0) return null;

  return (maintenanceMargin! - (balance ?? 0) - totalMargin! - b) / a;
}
  // =========================================================
  // REVERSE CALC
  // =========================================================

  double? currentFromFirstPnl(double targetPnl) {
    if (entry == null || firstPositionSize == null || firstPositionSize == 0) {
      return null;
    }

    final size = firstPositionSize!;
    final e = entry!;

    if (firstSide == 1) {
      return e * (1 + targetPnl / size);
    } else {
      return e * (1 - targetPnl / size);
    }
  }

  double? currentFromFirstRoi(double targetRoi) {
    if (margin == null || margin == 0) return null;
    final targetPnl = margin! * (targetRoi / 100);
    return currentFromFirstPnl(targetPnl);
  }

  double? currentFromSecondPnl(double targetPnl) {
    if (secondEntry == null ||
        secondPositionSize == null ||
        secondPositionSize == 0 ||
        secondSide == null) {
      return null;
    }

    final size = secondPositionSize!;
    final e = secondEntry!;

    if (secondSide == 1) {
      return e * (1 + targetPnl / size);
    } else {
      return e * (1 - targetPnl / size);
    }
  }

  double? currentFromSecondRoi(double targetRoi) {
    if (secondMargin == null || secondMargin == 0) return null;
    final targetPnl = secondMargin! * (targetRoi / 100);
    return currentFromSecondPnl(targetPnl);
  }

  /// Общий reverse calc для аккаунта, если нужен.
  double? currentFromTotalPnl(double targetPnl) {
    if (entry == null ||
        firstPositionSize == null ||
        firstPositionSize == 0) {
      return null;
    }

    double a = 0;
    double b = 0;

    // FIRST
    final size1 = firstPositionSize!;
    final e1 = entry!;
    final s1 = firstSide;

    if (s1 == 1) {
      a += size1 / e1;
      b -= size1;
    } else {
      a -= size1 / e1;
      b += size1;
    }

    // SECOND
    if (secondEntry != null &&
        secondPositionSize != null &&
        secondSide != null) {
      final size2 = secondPositionSize!;
      final e2 = secondEntry!;
      final s2 = secondSide!;

      if (s2 == 1) {
        a += size2 / e2;
        b -= size2;
      } else {
        a -= size2 / e2;
        b += size2;
      }
    }

    if (a == 0) return null;

    return (targetPnl - b) / a;
  }

  // =========================================================
  // SETTERS
  // =========================================================

  void setEntry(double v) => entry = v;
  void setMargin(double v) => margin = v;
  void setBalance(double v) => balance = v;
  void setCurrent(double v) => current = v;

  void setSecondPosition({
    required int side,
    required double entry,
    required double margin,
  }) {
    secondSide = side;
    secondEntry = entry;
    secondMargin = margin;
  }

  void clearSecondPosition() {
    secondSide = null;
    secondEntry = null;
    secondMargin = null;
  }
  
}