import 'dart:async';
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
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  String _query = '';
  AssetType? _type;
  final Set<String> _groups = {};
  String? _sector;
  String _sort = 'name';
  bool _watchlist = false;
  bool _open = false;
  bool _more = false;
  int _page = 0;
  static const _pageSize = 30;
  PortfolioProvider? _provider;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    // Remove this screen's quote subscription after it leaves the tree.
    final provider = _provider;
    if (provider != null) {
      Future.microtask(() => provider.setVisibleMarketAssets(const []));
    }
    super.dispose();
  }

  void _change(VoidCallback update) {
    setState(() {
      update();
      _page = 0;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _reset() {
    _debounce?.cancel();
    _search.clear();
    _change(() {
      _query = '';
      _type = null;
      _groups.clear();
      _sector = null;
      _watchlist = false;
      _open = false;
      _sort = 'name';
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PortfolioProvider>();
    _provider = provider;
    final sectors =
        provider.assets
            .where((a) => a.type == AssetType.stock)
            .map((a) => a.sector)
            .toSet()
            .toList()
          ..sort();
    final query = _query.toLowerCase().trim();
    final filtered = provider.assets.where((asset) {
      return (query.isEmpty ||
              '${asset.symbol} ${asset.name} ${asset.industry}'
                  .toLowerCase()
                  .contains(query)) &&
          (_type == null || asset.type == _type) &&
          (_groups.isEmpty || asset.marketGroups.any(_groups.contains)) &&
          (_sector == null || asset.sector == _sector) &&
          (!_watchlist || asset.isWatchlisted) &&
          (!_open || provider.isAssetMarketOpen(asset));
    }).toList();
    filtered.sort((a, b) {
      if (_sort != 'name' && _sort != 'nameDesc') {
        final aHasQuote = provider.quoteUpdatedAt(a) != null;
        final bHasQuote = provider.quoteUpdatedAt(b) != null;
        if (aHasQuote != bHasQuote) return aHasQuote ? -1 : 1;
        if (aHasQuote) {
          final result = switch (_sort) {
            'priceAsc' => a.currentPrice.compareTo(b.currentPrice),
            'priceDesc' => b.currentPrice.compareTo(a.currentPrice),
            'gain' => b.change24hPercent.compareTo(a.change24hPercent),
            'loss' => a.change24hPercent.compareTo(b.change24hPercent),
            _ => 0,
          };
          if (result != 0) return result;
        }
      }
      return _sort == 'nameDesc'
          ? b.name.compareTo(a.name)
          : a.name.compareTo(b.name);
    });
    final pages = (filtered.length / _pageSize).ceil();
    final currentPage = pages == 0 ? 0 : _page.clamp(0, pages - 1);
    final pageAssets = filtered
        .skip(currentPage * _pageSize)
        .take(_pageSize)
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) provider.setVisibleMarketAssets(pageAssets);
    });
    final active =
        _query.isNotEmpty ||
        _type != null ||
        _groups.isNotEmpty ||
        _sector != null ||
        _watchlist ||
        _open ||
        _sort != 'name';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Märkte & Kurse'),
        actions: [
          IconButton(
            tooltip: 'Datenquellen und Katalogstand',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Katalog und Kurse'),
                content: const SingleChildScrollView(
                  child: Text(
                    'Nasdaq: alle gelisteten Aktien, ohne ETFs, Warrants, Units, Rights und Anleihen. Quelle: Nasdaq Trader 16.10.2026; Branchen: Nasdaq Screener.\n\n'
                    'DAX: 40 Mitglieder, STOXX 05.10.2026. ATX: 20 Mitglieder, Wiener Börse 16.10.2026. Nikkei 225: 225 Mitglieder, Nikkei 30.09.2026.\n\n'
                    'Nicht gelieferte Branchen bleiben „Unbekannt“. Katalogangaben sind keine Kursdaten. Kurse: Yahoo Finance, Binance oder CoinGecko, möglicherweise verzögert. Der Anbieterzeitpunkt steht am Wert.\n\n'
                    'USD und JPY werden mit dem zuletzt verfügbaren EUR-Wechselkurs umgerechnet. Tagesvergleich: beide Kurse zum aktuellen FX-Kurs; keine historische EUR-Rendite. Fremdwährungscharts bleiben ohne zeitlich passende FX-Historie unverfügbar.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Schließen'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.48,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: 'Name, Symbol oder Industrie suchen',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _search.clear();
                                  _change(() => _query = '');
                                },
                              ),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 250),
                          () {
                            if (mounted) _change(() => _query = value);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          for (final group in [
                            'Nasdaq',
                            'DAX',
                            'ATX',
                            'Nikkei 225',
                          ])
                            FilterChip(
                              label: Text(group),
                              selected: _groups.contains(group),
                              onSelected: (selected) => _change(() {
                                if (selected) {
                                  _groups.add(group);
                                } else {
                                  _groups.remove(group);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() => _more = !_more),
                          icon: Icon(_more ? Icons.expand_less : Icons.tune),
                          label: const Text('Weitere Filter'),
                        ),
                        if (active)
                          TextButton(
                            onPressed: _reset,
                            child: const Text('Zurücksetzen'),
                          ),
                      ],
                    ),
                    if (_more)
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<AssetType>(
                              isExpanded: true,
                              initialValue: _type,
                              key: ValueKey('type-$_type'),
                              decoration: const InputDecoration(
                                labelText: 'Assetklasse',
                              ),
                              items: [
                                const DropdownMenuItem<AssetType>(
                                  value: null,
                                  child: Text('Alle Assetklassen'),
                                ),
                                ...AssetType.values.map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type.displayName),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  _change(() => _type = value),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              initialValue: _sector,
                              key: ValueKey('sector-$_sector'),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Branche',
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('Alle Branchen'),
                                ),
                                ...sectors.map(
                                  (sector) => DropdownMenuItem(
                                    value: sector,
                                    child: Text(
                                      sector,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  _change(() => _sector = value),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _sort,
                              key: ValueKey('sort-$_sort'),
                              decoration: const InputDecoration(
                                labelText: 'Sortieren',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'name',
                                  child: Text('Name A–Z'),
                                ),
                                DropdownMenuItem(
                                  value: 'nameDesc',
                                  child: Text('Name Z–A'),
                                ),
                                DropdownMenuItem(
                                  value: 'priceAsc',
                                  child: Text('Preis aufsteigend'),
                                ),
                                DropdownMenuItem(
                                  value: 'priceDesc',
                                  child: Text('Preis absteigend'),
                                ),
                                DropdownMenuItem(
                                  value: 'gain',
                                  child: Text(
                                    'Gewinner',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'loss',
                                  child: Text(
                                    'Verlierer',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  _change(() => _sort = value ?? 'name'),
                            ),
                          ),
                          FilterChip(
                            label: const Text('Nur Watchlist'),
                            selected: _watchlist,
                            onSelected: (v) => _change(() => _watchlist = v),
                          ),
                          FilterChip(
                            label: const Text('Börse offen'),
                            selected: _open,
                            onSelected: (v) => _change(() => _open = v),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${filtered.length} Treffer · ${provider.assets.length} Instrumente',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                if (pages > 1) ...[
                  IconButton(
                    tooltip: 'Vorherige Seite',
                    onPressed: currentPage > 0
                        ? () => setState(() => _page = currentPage - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${currentPage + 1}/$pages'),
                  IconButton(
                    tooltip: 'Nächste Seite',
                    onPressed: currentPage < pages - 1
                        ? () => setState(() => _page = currentPage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.fetchLiveMarketQuotes(),
              child: pageAssets.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(
                          child: Text('Keine Instrumente für diese Filter.'),
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      itemCount: pageAssets.length,
                      itemBuilder: (context, index) {
                        final asset = pageAssets[index];
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
          ),
        ],
      ),
    );
  }
}
