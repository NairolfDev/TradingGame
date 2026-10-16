import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/asset.dart';
import '../../logic/portfolio_provider.dart';
import '../widgets/asset_card.dart';
import 'trade_detail_screen.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  String _searchQuery = '';
  AssetType? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    final allAssets = provider.assets;

    final filteredAssets = allAssets.where((asset) {
      final matchesSearch = _searchQuery.isEmpty ||
          asset.symbol.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          asset.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          asset.category.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategory == null || asset.type == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Märkte & Kurse'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Aktie, Krypto, ETF, Anleihe suchen...',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),

              const SizedBox(height: 8),

              // Filter Category Chips
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildCategoryChip('Alle', null),
                    _buildCategoryChip('🥇 Rohstoffe & Metalle', AssetType.commodity),
                    _buildCategoryChip('🪙 Krypto 24/7', AssetType.crypto),
                    _buildCategoryChip('📈 Aktien', AssetType.stock),
                    _buildCategoryChip('🌐 ETFs', AssetType.etf),
                    _buildCategoryChip('⚡ CFDs (Hebel)', AssetType.cfd),
                    _buildCategoryChip('🏛️ Anleihen', AssetType.bond),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchLiveMarketQuotes(),
        color: AppColors.primary,
        child: filteredAssets.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        const Text(
                          'Keine Finanzinstrumente gefunden',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        if (_searchQuery.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _selectedCategory = null;
                              });
                            },
                            child: const Text('Filter zurücksetzen'),
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: filteredAssets.length,
                itemBuilder: (context, index) {
                  final asset = filteredAssets[index];
                  return AssetCard(
                    asset: asset,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TradeDetailScreen(asset: asset),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, AssetType? type) {
    final isSelected = _selectedCategory == type;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _selectedCategory = type;
          });
        },
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        checkmarkColor: AppColors.primary,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.cardBorder,
        ),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
