import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/news_event.dart';

class BreakingNewsTicker extends StatelessWidget {
  final NewsEvent? news;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  const BreakingNewsTicker({
    super.key,
    required this.news,
    this.onTap,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    if (news == null) return const SizedBox.shrink();

    final isBullish = news!.isBullish;
    final impactText = isBullish
        ? '+${(news!.priceImpact * 100).toStringAsFixed(1)}%'
        : '${(news!.priceImpact * 100).toStringAsFixed(1)}%';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: margin ?? const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isBullish
                ? AppColors.bullish.withAlpha(120)
                : AppColors.bearish.withAlpha(120),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isBullish ? AppColors.bullish : AppColors.bearish)
                  .withAlpha(30),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isBullish ? AppColors.bullish : AppColors.bearish,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt, size: 12, color: AppColors.onPrimary),
                  SizedBox(width: 2),
                  Text(
                    'NEWS',
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                news!.headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isBullish ? AppColors.bullish : AppColors.bearish)
                    .withAlpha(40),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                impactText,
                style: TextStyle(
                  color: isBullish ? AppColors.bullish : AppColors.bearish,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
