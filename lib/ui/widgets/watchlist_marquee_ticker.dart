import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../logic/portfolio_provider.dart';
import '../screens/trade_detail_screen.dart';

class WatchlistMarqueeTicker extends StatefulWidget {
  const WatchlistMarqueeTicker({super.key});

  @override
  State<WatchlistMarqueeTicker> createState() => _WatchlistMarqueeTickerState();
}

class _WatchlistMarqueeTickerState extends State<WatchlistMarqueeTicker> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  bool _isHoveredOrTouching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startContinuousScroll();
    });
  }

  void _startContinuousScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted || MediaQuery.of(context).disableAnimations ||
          !_scrollController.hasClients || _isHoveredOrTouching) {
        return;
      }

      final maxScroll = _scrollController.position.maxScrollExtent;
      final current = _scrollController.offset;
      const step = 1.2;

      if (current >= maxScroll) {
        _scrollController.jumpTo(0.0);
      } else {
        _scrollController.jumpTo(current + step);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final allAssets = provider.assets;

    // Filter auf Favoriten/Watchlist, oder nimm die Top 8 Assets als Fallback
    final watchlisted = allAssets.where((a) => a.isWatchlisted).toList();
    final displayAssets = watchlisted.isNotEmpty
        ? watchlisted
        : allAssets.take(10).toList();

    if (displayAssets.isEmpty) return const SizedBox.shrink();

    // Wir wiederholen die Liste mehrfach, damit das Laufband endlos durchlaufen kann
    final marqueeList = [
      ...displayAssets,
      ...displayAssets,
      ...displayAssets,
    ];

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: AppColors.accentGold.withValues(alpha: 0.4),
            width: 1.0,
          ),
          bottom: const BorderSide(
            color: AppColors.cardBorder,
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Statischer Header links (Bloomberg Ticker Badge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            height: double.infinity,
            color: AppColors.surfaceLight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.profitGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  watchlisted.isNotEmpty ? 'WATCHLIST' : 'KURSE',
                  style: const TextStyle(
                    color: AppColors.accentGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),

          // Scrollendes Laufband
          Expanded(
            child: Listener(
              onPointerDown: (_) => setState(() => _isHoveredOrTouching = true),
              onPointerUp: (_) => setState(() => _isHoveredOrTouching = false),
              onPointerCancel: (_) => setState(() => _isHoveredOrTouching = false),
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: marqueeList.length,
                itemBuilder: (context, index) {
                  final asset = marqueeList[index];
                  final isPositive = asset.change24h >= 0;
                  final sign = isPositive ? '+' : '';
                  final percentStr = '$sign${(asset.change24hPercent * 100).toStringAsFixed(1)}%';

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TradeDetailScreen(asset: asset),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            asset.symbol,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            CurrencyFormatter.formatPrice(asset.currentPrice),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isPositive
                                  ? AppColors.profitGreen.withValues(alpha: 0.15)
                                  : AppColors.lossRed.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${isPositive ? "▲" : "▼"} $percentStr',
                              style: TextStyle(
                                color: isPositive ? AppColors.profitGreen : AppColors.lossRed,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            '•',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
