import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/asset.dart';
import '../../data/models/position.dart';

class AllocationSlice {
  final String label;
  final double value;
  final Color color;
  const AllocationSlice(this.label, this.value, this.color);
}

/// Where the money is: cash, one slice per asset class, luxury goods.
/// Empty slices are left out; the list is sorted largest first.
List<AllocationSlice> buildAllocation({
  required double cash,
  required List<Position> positions,
  required double luxuryValue,
}) {
  final byType = <AssetType, double>{};
  for (final p in positions) {
    final v = p.currentValue;
    if (v.isFinite && v > 0) byType[p.type] = (byType[p.type] ?? 0) + v;
  }
  Color colorOf(AssetType t) => switch (t) {
    AssetType.stock => AppColors.stock,
    AssetType.crypto => AppColors.crypto,
    AssetType.etf => AppColors.etf,
    AssetType.cfd => AppColors.cfd,
    AssetType.bond => AppColors.bond,
    AssetType.commodity => AppColors.warning,
  };
  return [
    if (cash > 0) AllocationSlice('Bargeld', cash, AppColors.primary),
    for (final e in byType.entries)
      AllocationSlice(e.key.displayName, e.value, colorOf(e.key)),
    if (luxuryValue > 0)
      AllocationSlice('Luxus', luxuryValue, AppColors.purple),
  ]..sort((a, b) => b.value.compareTo(a.value));
}

/// Donut chart of the portfolio split with a legend that also works without
/// color (label, share as text).
class AllocationChart extends StatelessWidget {
  final List<AllocationSlice> slices;
  const AllocationChart({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portfolio-Aufteilung',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (total <= 0)
            Text(
              'Noch nichts angelegt.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final donut = SizedBox.square(
                  dimension: 140,
                  child: ExcludeSemantics(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        startDegreeOffset: -90,
                        pieTouchData: PieTouchData(enabled: false),
                        sections: [
                          for (final s in slices)
                            PieChartSectionData(
                              value: s.value,
                              color: s.color,
                              radius: 26,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
                final legend = Column(
                  children: [
                    for (final s in slices)
                      _LegendRow(slice: s, share: s.value / total),
                  ],
                );
                return box.maxWidth < 380
                    ? Column(
                        children: [donut, const SizedBox(height: 12), legend],
                      )
                    : Row(
                        children: [
                          donut,
                          const SizedBox(width: 16),
                          Expanded(child: legend),
                        ],
                      );
              },
            ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final AllocationSlice slice;
  final double share;
  const _LegendRow({required this.slice, required this.share});

  @override
  Widget build(BuildContext context) {
    final percent = '${(share * 100).toStringAsFixed(1)} %';
    return Semantics(
      container: true,
      label: '${slice.label}: ${CurrencyFormatter.format(slice.value)}, $percent',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: slice.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                slice.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              percent,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
