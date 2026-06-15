import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/painting.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:path_provider/path_provider.dart';


import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class ChartEvent {
  final int minute;
  final double price;
  final int index;
  final String description;

  ChartEvent({
    required this.minute,
    required this.price,
    required this.index,
    required this.description,
  });
}

class SimulationReportService {
  static Future<File> generateReport({
    required File journalFile,
    required List<double> deltas,
    required double startPrice,
    required int ticks,
  }) async {
    final lines = await journalFile.readAsLines();

    final events = _parseEvents(lines);
    final invested = _calculateInvested(lines);
    final pnl = _calculatePnl(lines);
    final duration = _simulationDuration(ticks);
    final prices = _buildPricesFromJournal(lines, ticks);

    // 🔥 генерируем картинку графика
    final chartBytes = await _generateChartImage(
      prices,
      events,
      ticks,
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Simulation Trading Report',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 30),

              // ✅ ВСТАВКА ГРАФИКА
              pw.Image(
                pw.MemoryImage(chartBytes),
                width: 520,
                height: 240,
              ),

              pw.SizedBox(height: 20),

              pw.Text(
                'Events',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              ...events.map(
                (e) => pw.Text(
                  '${e.index}. ${e.description}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Text(
                'Simulation Summary',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Text('Duration: $duration'),
              pw.Text('Total invested: ${invested.toStringAsFixed(2)}'),
              pw.Text('Final Balance: ${pnl.toStringAsFixed(2)}'),
            ],
          );
        },
      ),
    );

final fileName = 'simulation_${DateTime.now().millisecondsSinceEpoch}.pdf';

if (Platform.isAndroid) {
  final dir = Directory('/storage/emulated/0/Download');
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(await pdf.save());
  return file;
}

final dir = await getTemporaryDirectory();
final file = File('${dir.path}/$fileName');
await file.writeAsBytes(await pdf.save());
return file;
  }

  // =========================================================
  // 🔥 ГЕНЕРАЦИЯ ГРАФИКА В КАРТИНКУ
  // =========================================================

  static Future<Uint8List> _generateChartImage(
  List<double> prices,
  List<ChartEvent> events,
  int ticks,
) async {
  const width = 800.0;
  const height = 400.0;

  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
  canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

  final gridPaint = Paint()
    ..color = const Color(0xFFE0E0E0)
    ..strokeWidth = 1;

  // GRID
  for (int i = 0; i <= 5; i++) {
    final y = height * i / 5;
    canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
  }

  for (int i = 0; i <= 10; i++) {
    final x = width * i / 10;
    canvas.drawLine(Offset(x, 0), Offset(x, height), gridPaint);
  }

  if (prices.isEmpty) {
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  final minPrice = prices.reduce((a, b) => a < b ? a : b);
  final maxPrice = prices.reduce((a, b) => a > b ? a : b);

  double priceToY(double price) {
    if (maxPrice == minPrice) return height / 2;
    final norm = (price - minPrice) / (maxPrice - minPrice);
    return height - norm * height;
  }

  // =========================================================
  // 🔵 PRICE LINE
  // =========================================================

  final linePaint = Paint()
    ..color = const Color(0xFF2196F3)
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke;

  final path = Path();

  for (int i = 0; i < prices.length; i++) {
    final x = width * i / (prices.length - 1);
    final y = priceToY(prices[i]);

    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }

  canvas.drawPath(path, linePaint);

  // =========================================================
  // 🔴 FINAL DASH LINE
  // =========================================================

  final finalY = priceToY(prices.last);

  final dashPaint = Paint()
    ..color = const Color(0xFFF44336)
    ..strokeWidth = 2;

  const dashWidth = 8;
  const gap = 5;

  double dx = 0;
  while (dx < width) {
    canvas.drawLine(
      Offset(dx, finalY),
      Offset(dx + dashWidth, finalY),
      dashPaint,
    );
    dx += dashWidth + gap;
  }

  // =========================================================
  // 🟢 START / 🔴 FINAL POINTS
  // =========================================================

  final startY = priceToY(prices.first);

  canvas.drawCircle(
    Offset(0, startY),
    6,
    Paint()..color = const Color(0xFF4CAF50),
  );

  canvas.drawCircle(
    Offset(width, finalY),
    6,
    Paint()..color = const Color(0xFFF44336),
  );

  // =========================================================
  // 🔴 EVENTS
  // =========================================================

  for (final e in events) {
    final x = width * (e.minute / ticks).clamp(0.0, 1.0);
    final y = priceToY(e.price);

    canvas.drawCircle(
      Offset(x, y),
      5,
      Paint()..color = const Color(0xFFFF5722),
    );
  }

  // =========================================================
  // 🏷 TEXT HELPER
  // =========================================================

  void drawText(
    String text,
    double x,
    double y, {
    Color color = const Color(0xFF000000),
    double size = 14,
    bool alignRight = false,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
        ),
      ),
      textDirection: painting.TextDirection.ltr,
    );

    textPainter.layout();

    final dx = alignRight ? x - textPainter.width : x;

    textPainter.paint(canvas, Offset(dx, y));
  }

  // =========================================================
  // 🟢 START LABEL
  // =========================================================

  drawText(
    'Start ${prices.first.toStringAsFixed(2)}',
    10,
    (startY - 20).clamp(0, height - 20),
    color: const Color(0xFF2E7D32),
  );

  // =========================================================
  // 🔴 FINAL LABEL
  // =========================================================

  drawText(
    'Final ${prices.last.toStringAsFixed(2)}',
    width - 10,
    (finalY - 20).clamp(0, height - 20),
    color: const Color(0xFFC62828),
    alignRight: true,
  );

  // =========================================================
  // 📊 Y AXIS LABELS
  // =========================================================

  drawText(maxPrice.toStringAsFixed(2), width - 5, 5,
      alignRight: true);

  drawText(
    ((maxPrice + minPrice) / 2).toStringAsFixed(2),
    width - 5,
    height / 2 - 8,
    alignRight: true,
  );

  drawText(
    minPrice.toStringAsFixed(2),
    width - 5,
    height - 18,
    alignRight: true,
  );

  // =========================================================
  // ⏱ X AXIS LABELS
  // =========================================================

  int step;

