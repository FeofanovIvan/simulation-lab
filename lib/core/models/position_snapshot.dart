class PositionSnapshot {
  final bool isLong;
  final double entry;
  final double margin;
  final double leverage;
  final double? roi;
  final double? pnl;

  PositionSnapshot({
    required this.isLong,
    required this.entry,
    required this.margin,
    required this.leverage,
    this.roi,
    this.pnl,
  });
}
