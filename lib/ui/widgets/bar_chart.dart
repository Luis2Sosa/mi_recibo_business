import 'dart:math' as math;
import 'package:flutter/material.dart';

class SimpleBarChart extends StatelessWidget {
  final List<int> values;
  final List<String> labels;
  final String Function(int) yTickFormatter;

  const SimpleBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.yTickFormatter,
  }) : assert(values.length == labels.length, 'values y labels deben tener la misma longitud');

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Text('Sin datos aún', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
      );
    }

    const double chartH = 185;
    const double axisLeftW = 60;
    const double bottomLabelH = 24;
    const double topPad = 8;

    final maxV = values.reduce(math.max).toDouble().clamp(1.0, 999999.0);

    double niceMax;
    if (maxV <= 20000) niceMax = 20000;
    else if (maxV <= 40000) niceMax = 40000;
    else if (maxV <= 60000) niceMax = 60000;
    else if (maxV <= 100000) niceMax = 100000;
    else niceMax = (maxV / 10000.0).ceil() * 10000;

    final ticks = [0.2, 0.4, 0.6, 1.0];
    final tickLabels = ticks.map((t) => yTickFormatter((niceMax * t).round())).toList();

    return SizedBox(
      height: chartH,
      child: Row(
        children: [
          // eje Y
          SizedBox(
            width: axisLeftW,
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(builder: (c, cs) {
                    return Stack(
                      children: List.generate(ticks.length, (i) {
                        final y = (1 - ticks[i]) * (cs.maxHeight - bottomLabelH - topPad) + topPad;
                        return Positioned(
                          left: 0, right: 6, top: y - 8,
                          child: Text(tickLabels[i], textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1)),
                        );
                      }),
                    );
                  }),
                ),
                const SizedBox(height: bottomLabelH),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // área barras
          Expanded(
            child: LayoutBuilder(builder: (c, cs) {
              final barAreaH = cs.maxHeight - bottomLabelH - topPad;
              final barW = math.max(18.0, cs.maxWidth / (values.length * 1.8));

              return Column(
                children: [
                  SizedBox(
                    height: barAreaH,
                    child: Stack(
                      children: [
                        ...List.generate(ticks.length, (i) {
                          final y = (1 - ticks[i]) * barAreaH;
                          return Positioned(left: 0, right: 0, top: y, child: Container(height: 1, color: const Color(0xFFE6ECF5)));
                        }),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: List.generate(values.length, (i) {
                              final h = (values[i] / niceMax) * barAreaH;
                              return Container(
                                height: h.clamp(0, barAreaH),
                                width: barW,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(.18), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: bottomLabelH,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(labels.length, (i) {
                        return SizedBox(
                          width: barW + 8,
                          child: Text(labels[i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        );
                      }),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
