import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../logic/market_filter_views.dart';
import '../../data/models/asset.dart';
import '../../logic/portfolio_provider.dart';
import '../widgets/asset_card.dart';
import '../widgets/empty_state.dart';
import 'trade_detail_screen.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});
  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _filtersKey = GlobalKey();
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

  final _viewStore = MarketFilterViews();
  Map<String, Map<String, dynamic>> _views = {};
  bool _savingView = false;

  @override
  void initState() {
    super.initState();
    _viewStore
        .load()
        .then((views) {
          if (mounted) setState(() => _views = views);
        })
        .catchError((Object _) {
          if (mounted) _viewError();
        });
  }

  void _viewError() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Filteransichten konnten nicht gespeichert oder geladen werden.',
      ),
    ),
  );

  Map<String, dynamic> get _snapshot => {
    'query': _query,
    'type': _type?.name,
    'groups': _groups.toList(),
    'sector': _sector,
    'sort': _sort,
    'watchlist': _watchlist,
    'open': _open,
  };

  void _applyView(Map<String, dynamic> view) {
    _debounce?.cancel();
    _change(() {
      _query = view['query'] is String ? view['query'] as String : '';
      _search.text = _query;
      _type = AssetType.values
          .where((type) => type.name == view['type'])
          .firstOrNull;
      _groups
        ..clear()
        ..addAll(
          (view['groups'] is List ? view['groups'] as List : [])
              .whereType<String>(),
        );
      _sector = view['sector'] is String ? view['sector'] as String : null;
      _sort = view['sort'] is String ? view['sort'] as String : 'name';
      _watchlist = view['watchlist'] == true;
      _open = view['open'] == true;
    });
  }

  Future<void> _saveView() async {
    var enteredName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filteransicht speichern'),
        content: TextField(
          onChanged: (value) => enteredName = value,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Name der Ansicht'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              if (enteredName.trim().isNotEmpty) {
                Navigator.pop(context, enteredName.trim());
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    await _persistViews({..._views, name: _snapshot});
  }

  Future<void> _persistViews(Map<String, Map<String, dynamic>> views) async {
    setState(() => _savingView = true);
    try {
      await _viewStore.save(views);
      if (mounted) setState(() => _views = views);
    } catch (_) {
      if (mounted) _viewError();
    } finally {
      if (mounted) setState(() => _savingView = false);
    }
  }

  void _openAsset(Asset asset) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => TradeDetailScreen(asset: asset)),
  );

  Widget _desktopTable(List<Asset> assets, PortfolioProvider provider) {
    const columns = [
      'Name / Symbol',
      'Index',
      'Branche',
      'EUR-Kurs',
      'Tagesänderung',
      'Kurszeit',
      'Watchlist',
    ];
    const sorts = [
      'name',
      'index',
      'sector',
      'priceAsc',
      'loss',
      'time',
      'watchlist',
    ];
    final index = sorts.indexOf(
      _sort.endsWith('Desc') ? _sort.substring(0, _sort.length - 4) : _sort,
    );
    return SingleChildScrollView(
      controller: _scroll,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.sizeOf(context).width - 32,
          ),
          child: DataTable(
            columnSpacing: 20,
            horizontalMargin: 16,
            dataRowMinHeight: 64,
            dataRowMaxHeight: 110 * MediaQuery.textScalerOf(context).scale(1),
            headingRowHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
            sortColumnIndex: index < 0 ? null : index,
            sortAscending: !_sort.endsWith('Desc'),
            columns: [
              for (var i = 0; i < columns.length; i++)
                DataColumn(
                  label: Text(columns[i]),
                  onSort: (_, ascending) => _change(
                    () => _sort = ascending ? sorts[i] : '${sorts[i]}Desc',
                  ),
                ),
            ],
            rows: [
              for (final asset in assets)
                DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 210,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asset.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              asset.symbol,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      onTap: () => _openAsset(asset),
                    ),
                    DataCell(
                      SizedBox(
                        width: 110,
                        child: Text(
                          asset.marketGroups.isEmpty
                              ? '—'
                              : asset.marketGroups.join(', '),
                        ),
                      ),
                    ),
                    DataCell(SizedBox(width: 130, child: Text(asset.sector))),
                    DataCell(
                      Text(
                        provider.quoteUpdatedAt(asset) == null
                            ? 'Kein Kurs'
                            : CurrencyFormatter.formatPrice(asset.currentPrice),
                      ),
                    ),
                    DataCell(
                      Text(
                        provider.quoteUpdatedAt(asset) == null
                            ? '—'
                            : CurrencyFormatter.formatPercent(
                                asset.change24hPercent,
                              ),
                        style: TextStyle(
                          color: asset.isPositive
                              ? AppColors.profit
                              : AppColors.loss,
                        ),
                      ),
                    ),
                    DataCell(
                      Tooltip(
                        message: provider.quoteStatus(asset),
                        child: Text(_quoteTime(provider.quoteUpdatedAt(asset))),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        tooltip: asset.isWatchlisted
                            ? '${asset.symbol} aus Watchlist entfernen'
                            : '${asset.symbol} zur Watchlist hinzufügen',
                        onPressed: () => provider.toggleWatchlist(asset),
                        color: AppColors.primary,
                        icon: Icon(
                          asset.isWatchlisted ? Icons.star : Icons.star_border,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _quoteTime(DateTime? value) {
    if (value == null) return 'Kein Kurs';
    final date = value.toLocal();
    return '${date.day}.${date.month}. ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

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

  Widget _noHits() => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 320),
    child: EmptyState(
      icon: Icons.search_off,
      title: 'Keine Treffer',
      message:
          'Zu dieser Suche passt kein Instrument. Passe Suche oder Filter an.',
      actionLabel: 'Filter zurücksetzen',
      onAction: _reset,
    ),
  );

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
            .where((sector) => sector.isNotEmpty && sector != 'Unbekannt')
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
      final descending = _sort.endsWith('Desc');
      final key = descending ? _sort.substring(0, _sort.length - 4) : _sort;
      if (['index', 'sector', 'time', 'watchlist'].contains(key)) {
        final result = switch (key) {
          'index' =>
            a.marketGroups.join(', ').compareTo(b.marketGroups.join(', ')),
          'sector' => a.sector.compareTo(b.sector),
          'time' => (provider.quoteUpdatedAt(a) ?? DateTime(1970)).compareTo(
            provider.quoteUpdatedAt(b) ?? DateTime(1970),
          ),
          _ => (a.isWatchlisted ? 1 : 0).compareTo(b.isWatchlisted ? 1 : 0),
        };
        if (result != 0) return descending ? -result : result;
      }
      if (_sort != 'name' && _sort != 'nameDesc') {
        final aHasQuote = provider.quoteUpdatedAt(a) != null;
        final bHasQuote = provider.quoteUpdatedAt(b) != null;
        if (aHasQuote != bHasQuote) return aHasQuote ? -1 : 1;
        if (aHasQuote) {
          final result = switch (_sort) {
            'priceAsc' => a.currentPrice.compareTo(b.currentPrice),
            'priceAscDesc' => b.currentPrice.compareTo(a.currentPrice),
            'priceDesc' => b.currentPrice.compareTo(a.currentPrice),
            'gain' => b.change24hPercent.compareTo(a.change24hPercent),
            'loss' => a.change24hPercent.compareTo(b.change24hPercent),
            'lossDesc' => b.change24hPercent.compareTo(a.change24hPercent),
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
      body: LayoutBuilder(
        builder: (context, bodyConstraints) {
          final filters = Padding(
            key: _filtersKey,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: 'Instrument suchen',
                    hintText: 'Name, Symbol oder Industrie',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Suche löschen',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _debounce?.cancel();
                              _search.clear();
                              _change(() => _query = '');
                            },
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 250), () {
                      if (mounted) _change(() => _query = value);
                    });
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      PopupMenuButton<String>(
                        tooltip: 'Gespeicherte Filteransichten',
                        onSelected: (name) => _applyView(switch (name) {
                          'preset:DAX' => {
                            'groups': ['DAX'],
                          },
                          'preset:ATX' => {
                            'groups': ['ATX'],
                          },
                          'preset:Nasdaq Technologie' => {
                            'groups': ['Nasdaq'],
                            'sector': 'Technologie',
                          },
                          _ => _views[name] ?? {},
                        }),
                        itemBuilder: (_) => [
                          for (final name in [
                            'DAX',
                            'ATX',
                            'Nasdaq Technologie',
                          ])
                            PopupMenuItem(
                              value: 'preset:$name',
                              child: Text(name),
                            ),
                          if (_views.isNotEmpty) const PopupMenuDivider(),
                          for (final name in _views.keys)
                            PopupMenuItem(value: name, child: Text(name)),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Ansichten'),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _savingView ? null : _saveView,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const Text('Ansicht speichern'),
                      ),
                      if (_views.isNotEmpty)
                        PopupMenuButton<String>(
                          tooltip: 'Persönliche Ansicht löschen',
                          icon: const Icon(Icons.bookmark_remove_outlined),
                          onSelected: _savingView
                              ? null
                              : (name) =>
                                    _persistViews({..._views}..remove(name)),
                          itemBuilder: (_) => [
                            for (final name in _views.keys)
                              PopupMenuItem(value: name, child: Text(name)),
                          ],
                        ),
                    ],
                  ),
                ),
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
                if (active)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (_query.isNotEmpty)
                          InputChip(
                            label: Text('Suche: $_query'),
                            onDeleted: () {
                              _debounce?.cancel();
                              _search.clear();
                              _change(() => _query = '');
                            },
                          ),
                        if (_type != null)
                          InputChip(
                            label: Text(_type!.displayName),
                            onDeleted: () => _change(() => _type = null),
                          ),
                        for (final group in _groups)
                          InputChip(
                            label: Text('Index: $group'),
                            onDeleted: () =>
                                _change(() => _groups.remove(group)),
                          ),
                        if (_sector != null)
                          InputChip(
                            label: Text('Branche: $_sector'),
                            onDeleted: () => _change(() => _sector = null),
                          ),
                        if (_watchlist)
                          InputChip(
                            label: const Text('Nur Watchlist'),
                            onDeleted: () => _change(() => _watchlist = false),
                          ),
                        if (_open)
                          InputChip(
                            label: const Text('Börse offen'),
                            onDeleted: () => _change(() => _open = false),
                          ),
                        if (_sort != 'name')
                          InputChip(
                            label: const Text('Sortierung aktiv'),
                            onDeleted: () => _change(() => _sort = 'name'),
                          ),
                      ],
                    ),
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
                          onChanged: (value) => _change(() => _type = value),
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
                          onChanged: (value) => _change(() => _sector = value),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue:
                              [
                                'name',
                                'nameDesc',
                                'priceAsc',
                                'priceDesc',
                                'gain',
                                'loss',
                              ].contains(_sort)
                              ? _sort
                              : null,
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
          );
          final summary = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${filtered.length} Treffer · ${provider.assets.length} Instrumente',
                    style: TextStyle(color: AppColors.textSecondary),
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
          );
          // Short or zoomed-in screens: filters and results scroll together,
          // otherwise the fixed filter area leaves no room for the list.
          // Judge by the window, not the body: the on-screen keyboard shrinks
          // the body, and switching layouts then rebuilt the search field and
          // closed the keyboard while typing.
          final windowHeight = MediaQuery.sizeOf(context).height;
          if (windowHeight < 560 ||
              (MediaQuery.textScalerOf(context).scale(1) >= 1.5 &&
                  bodyConstraints.maxWidth < 1000)) {
            return RefreshIndicator(
              onRefresh: () => provider.fetchLiveMarketQuotes(),
              child: ListView(
                controller: _scroll,
                children: [
                  filters,
                  summary,
                  if (pageAssets.isEmpty)
                    _noHits()
                  else
                    for (final asset in pageAssets)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: AssetCard(
                          asset: asset,
                          onTap: () => _openAsset(asset),
                        ),
                      ),
                ],
              ),
            );
          }
          return Column(
            children: [
              Flexible(
                flex: 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: bodyConstraints.maxHeight * 0.45,
                  ),
                  child: SingleChildScrollView(child: filters),
                ),
              ),
              summary,
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.fetchLiveMarketQuotes(),
                  child: pageAssets.isEmpty
                      ? ListView(children: [_noHits()])
                      : MediaQuery.sizeOf(context).width >= 1000
                      ? _desktopTable(pageAssets, provider)
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
                              onTap: () => _openAsset(asset),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
