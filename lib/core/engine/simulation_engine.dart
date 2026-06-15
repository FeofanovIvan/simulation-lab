import 'dart:async';

class SimulationEngine {
  final List<double> deltas;
  final double startPrice;

  late double _currentPrice;
  int _index = 0;

  Timer? _timer;

  final StreamController<double> _priceController =
      StreamController.broadcast();

  Stream<double> get priceStream => _priceController.stream;

  // ===== STATE =====
  bool _isRunning = false;
  bool _isPaused = false;

  int _speedMultiplier = 1;
  final Duration _baseTick = const Duration(milliseconds: 50);

  SimulationEngine({
    required this.deltas,
    required this.startPrice,
  }) {
    _currentPrice = startPrice;
  }

  // ===================================================
  // START
  // ===================================================

  void start() {
    if (_isRunning) return;

    _isRunning = true;
    _isPaused = false;

    _startTimer();

    print("🚀 Engine started");
  }

  void _startTimer() {
    _timer?.cancel();

    final tick = Duration(
      milliseconds:
          (_baseTick.inMilliseconds / _speedMultiplier).round(),
    );

    _timer = Timer.periodic(tick, (_) {
      if (_isPaused) return;

      if (_index >= deltas.length) {
        stop();
        return;
      }

      final delta = deltas[_index];

     _currentPrice = _currentPrice * (1 + delta / 100);


      _priceController.add(_currentPrice);

      _index++;
    });
  }

  // ===================================================
  // PAUSE (сохраняет позицию)
  // ===================================================

  void pause() {
    if (!_isRunning) return;

    _isPaused = true;
    print("⏸ Paused at index $_index");
  }

  void resume() {
    if (!_isRunning) return;

    _isPaused = false;
    print("▶️ Resumed");
  }

  // ===================================================
  // STOP (полностью очищает всё)
  // ===================================================

  void stop() {
    _timer?.cancel();

    _isRunning = false;
    _isPaused = false;

    _index = 0;
    _currentPrice = startPrice;

    print("⏹ Fully stopped and cleared");
  }

  // ===================================================
  // SPEED CONTROL
  // ===================================================

  void setSpeed(int multiplier) {
    if (![1, 2, 4, 8].contains(multiplier)) return;

    _speedMultiplier = multiplier;

    print("⚡ Speed set to x$multiplier");

    if (_isRunning) {
      _startTimer(); // перезапуск с новой скоростью
    }
  }

  // ===== GETTERS =====

  int get currentIndex => _index;
  double get currentPrice => _currentPrice;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;

  void dispose() {
    _timer?.cancel();
    _priceController.close();
  }
  void restoreToIndex(int index) {
  if (index <= 0 || index >= deltas.length) return;

  _index = index;

  _currentPrice = startPrice;

  for (int i = 0; i < index; i++) {
    final delta = deltas[i];
    _currentPrice = _currentPrice * (1 + delta / 100);
  }
}
}
