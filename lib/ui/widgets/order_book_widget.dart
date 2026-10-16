import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/asset.dart';

class OrderBookWidget extends StatelessWidget {
  final Asset asset;
  const OrderBookWidget({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.table_rows_outlined, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Markttiefe nicht verfügbar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Für ${asset.symbol} liefert der Kursanbieter keine '
                  'Orderbuchdaten. Geld-/Briefkurse und Mengen können deshalb '
                  'nicht angezeigt werden.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
