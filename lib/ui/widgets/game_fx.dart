import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

/// Card surface: gradient + glow in the Gamer style, flat card otherwise.
BoxDecoration heroDecoration({Color? glow}) {
  final p = AppColors.palette;
  if (!AppColors.isGamer) {
    return BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: p.cardBorder),
    );
  }
  return BoxDecoration(
    borderRadius: BorderRadius.circular(20),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(p.heroGradient[0].withValues(alpha: 0.55), p.surface),
        Color.alphaBlend(p.heroGradient[1].withValues(alpha: 0.35), p.surface),
      ],
    ),
    border: Border.all(color: (glow ?? p.primary).withValues(alpha: 0.35)),
    boxShadow: [
      BoxShadow(
        color: (glow ?? p.primary).withValues(alpha: 0.18),
        blurRadius: 28,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

/// Money value that counts up/down to its new value in the Gamer style.
class AnimatedMoney extends StatelessWidget {
  final double value;
  final TextStyle style;
  const AnimatedMoney(this.value, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    final style = this.style.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    if (!AppColors.isGamer || MediaQuery.of(context).disableAnimations) {
      return Text(CurrencyFormatter.format(value), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(
        CurrencyFormatter.format(v),
        style: style,
        semanticsLabel: CurrencyFormatter.format(value),
      ),
    );
  }
}

/// Progress bar; animated gradient with glow in the Gamer style.
class GameProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const GameProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    if (!AppColors.isGamer) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: AppColors.surfaceElevated,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );
    }
    return Semantics(
      value: '${(v * 100).round()} %',
      child: Container(
        height: height + 4,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(height),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: v),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (_, t, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: t,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                gradient: LinearGradient(
                  colors: [color, Color.lerp(color, AppColors.gold, 0.6)!],
                ),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
