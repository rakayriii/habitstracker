import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../constants/design_tokens.dart';

/// 30 day net-worth trace. A 1.5px line and an end marker: it answers "which
/// way did it move", so nothing else is drawn. No fill, no gradient, no axis.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.points,
    this.color = MyOSColors.accent,
    this.height = 34,
  });

  final List<double> points;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparklinePainter(points, color)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.points, this.color);

  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.width <= 0) return;

    final minValue = points.reduce(math.min);
    final maxValue = points.reduce(math.max);
    final span = (maxValue - minValue).abs() < 1e-9 ? 1.0 : maxValue - minValue;
    final step = size.width / (points.length - 1);

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = step * i;
      final y = size.height - ((points[i] - minValue) / span * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    canvas.drawPath(path, paint);

    final lastX = step * (points.length - 1);
    final lastY = size.height - ((points.last - minValue) / span * size.height);
    canvas.drawCircle(Offset(lastX, lastY), 2.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

/// Stacked allocation rail. One hue in four values, separated by a 2px gap so
/// neighbouring segments never blur into each other. The numeric breakdown
/// lives in the ledger below it, not in the bar.
class AllocationBar extends StatelessWidget {
  const AllocationBar({
    super.key,
    required this.segments,
    this.height = 8,
  });

  /// Already-normalised weights in display order.
  final List<double> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(
          // Stretch, or the segments collapse to zero height under the loose
          // constraints a Column hands down.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                flex: math.max(1, (segments[i] * 1000).round()),
                child: ColoredBox(
                  color: MyOSColors.allocationRamp[
                      i % MyOSColors.allocationRamp.length],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CashflowBar {
  const CashflowBar({
    required this.label,
    required this.income,
    required this.expenses,
  });

  final String label;
  final int income;
  final int expenses;
}

/// Six month income versus expenses. The question is "am I retaining capital",
/// so the bars are paired, unscaled by any third axis, and the net is written
/// as text in the card header instead of being encoded in a trend line.
class CashflowBars extends StatelessWidget {
  const CashflowBars({super.key, required this.months, this.height = 72});

  final List<CashflowBar> months;
  final double height;

  static const _income = Color(0xFF9CC9F5);
  static const _expenses = Color(0xFF2E5FA5);

  static const _legend = <(String, Color)>[
    ('Masuk', _income),
    ('Keluar', _expenses),
  ];

  @override
  Widget build(BuildContext context) {
    final peak = months.fold<int>(
      1,
      (max, month) => math.max(max, math.max(month.income, month.expenses)),
    );

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final month in months)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _Bar(
                            value: month.income / peak,
                            color: _income,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: _Bar(
                            value: month.expenses / peak,
                            color: _expenses,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    month.label,
                    style: MyOSText.dataSm.copyWith(
                      fontSize: 10,
                      color: MyOSColors.textMuted,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Row legend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, entry) in _legend.indexed) ...[
          if (index > 0) const SizedBox(width: MyOSSpace.sm),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: entry.$2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              entry.$1,
              style: MyOSText.dataSm.copyWith(
                color: MyOSColors.textSecondary,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// Legend for [CashflowBars], exposed so the card can lay it out next to its
/// own readout without reaching into the chart.
class CashflowBarsLegend extends StatelessWidget {
  const CashflowBarsLegend({super.key});

  @override
  Widget build(BuildContext context) => CashflowBars.legend();
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: value.clamp(0.04, 1.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
      ),
    );
  }
}
