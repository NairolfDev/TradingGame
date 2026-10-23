import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/asset.dart';
import '../../logic/live_market_data_service.dart';

class OrderBookWidget extends StatefulWidget {
  final Asset asset;
  final OrderBookData? initialData;

  const OrderBookWidget({
    super.key,
    required this.asset,
    this.initialData,
  });

  @override
  State<OrderBookWidget> createState() => _OrderBookWidgetState();
}

class _OrderBookWidgetState extends State<OrderBookWidget> {
  OrderBookData? _data;
  bool _isLoading = false;
  String _viewFilter = 'ALL'; // 'ALL', 'BIDS', 'ASKS'

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _data = widget.initialData;
      _isLoading = false;
    } else if (widget.asset.type == AssetType.crypto) {
      _isLoading = true;
      _fetchOrderBook();
    } else {
      _isLoading = false;
      _data = null;
    }
  }

  @override
  void didUpdateWidget(covariant OrderBookWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialData != widget.initialData) {
      setState(() {
        _data = widget.initialData;
      });
    } else if (oldWidget.asset.id != widget.asset.id) {
      if (widget.asset.type == AssetType.crypto) {
        setState(() {
          _data = null;
          _isLoading = true;
        });
        _fetchOrderBook();
      } else {
        setState(() {
          _data = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchOrderBook() async {
    try {
      final res = await LiveMarketDataService().fetchOrderBook(widget.asset);
      if (mounted) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final data = _data;
    if (data == null || (data.bids.isEmpty && data.asks.isEmpty)) {
      return _buildUnavailableView();
    }

    return _buildOrderBookView(data);
  }

  Widget _buildUnavailableView() {
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
          Icon(Icons.table_rows_outlined, color: AppColors.accent),
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
                  'Für ${widget.asset.symbol} liefert der Kursanbieter keine '
                  'Orderbuchdaten. Geld-/Briefkurse und Mengen können deshalb '
                  'nicht angezeigt werden.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderBookView(OrderBookData data) {
    final maxBidAmount = data.bids.isEmpty
        ? 1.0
        : data.bids.map((e) => e.amount).reduce(max);
    final maxAskAmount = data.asks.isEmpty
        ? 1.0
        : data.asks.map((e) => e.amount).reduce(max);
    final maxAmount = max(maxBidAmount, maxAskAmount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.table_rows_outlined, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Orderbuch (Level-2)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.profit,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      data.source,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _filterChip('ALL', 'Beide'),
              const SizedBox(width: 8),
              _filterChip('BIDS', 'Kauf (Bids)'),
              const SizedBox(width: 8),
              _filterChip('ASKS', 'Verkauf (Asks)'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cardBorder.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spread',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${CurrencyFormatter.format(data.spread)} (${data.spreadPercent.toStringAsFixed(3)}%)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_viewFilter == 'ALL')
            _buildSideBySideView(data, maxAmount)
          else if (_viewFilter == 'BIDS')
            _buildListView(data.bids, maxAmount, isBid: true)
          else
            _buildListView(data.asks, maxAmount, isBid: false),
        ],
      ),
    );
  }

  Widget _filterChip(String filter, String label) {
    final selected = _viewFilter == filter;
    return InkWell(
      onTap: () => setState(() => _viewFilter = filter),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSideBySideView(OrderBookData data, double maxAmount) {
    final maxLen = max(data.bids.length, data.asks.length);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Menge', style: _headerStyle),
                    Text('Bid (€)', style: _headerStyle),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ask (€)', style: _headerStyle),
                    Text('Menge', style: _headerStyle),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (int i = 0; i < maxLen; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              children: [
                Expanded(
                  child: i < data.bids.length
                      ? _buildBidRow(data.bids[i], maxAmount)
                      : const SizedBox(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: i < data.asks.length
                      ? _buildAskRow(data.asks[i], maxAmount)
                      : const SizedBox(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildListView(
    List<OrderBookEntry> entries,
    double maxAmount, {
    required bool isBid,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isBid ? 'Bid Preis (€)' : 'Ask Preis (€)',
                style: _headerStyle,
              ),
              Text('Menge', style: _headerStyle),
              Text('Gesamt (€)', style: _headerStyle),
            ],
          ),
        ),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Stack(
              children: [
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment:
                        isBid ? Alignment.centerLeft : Alignment.centerRight,
                    widthFactor: (entry.amount / maxAmount).clamp(0.04, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: (isBid ? AppColors.profit : AppColors.loss)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        CurrencyFormatter.format(entry.price),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isBid ? AppColors.profit : AppColors.loss,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        _formatAmount(entry.amount),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(entry.price * entry.amount),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBidRow(OrderBookEntry entry, double maxAmount) {
    return Stack(
      children: [
        Positioned.fill(
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (entry.amount / maxAmount).clamp(0.04, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.profit.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatAmount(entry.amount),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _formatPrice(entry.price),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.profit,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAskRow(OrderBookEntry entry, double maxAmount) {
    return Stack(
      children: [
        Positioned.fill(
          child: FractionallySizedBox(
            alignment: Alignment.centerRight,
            widthFactor: (entry.amount / maxAmount).clamp(0.04, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.loss.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatPrice(entry.price),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.loss,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _formatAmount(entry.amount),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatPrice(double p) => CurrencyFormatter.format(p);

  String _formatAmount(double a) {
    if (a >= 100) return a.toStringAsFixed(1);
    if (a >= 1) return a.toStringAsFixed(3);
    return a.toStringAsFixed(4);
  }

  TextStyle get _headerStyle => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      );
}