if (ticks <= 120) {
  step = 15; // до 2 часов
} else if (ticks <= 720) {
  step = 60; // до 12 часов
} else if (ticks <= 4320) {
  step = 360; // до 3 дней
} else if (ticks <= 14400) {
  step = 720; // до 10 дней
} else {
  step = 1440; // дни
}

  for (int t = 0; t <= ticks; t += step) {
    final x = width * (t / ticks);
   drawText(_formatTime(t), x - 15, height - 15);
  }

  // =========================================================
  // END
  // =========================================================

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), height.toInt());
  final bytes = await image.toByteData(format: ImageByteFormat.png);

  return bytes!.buffer.asUint8List();
}

  // =========================================================
  // DATA
  // =========================================================

  static List<double> _buildPricesFromJournal(List<String> lines, int ticks) {
    final prices = List<double>.filled(ticks, 0);

    double currentPrice = 0;

    for (final line in lines) {
      final json = jsonDecode(line);

      if (json["type"] == "start_price_set") {
        final minute = json["minute"] ?? 0;
        currentPrice = (json["data"]["to"]).toDouble();

        if (minute >= 0 && minute < ticks) {
          prices[minute] = currentPrice;
        }
      }
    }

    for (int i = 1; i < prices.length; i++) {
      if (prices[i] == 0) {
        prices[i] = prices[i - 1];
      }
    }

    return prices;
  }

  static List<ChartEvent> _parseEvents(List<String> lines) {
    final events = <ChartEvent>[];
    int counter = 1;

    for (final line in lines) {
      final json = jsonDecode(line);
      final type = json['type'];

      if (type == 'isolated_calculated') {
        events.add(
          ChartEvent(
            minute: json['minute'] ?? 0,
            price: (json['data']['entry'] as num).toDouble(),
            index: counter++,
            description: 'Long entry',
          ),
        );
      }

      if (type == 'position_averaged_market') {
        events.add(
          ChartEvent(
            minute: json['minute'] ?? 0,
            price: (json['data']['price'] as num).toDouble(),
            index: counter++,
            description: 'Position averaged',
          ),
        );
      }

      if (type == 'limit_order_triggered') {
        if (json['data']['side'] == 'sell') {
          events.add(
            ChartEvent(
              minute: json['minute'] ?? 0,
              price: (json['data']['price'] as num).toDouble(),
              index: counter++,
              description: 'Position closed',
            ),
          );
        }
      }
    }

    return events;
  }

  static double _calculateInvested(List<String> lines) {
    double total = 0;

    for (final line in lines) {
      final json = jsonDecode(line);

      if (json['type'] == 'margin_added') {
        total += ((json['data']['added'] ?? 0) as num).toDouble();
      }

      if (json['type'] == 'position_averaged_market') {
        total += ((json['data']['marginAdded'] ?? 0) as num).toDouble();
      }
    }

    return total;
  }

  static double _calculatePnl(List<String> lines) {
    for (final line in lines.reversed) {
      final json = jsonDecode(line);

      if (json['type'] == 'session_end') {
        return ((json['finalState']['balance'] ?? 0) as num).toDouble();
      }
    }

    return 0;
  }

  static String _simulationDuration(int ticks) {
    final days = ticks ~/ 1440;
    final hours = (ticks % 1440) ~/ 60;
    final minutes = ticks % 60;

    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
  static String _formatTime(int minutes) {
  if (minutes < 60) {
    return '${minutes}m';
  }

  if (minutes < 1440) {
    final h = minutes ~/ 60;
    final m = minutes % 60;

    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  final d = minutes ~/ 1440;
  final h = (minutes % 1440) ~/ 60;

  if (h == 0) return '${d}d';
  return '${d}d ${h}h';
}
}