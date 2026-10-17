import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/reward_event.dart';
import '../../logic/portfolio_provider.dart';
import '../../logic/theme_controller.dart';

/// Shows trade results, quest rewards and achievements on top of every screen.
/// Gamer style: animated celebration card with confetti burst.
/// Schlicht style (or reduced motion): a short, quiet confirmation.
class RewardOverlay extends StatefulWidget {
  final Widget child;
  const RewardOverlay({super.key, required this.child});

  @override
  State<RewardOverlay> createState() => _RewardOverlayState();
}

class _RewardOverlayState extends State<RewardOverlay>
    with TickerProviderStateMixin {
  StreamSubscription<RewardEvent>? _sub;
  PortfolioProvider? _provider;
  final _queue = <RewardEvent>[];
  RewardEvent? _current;
  Timer? _hideTimer;
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<PortfolioProvider>();
    if (!identical(provider, _provider)) {
      _sub?.cancel();
      _provider = provider;
      _sub = provider.rewards.listen(_enqueue);
    }
  }

  void _enqueue(RewardEvent e) {
    _queue.add(e);
    if (_current == null) _next();
  }

  void _next() {
    if (!mounted) return;
    if (_queue.isEmpty) {
      setState(() => _current = null);
      return;
    }
    final e = _queue.removeAt(0);
    final celebrate = e.kind != RewardKind.loss && e.kind != RewardKind.buy;
    if (celebrate) HapticFeedback.mediumImpact();
    setState(() => _current = e);
    _anim.forward(from: 0);
    _hideTimer?.cancel();
    _hideTimer = Timer(
      Duration(milliseconds: celebrate ? 3200 : 2400),
      _dismiss,
    );
  }

  void _dismiss() {
    _hideTimer?.cancel();
    _next();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hideTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = _current;
    final gamer =
        context.watch<ThemeController>().isGamer &&
        !MediaQuery.of(context).disableAnimations;
    return Stack(
      children: [
        widget.child,
        if (e != null)
          Positioned(
            left: 16,
            right: 16,
            top: MediaQuery.of(context).padding.top + 12,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: gamer
                    ? _GamerCard(event: e, anim: _anim, onTap: _dismiss)
                    : _QuietCard(event: e, onTap: _dismiss),
              ),
            ),
          ),
      ],
    );
  }
}

({Color color, IconData icon}) _look(RewardKind kind) => switch (kind) {
  RewardKind.buy => (
    color: AppColors.accent,
    icon: Icons.shopping_bag_outlined,
  ),
  RewardKind.profit => (color: AppColors.profit, icon: Icons.trending_up),
  RewardKind.loss => (color: AppColors.loss, icon: Icons.trending_down),
  RewardKind.quest => (color: AppColors.gold, icon: Icons.card_giftcard),
  RewardKind.achievement => (color: AppColors.gold, icon: Icons.emoji_events),
  RewardKind.purchase => (
    color: AppColors.purple,
    icon: Icons.diamond_outlined,
  ),
};

String? _amountText(RewardEvent e) {
  final parts = <String>[
    if (e.cash != null && e.cash != 0)
      '${e.cash! > 0 ? '+' : '−'}${CurrencyFormatter.format(e.cash!.abs())}',
    if (e.prestige > 0) '+${e.prestige} Prestige',
  ];
  return parts.isEmpty ? null : parts.join('  ·  ');
}

class _QuietCard extends StatelessWidget {
  final RewardEvent event;
  final VoidCallback onTap;
  const _QuietCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final look = _look(event.kind);
    final amount = _amountText(event);
    return Semantics(
      liveRegion: true,
      child: Material(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        elevation: 6,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(look.icon, color: look.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${event.title} · ${event.detail}',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                if (amount != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    amount,
                    style: TextStyle(
                      color: look.color,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GamerCard extends StatelessWidget {
  final RewardEvent event;
  final Animation<double> anim;
  final VoidCallback onTap;
  const _GamerCard({
    required this.event,
    required this.anim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final look = _look(event.kind);
    final amount = _amountText(event);
    final celebrate =
        event.kind != RewardKind.loss && event.kind != RewardKind.buy;
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        final t = anim.value;
        // Pop in with a little overshoot during the first ~30%.
        final enter = Curves.elasticOut.transform((t / 0.45).clamp(0.0, 1.0));
        return Opacity(
          opacity: (t / 0.12).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.7 + 0.3 * enter,
            child: CustomPaint(
              foregroundPainter: celebrate
                  ? _ConfettiPainter(progress: t, seed: event.hashCode)
                  : null,
              child: child,
            ),
          ),
        );
      },
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 20, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Color.alphaBlend(
                      look.color.withValues(alpha: 0.28),
                      AppColors.surface,
                    ),
                    AppColors.surfaceElevated,
                  ],
                ),
                border: Border.all(
                  color: look.color.withValues(alpha: 0.7),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: look.color.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: look.color.withValues(alpha: 0.2),
                    ),
                    child: Icon(look.icon, color: look.color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          event.title,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.detail,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        if (amount != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            amount,
                            style: TextStyle(
                              color: look.color,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final int seed;
  _ConfettiPainter({required this.progress, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final rnd = Random(seed);
    final colors = [
      AppColors.primary,
      AppColors.gold,
      AppColors.accent,
      AppColors.purple,
      AppColors.loss,
    ];
    final origin = Offset(size.width / 2, size.height / 2);
    final paint = Paint();
    for (var i = 0; i < 36; i++) {
      final angle = rnd.nextDouble() * 2 * pi;
      final speed = 90 + rnd.nextDouble() * 160;
      final d = speed * Curves.easeOut.transform(progress);
      final pos =
          origin +
          Offset(cos(angle) * d * 1.6, sin(angle) * d * 0.8) +
          Offset(0, 120 * progress * progress); // gravity
      paint.color = colors[i % colors.length].withValues(
        alpha: (1 - progress).clamp(0.0, 1.0),
      );
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle + progress * 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-4, -2, 8, 4),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
