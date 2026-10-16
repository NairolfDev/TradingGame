import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/models/asset.dart';
import '../data/models/position.dart';
import '../data/models/transaction.dart';
import '../data/models/luxury_item.dart';
import '../data/models/rank_info.dart';
import '../data/models/pending_order.dart';
import '../data/models/news_event.dart';
import '../data/models/leaderboard_entry.dart';
import '../data/models/market_schedule.dart';
import '../data/models/loan_model.dart';
import '../data/repositories/trading_repository.dart';
import 'market_engine.dart';
import 'trading_fee_service.dart';
import 'credit_rating_service.dart';
import 'news_service.dart';
import 'quest_service.dart';
import 'turbo_options_service.dart';
import 'dividend_service.dart';
import '../data/models/turbo_option.dart';
import '../data/models/copy_trader.dart';
import '../data/models/daily_quest.dart';
import '../data/mock_data/initial_copy_traders.dart';

class PortfolioProvider extends ChangeNotifier {
  final TradingRepository repository;
  final MarketEngine marketEngine = MarketEngine();
  final NewsService newsService = NewsService();
  final QuestService questService = QuestService();
  final TurboOptionsService turboService = TurboOptionsService();
  final Uuid _uuid = const Uuid();

  double _cash = 50000.0;
  List<Asset> _assets = [];
  List<Position> _positions = [];
  List<TransactionRecord> _transactions = [];
  List<LuxuryItem> _luxuryItems = [];
  List<PendingOrder> _pendingOrders = [];
  List<LeaderboardEntry> _leaderboard = [];
  List<Loan> _loans = [];
  final List<NewsEvent> _newsEvents = [];

  bool _isInsolvent = false;
  DateTime? _insolvencyLockoutUntil;
  DateTime? _lastLoanTakenAt;

  bool _isLoading = true;
  String? _lastAlertMessage;

  PortfolioProvider({required this.repository}) {
    _init();
  }

  // Getters
  double get cash => _cash;
  List<Asset> get assets => _assets;
  List<Position> get positions => _positions;
  List<TransactionRecord> get transactions => _transactions;
  List<LuxuryItem> get luxuryItems => _luxuryItems;
  List<PendingOrder> get pendingOrders =>
      _pendingOrders.where((o) => o.status == PendingOrderStatus.pending).toList();
  List<PendingOrder> get allPendingOrders => _pendingOrders;
  List<LeaderboardEntry> get leaderboard => _leaderboard;
  List<Loan> get loans => _loans;
  List<Loan> get activeLoans => _loans.where((l) => !l.isPaid).toList();
  List<NewsEvent> get newsEvents => _newsEvents;
  NewsEvent? get latestBreakingNews => newsService.latestNews ?? (_newsEvents.isNotEmpty ? _newsEvents.first : null);
  List<DailyQuest> get dailyQuests => questService.quests;
  int get loginStreakDays => questService.loginStreakDays;
  List<TurboOption> get activeTurboOptions => turboService.activeOptions;
  List<TurboOption> get settledTurboOptions => turboService.settledOptions;
  List<CopyTrader> get copyTraders => InitialCopyTraders.getTraders();
  double get totalAnnualDividends => DividendService.calculateAnnualDividendRunRate(_positions, _assets);
  double get monthlyPassiveIncome => DividendService.calculateMonthlyPassiveIncome(_positions, _assets);
  List<DividendScheduleItem> get dividendSchedule => DividendService.getDividendSchedule(_positions, _assets);

  bool get isLoading => _isLoading;
  String? get lastAlertMessage => _lastAlertMessage;

  // Insolvenz & Kreditsperre (5 echte Kalendertage = 120h)
  bool get isInsolvent => _isInsolvent || (_cash <= 0 && netWorth <= -10000);
  DateTime? get insolvencyLockoutUntil => _insolvencyLockoutUntil;
  DateTime? get lastLoanTakenAt => _lastLoanTakenAt;

  bool get isUnderCreditLockout {
    if (_insolvencyLockoutUntil == null) return false;
    return DateTime.now().isBefore(_insolvencyLockoutUntil!);
  }

  Duration get creditLockoutTimeRemaining {
    if (!isUnderCreditLockout || _insolvencyLockoutUntil == null) return Duration.zero;
    return _insolvencyLockoutUntil!.difference(DateTime.now());
  }

  // Kredit-Abkühlphase: Nach jedem Kredit mind. 24h Sperre
  bool get isLoanOnCooldown {
    if (_lastLoanTakenAt == null) return false;
    return DateTime.now().difference(_lastLoanTakenAt!).inHours < 24;
  }

  Duration get loanCooldownRemaining {
    if (!isLoanOnCooldown || _lastLoanTakenAt == null) return Duration.zero;
    final end = _lastLoanTakenAt!.add(const Duration(hours: 24));
    final diff = end.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get canTakeLoan {
    if (isUnderCreditLockout) return false;
    if (isLoanOnCooldown) return false;
    // Maximal 1 aktiver Bankkredit neben dem Startkredit
    final bankLoans = activeLoans.where((l) => l.id != 'initial_start_loan_50k').length;
    if (bankLoans >= 1) return false;
    return true;
  }

  void clearAlert() {
    _lastAlertMessage = null;
  }

  // Berechnete Depot-Werte
  double get totalPositionsValue {
    double sum = 0.0;
    for (final pos in _positions) {
      sum += pos.currentValue;
    }
    return sum;
  }

  double get totalLuxuryValue {
    double sum = 0.0;
    for (final item in _luxuryItems) {
      sum += item.totalValue;
    }
    return sum;
  }

  double get totalDebt {
    double sum = 0.0;
    for (final loan in activeLoans) {
      sum += loan.remainingDebt;
    }
    return sum;
  }

  // Net Worth berücksichtigt Cash + Positionen + Luxusgegenstände ABZÜGLICH Verbindlichkeiten/Kredite
  double get netWorth => _cash + totalPositionsValue + totalLuxuryValue - totalDebt;

  CreditRating get creditRating {
    final lossRecords = _transactions.where((t) => (t.realizedPnL ?? 0) < 0);
    final totalLosses = lossRecords.fold<double>(0.0, (sum, t) => sum + (t.realizedPnL?.abs() ?? 0));
    final liquidations = _transactions.where((t) => t.type == TransactionType.liquidation).length;
    return CreditRatingService.evaluateRating(
      netWorth: netWorth,
      totalDebt: totalDebt,
      realizedLosses: totalLosses,
      liquidationsCount: liquidations,
    );
  }

  double get totalInvestedCost {
    double sum = 0.0;
    for (final pos in _positions) {
      sum += pos.isLeveraged ? pos.collateral : (pos.amount * pos.averageBuyPrice);
    }
    return sum;
  }

  double get totalUnrealizedPnL {
    double sum = 0.0;
    for (final pos in _positions) {
      sum += pos.unrealizedPnL;
    }
    return sum;
  }

  double get totalUnrealizedPnLPercent {
    if (totalInvestedCost <= 0) return 0.0;
    return totalUnrealizedPnL / totalInvestedCost;
  }

  double get totalRoiPercent {
    const startingCapital = 50000.0;
    return netWorth / startingCapital;
  }

  int get totalPrestigePoints {
    int sum = 0;
    for (final item in _luxuryItems) {
      sum += item.ownedCount * item.prestigePoints;
    }
    return sum;
  }

  RankInfo get currentRank => RankInfo.getRankForNetWorth(netWorth);
  RankInfo? get nextRank => RankInfo.getNextRank(netWorth);

  double get rankProgress {
    final next = nextRank;
    if (next == null) return 1.0;
    final currentMin = currentRank.minNetWorth;
    final target = next.minNetWorth;
    if (target <= currentMin) return 1.0;
    final progress = (netWorth - currentMin) / (target - currentMin);
    return progress.clamp(0.0, 1.0);
  }

  // Initialisierung
  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    _cash = await repository.getCashBalance();
    _assets = await repository.getAssets();
    _positions = await repository.getPositions();
    _transactions = await repository.getTransactions();
    _luxuryItems = await repository.getLuxuryItems();
    _pendingOrders = await repository.getPendingOrders();
    _leaderboard = await repository.getLeaderboard();
    _loans = await repository.getLoans();

    if (_loans.isEmpty) {
      final startLoan = Loan.createInitialStartLoan();
      _loans = [startLoan];
      await repository.saveLoans(_loans);
    }

    final insolvencyData = await repository.getInsolvencyStatus();
    _isInsolvent = insolvencyData['isInsolvent'] as bool? ?? false;
    if (insolvencyData['lockoutUntil'] != null) {
      _insolvencyLockoutUntil = DateTime.tryParse(insolvencyData['lockoutUntil'] as String);
    }
    if (insolvencyData['lastLoanTakenAt'] != null) {
      _lastLoanTakenAt = DateTime.tryParse(insolvencyData['lastLoanTakenAt'] as String);
    }

    // Starte Market Engine
    marketEngine.start(
      initialAssets: _assets,
      priceCallback: _onPriceUpdate,
      newsCallback: _onNewsGenerated,
    );

    // Initialisiere News Service
    newsService.initialize(_assets);
    newsService.onNewsDropped = (news) {
      _applyNewsImpact(news);
    };

    // Initialisiere Daily Quests
    questService.initialize();
    questService.recordTrade(
      tradeAmount: 0,
      isCommodity: false,
      leverage: 1,
      profit: 0,
      totalPositionsCount: _positions.length,
    );

    // Initialisiere Turbo Options Ticker
    turboService.startTicker((symbol) {
      final matching = _assets.firstWhere(
        (a) => a.symbol == symbol,
        orElse: () => _assets.first,
      );
      return matching.currentPrice;
    });

    turboService.onOptionSettled = (option) {
      final record = TransactionRecord(
        id: _uuid.v4(),
        symbol: option.assetSymbol,
        name: option.assetName,
        type: TransactionType.sell,
        amount: 1,
        price: option.finalPrice ?? option.entryPrice,
        totalAmount: option.isWon ? option.potentialPayout : 0.0,
        realizedPnL: option.profit,
        timestamp: DateTime.now(),
        note: option.isWon
            ? '⚡ 60s Turbo-Option (${option.direction == TurboDirection.call ? 'Call' : 'Put'}) GEWONNEN!'
            : '⚡ 60s Turbo-Option (${option.direction == TurboDirection.call ? 'Call' : 'Put'}) VERLOREN',
      );

      if (option.isWon) {
        _cash += option.potentialPayout;
        _lastAlertMessage = '🎉 Turbo-Option gewonnen! +${option.potentialPayout.toStringAsFixed(2)} €!';
      } else {
        _lastAlertMessage = '❌ Turbo-Option verloren (-${option.stake.toStringAsFixed(2)} €).';
      }
      _transactions.insert(0, record);
      repository.saveCashBalance(_cash);
      repository.saveTransaction(record);
      notifyListeners();
    };

    // Initiales Update der Positionspreise & Leaderboard
    _updatePositionsWithCurrentAssetPrices();
    _updateLeaderboard();

    _isLoading = false;
    notifyListeners();
  }

  bool isAssetMarketOpen(Asset asset) {
    final schedule = MarketSchedule.forAsset(asset);
    return schedule.isMarketOpen();
  }

  String getMarketStatusString(Asset asset) {
    final schedule = MarketSchedule.forAsset(asset);
    return schedule.getNextOpenTimeString();
  }

  // Preisschwankungen aus Market Engine verarbeiten
  void _onPriceUpdate(List<Asset> updatedAssets) {
    _assets = updatedAssets;
    marketEngine.updateAssetsReference(_assets);

    _updatePositionsWithCurrentAssetPrices();
    _checkAndExecutePendingOrders();
    _checkBondsCouponPayout();
    _updateLeaderboard();

    // Gelegentlich im Hintergrund speichern
    repository.saveAssets(_assets);
    notifyListeners();
  }

  void _onNewsGenerated(NewsEvent news) {
    _applyNewsImpact(news);
  }

  void _applyNewsImpact(NewsEvent news) {
    if (news.affectedSymbol != null && news.affectedSymbol!.isNotEmpty) {
      final idx = _assets.indexWhere((a) => a.symbol == news.affectedSymbol);
      if (idx != -1) {
        final asset = _assets[idx];
        final newPrice = (asset.currentPrice * (1 + news.priceImpact)).clamp(0.0001, 1000000.0);
        final rounded = double.parse(newPrice.toStringAsFixed(newPrice > 500 ? 2 : 4));
        _assets[idx] = asset.copyWithPrice(rounded);
        _updatePositionsWithCurrentAssetPrices();
        repository.saveAssets(_assets);
      }
    }
    _newsEvents.insert(0, news);
    if (_newsEvents.length > 30) {
      _newsEvents.removeLast();
    }
    _lastAlertMessage = '⚡ Eilmeldung: ${news.headline}';
    notifyListeners();
  }

  void _updatePositionsWithCurrentAssetPrices() {
    bool hasLiquidations = false;
    final remainingPositions = <Position>[];

    for (final pos in _positions) {
      final matchingAsset = _assets.firstWhere(
        (a) => a.id == pos.assetId || a.symbol == pos.symbol,
        orElse: () => Asset(
          id: pos.assetId,
          symbol: pos.symbol,
          name: pos.name,
          type: pos.type,
          currentPrice: pos.currentPrice,
          previousClose: pos.currentPrice,
          dailyHigh: pos.currentPrice,
          dailyLow: pos.currentPrice,
          priceHistory: [pos.currentPrice],
          volatility: 0.01,
          description: '',
        ),
      );

      final updatedPos = pos.copyWith(currentPrice: matchingAsset.currentPrice);

      // Prüfe auf Zwangsliquidation bei Hebelprodukten
      if (updatedPos.isLiquidated) {
        hasLiquidations = true;
        _handleLiquidation(updatedPos);
      } else {
        remainingPositions.add(updatedPos);
      }
    }

    _positions = remainingPositions;
    if (hasLiquidations) {
      repository.savePositions(_positions);
    }
  }

  void _handleLiquidation(Position pos) {
    _lastAlertMessage =
        '⚠️ ZWANGSLIQUIDATION! Deine Position ${pos.symbol} (${pos.leverage}x Hebel) wurde liquidiert. Margin verloren!';

    final record = TransactionRecord(
      id: _uuid.v4(),
      symbol: pos.symbol,
      name: pos.name,
      type: TransactionType.liquidation,
      amount: pos.amount,
      price: pos.currentPrice,
      totalAmount: 0.0,
      realizedPnL: -pos.collateral,
      timestamp: DateTime.now(),
      note: '${pos.leverage}x Hebel Margin Call erreicht',
    );

    _transactions.insert(0, record);
    repository.saveTransaction(record);
  }

  // --- TRADING LOGIK (KAUFEN / VERKAUFEN / VORAB-ORDER) ---

  /// Führt einen Sofort-Kauf aus (falls Markt offen) ODER legt eine Vorab-Order an (falls Markt geschlossen)
  Future<bool> executeBuy({
    required Asset asset,
    required double amount,
    int leverage = 1,
    bool isShort = false,
  }) async {
    final isOpen = isAssetMarketOpen(asset);
    final breakdown = TradingFeeService.calculateBuyFee(
      asset: asset,
      amount: amount,
      leverage: leverage,
    );
    final totalCost = breakdown.totalCashRequired;
    final fee = breakdown.transactionFee;

    if (totalCost > _cash) {
      _lastAlertMessage =
          'Nicht genügend Bargeld vorhanden! (Inkl. ${fee.toStringAsFixed(2)} € Börsenspesen)';
      notifyListeners();
      return false;
    }

    if (!isOpen) {
      // BÖRSE GESCHLOSSEN -> VORAB-ORDER ERSTELLEN
      _cash -= totalCost; // Cash für Vorab-Order reservieren
      await repository.saveCashBalance(_cash);

      final pendingOrder = PendingOrder(
        id: _uuid.v4(),
        assetId: asset.id,
        symbol: asset.symbol,
        name: asset.name,
        assetType: asset.type,
        isBuy: true,
        amount: amount,
        estimatedPrice: asset.currentPrice,
        totalEstimatedCost: totalCost,
        leverage: leverage,
        isShort: isShort,
      );

      _pendingOrders.insert(0, pendingOrder);
      await repository.savePendingOrders(_pendingOrders);

      _lastAlertMessage =
          '🕒 Börse geschlossen: Vorab-Kauforder für ${asset.symbol} vorgemerkt! Wird automatisch bei Marktöffnung ausgeführt.';
      notifyListeners();
      return true;
    }

    // BÖRSE GEÖFFNET -> SOFORTIGE AUSFÜHRUNG
    _cash -= totalCost;
    await repository.saveCashBalance(_cash);

    // Prüfen, ob bereits eine gleiche Spot-Position existiert (nur bei Spot / leverage == 1)
    if (leverage == 1 && !isShort) {
      final existingIndex = _positions.indexWhere(
        (p) => p.assetId == asset.id && !p.isLeveraged && !p.isShort,
      );

      if (existingIndex != -1) {
        final existing = _positions[existingIndex];
        final newTotalAmount = existing.amount + amount;
        final newAvgPrice = ((existing.amount * existing.averageBuyPrice) +
                (amount * asset.currentPrice)) /
            newTotalAmount;

        _positions[existingIndex] = existing.copyWith(
          amount: newTotalAmount,
          averageBuyPrice: newAvgPrice,
          currentPrice: asset.currentPrice,
        );
      } else {
        _positions.add(
          Position(
            id: _uuid.v4(),
            assetId: asset.id,
            symbol: asset.symbol,
            name: asset.name,
            type: asset.type,
            amount: amount,
            averageBuyPrice: asset.currentPrice,
            currentPrice: asset.currentPrice,
            leverage: 1,
            isShort: false,
          ),
        );
      }
    } else {
      // Hebelpositionen werden als eigenständige Kontrakte geführt
      _positions.add(
        Position(
          id: _uuid.v4(),
          assetId: asset.id,
          symbol: asset.symbol,
          name: asset.name,
          type: asset.type,
          amount: amount,
          averageBuyPrice: asset.currentPrice,
          currentPrice: asset.currentPrice,
          leverage: leverage,
          isShort: isShort,
          collateral: breakdown.assetCost,
        ),
      );
    }

    await repository.savePositions(_positions);

    // Transaktionshistorie eintragen
    final record = TransactionRecord(
      id: _uuid.v4(),
      symbol: asset.symbol,
      name: asset.name,
      type: TransactionType.buy,
      amount: amount,
      price: asset.currentPrice,
      totalAmount: totalCost,
      timestamp: DateTime.now(),
      note: leverage > 1 ? '${leverage}x Hebel ${isShort ? "Short" : "Long"}' : 'Spot Kauf',
    );

    _transactions.insert(0, record);
    await repository.saveTransaction(record);

    questService.recordTrade(
      tradeAmount: totalCost,
      isCommodity: asset.type == AssetType.commodity,
      leverage: leverage,
      profit: 0,
      totalPositionsCount: _positions.length,
    );

    _lastAlertMessage = 'Erfolgreich gekauft: ${amount.toStringAsFixed(2)}x ${asset.symbol}';
    notifyListeners();
    return true;
  }

  /// Verkauft eine Position (teilweise oder ganz)
  Future<bool> executeSell({
    required Position position,
    required double sellAmount,
  }) async {
    final asset = _assets.firstWhere(
      (a) => a.id == position.assetId || a.symbol == position.symbol,
    );

    final isOpen = isAssetMarketOpen(asset);

    if (!isOpen) {
      _lastAlertMessage =
          'Börse für ${asset.symbol} ist geschlossen. Verkäufe können nur während der Handelszeiten abgewickelt werden.';
      notifyListeners();
      return false;
    }

    if (sellAmount > position.amount) {
      _lastAlertMessage = 'Verkaufsmenge übersteigt den Bestand!';
      notifyListeners();
      return false;
    }

    // Anteiliger PnL und Rückfluss
    final ratio = sellAmount / position.amount;
    double cashReturn = 0.0;
    double realizedPnL = 0.0;

    if (!position.isLeveraged) {
      cashReturn = sellAmount * asset.currentPrice;
      realizedPnL = (asset.currentPrice - position.averageBuyPrice) * sellAmount;
    } else {
      final portionCollateral = position.collateral * ratio;
      final portionPnL = position.unrealizedPnL * ratio;
      cashReturn = portionCollateral + portionPnL;
      if (cashReturn < 0) cashReturn = 0.0;
      realizedPnL = portionPnL;
    }

    _cash += cashReturn;
    await repository.saveCashBalance(_cash);

    if (sellAmount >= position.amount) {
      _positions.removeWhere((p) => p.id == position.id);
    } else {
      final remainingAmount = position.amount - sellAmount;
      final index = _positions.indexWhere((p) => p.id == position.id);
      if (index != -1) {
        _positions[index] = position.copyWith(
          amount: remainingAmount,
          currentPrice: asset.currentPrice,
        );
      }
    }

    await repository.savePositions(_positions);

    final record = TransactionRecord(
      id: _uuid.v4(),
      symbol: position.symbol,
      name: position.name,
      type: TransactionType.sell,
      amount: sellAmount,
      price: asset.currentPrice,
      totalAmount: cashReturn,
      realizedPnL: realizedPnL,
      timestamp: DateTime.now(),
      note: 'Verkauf Realisiert: ${realizedPnL >= 0 ? "+" : ""}${realizedPnL.toStringAsFixed(2)} €',
    );

    _transactions.insert(0, record);
    await repository.saveTransaction(record);

    questService.recordTrade(
      tradeAmount: cashReturn,
      isCommodity: position.type == AssetType.commodity,
      leverage: position.leverage,
      profit: realizedPnL,
      totalPositionsCount: _positions.length,
    );

    _lastAlertMessage =
        'Verkauft: ${sellAmount.toStringAsFixed(2)}x ${position.symbol} (Rendite: ${realizedPnL >= 0 ? "+" : ""}${realizedPnL.toStringAsFixed(2)} €)';
    notifyListeners();
    return true;
  }

  /// Prüft bei Marktöffnung, ob anstehende Vorab-Orders ausgeführt werden können
  void _checkAndExecutePendingOrders() {
    bool changes = false;

    for (final order in _pendingOrders) {
      if (order.status != PendingOrderStatus.pending) continue;

      final matchingAsset = _assets.firstWhere(
        (a) => a.id == order.assetId || a.symbol == order.symbol,
      );

      if (isAssetMarketOpen(matchingAsset)) {
        // Börse ist JETZT offen! Ausführen zum aktuellen Markt-Eröffnungskurs
        order.status = PendingOrderStatus.executed;
        order.executedAt = DateTime.now();
        order.executedPrice = matchingAsset.currentPrice;
        changes = true;

        // Position erzeugen
        _positions.add(
          Position(
            id: _uuid.v4(),
            assetId: matchingAsset.id,
            symbol: matchingAsset.symbol,
            name: matchingAsset.name,
            type: matchingAsset.type,
            amount: order.amount,
            averageBuyPrice: matchingAsset.currentPrice,
            currentPrice: matchingAsset.currentPrice,
            leverage: order.leverage,
            isShort: order.isShort,
            collateral: (order.amount * matchingAsset.currentPrice) / order.leverage,
          ),
        );

        final record = TransactionRecord(
          id: _uuid.v4(),
          symbol: matchingAsset.symbol,
          name: matchingAsset.name,
          type: TransactionType.buy,
          amount: order.amount,
          price: matchingAsset.currentPrice,
          totalAmount: order.totalEstimatedCost,
          timestamp: DateTime.now(),
          note: 'Vorab-Order bei Börsenöffnung ausgeführt!',
        );

        _transactions.insert(0, record);
        repository.saveTransaction(record);

        _lastAlertMessage =
            '🔔 VORAB-ORDER AUSGEFÜHRT: Börse geöffnet für ${matchingAsset.symbol}! ${order.amount.toStringAsFixed(2)}x eingebucht.';
      }
    }

    if (changes) {
      repository.savePendingOrders(_pendingOrders);
      repository.savePositions(_positions);
    }
  }

  /// Storniert eine noch nicht ausgeführte Vorab-Order und erstattet das reservierte Geld
  Future<void> cancelPendingOrder(PendingOrder order) async {
    if (order.status != PendingOrderStatus.pending) return;

    order.status = PendingOrderStatus.cancelled;
    _cash += order.totalEstimatedCost; // Geld zurückerstatten
    await repository.saveCashBalance(_cash);
    await repository.savePendingOrders(_pendingOrders);

    _lastAlertMessage = 'Vorab-Order für ${order.symbol} storniert. Betrag erstattet.';
    notifyListeners();
  }

  // --- ANLEIHEN KUPON-AUSSCHÜTTUNG ---
  int _ticksCount = 0;
  void _checkBondsCouponPayout() {
    _ticksCount++;
    // Alle 20 Ticks (~50 Sekunden) wird ein anteiliger Zinskupon gutgeschrieben
    if (_ticksCount % 20 != 0) return;

    double totalCouponPaid = 0.0;
    for (final pos in _positions) {
      if (pos.type == AssetType.bond) {
        final asset = _assets.firstWhere((a) => a.id == pos.assetId);
        final rate = asset.couponRate ?? 0.035;
        // Simulierte anteilige Ausschüttung
        final payout = (pos.amount * pos.currentPrice) * (rate / 365 * 10);
        if (payout > 0.01) {
          totalCouponPaid += payout;
          final record = TransactionRecord(
            id: _uuid.v4(),
            symbol: pos.symbol,
            name: pos.name,
            type: TransactionType.couponPayout,
            amount: 1,
            price: payout,
            totalAmount: payout,
            timestamp: DateTime.now(),
            note: 'Zinskupon ${(rate * 100).toStringAsFixed(1)}% p.a.',
          );
          _transactions.insert(0, record);
          repository.saveTransaction(record);
        }
      }
    }

    if (totalCouponPaid > 0) {
      _cash += totalCouponPaid;
      repository.saveCashBalance(_cash);
      _lastAlertMessage =
          '💰 Kupon-Gutschrift! Du hast ${totalCouponPaid.toStringAsFixed(2)} € Zinsen auf deine Anleihen erhalten.';
    }
  }

  // --- PRESTIGE & STATUS-SHOP ("Cooler werden") ---
  Future<bool> buyLuxuryItem(LuxuryItem item) async {
    if (_cash < item.price) {
      _lastAlertMessage = 'Nicht genügend Barmittel für ${item.name}!';
      notifyListeners();
      return false;
    }

    _cash -= item.price;
    item.ownedCount += 1;

    await repository.saveCashBalance(_cash);
    await repository.saveLuxuryItems(_luxuryItems);

    final record = TransactionRecord(
      id: _uuid.v4(),
      symbol: item.icon,
      name: item.name,
      type: TransactionType.luxuryPurchase,
      amount: 1,
      price: item.price,
      totalAmount: item.price,
      timestamp: DateTime.now(),
      note: 'Prestige: +${item.prestigePoints} Punkte',
    );

    _transactions.insert(0, record);
    await repository.saveTransaction(record);

    _lastAlertMessage = '🎉 Glückwunsch! Du hast ${item.name} erworben. Dein Prestige steigt!';
    _updateLeaderboard();
    notifyListeners();
    return true;
  }

  // --- KREDIT & SCHULDEN SYSTEM ---
  Future<void> declareInsolvency() async {
    _isInsolvent = true;
    _insolvencyLockoutUntil = DateTime.now().add(const Duration(days: 5)); // 5 echte Tage = 120h
    
    // Notverkauf aller Positionen
    for (final pos in List<Position>.from(_positions)) {
      final recoveryCash = pos.currentValue * 0.8;
      _cash += recoveryCash;
    }
    _positions.clear();
    await repository.savePositions(_positions);

    if (_cash < 0) {
      _cash = 0;
    }

    await repository.saveCashBalance(_cash);
    await repository.saveInsolvencyStatus(
      isInsolvent: _isInsolvent,
      lockoutUntil: _insolvencyLockoutUntil,
      lastLoanTakenAt: _lastLoanTakenAt,
    );

    final record = TransactionRecord(
      id: _uuid.v4(),
      symbol: '🚨',
      name: 'Privatinsolvenz angemeldet',
      type: TransactionType.liquidation,
      amount: 1,
      price: 0,
      totalAmount: 0,
      timestamp: DateTime.now(),
      note: '5 Tage Kreditsperre verhängt. Sanierungsverfahren eingeleitet.',
    );
    _transactions.insert(0, record);
    await repository.saveTransaction(record);

    _lastAlertMessage = '🚨 PRIVATINSOLVENZ ANGEMELDET! 5 Tage Kreditsperre aktiv.';
    _updateLeaderboard();
    notifyListeners();
  }

  Future<bool> takeLoan({
    required double principal,
    required int durationDays,
  }) async {
    if (isUnderCreditLockout) {
      final rem = creditLockoutTimeRemaining;
      _lastAlertMessage =
          '🚨 Kreditsperre aktiv! Du musst noch ${rem.inDays} Tage und ${rem.inHours % 24} Stunden warten.';
      notifyListeners();
      return false;
    }

    if (!canTakeLoan) {
      if (isLoanOnCooldown) {
        final rem = loanCooldownRemaining;
        _lastAlertMessage =
            '⏳ Kredit-Abkühlphase: Nach jedem Kredit gilt eine 24-Stunden-Sperre (noch ${rem.inHours}h ${rem.inMinutes % 60}m)!';
      } else {
        _lastAlertMessage = '⚠️ Du hast bereits einen aktiven Bankkredit! Tilge diesen zuerst ab.';
      }
      notifyListeners();
      return false;
    }

    final rating = creditRating;
    final interest = CreditRatingService.calculateLoanInterest(
      principal: principal,
      durationDays: durationDays,
      interestRate: rating.baseInterestRate,
    );
    final totalDebtToRepay = principal + interest;
    final now = DateTime.now();

    final loan = Loan(
      id: _uuid.v4(),
      title: 'Bankkredit (${rating.grade})',
      principal: principal,
      interestRate: rating.baseInterestRate,
      remainingDebt: totalDebtToRepay,
      takenAt: now,
      dueDate: now.add(Duration(days: durationDays)),
      durationDays: durationDays,
    );

    _cash += principal;
    _loans.insert(0, loan);
    _lastLoanTakenAt = now;
    _isInsolvent = false; // Wieder aktiv im Spiel

    await repository.saveCashBalance(_cash);
    await repository.saveLoans(_loans);
    await repository.saveInsolvencyStatus(
      isInsolvent: _isInsolvent,
      lockoutUntil: _insolvencyLockoutUntil,
      lastLoanTakenAt: _lastLoanTakenAt,
    );

    final record = TransactionRecord(
      id: _uuid.v4(),
      symbol: '🏦',
      name: 'Kreditaufnahme (${rating.grade})',
      type: TransactionType.loanPayout,
      amount: 1,
      price: principal,
      totalAmount: principal,
      timestamp: now,
      note: '${principal.toStringAsFixed(0)} € zu ${(rating.baseInterestRate * 100).toStringAsFixed(1)}% p.a. ($durationDays Tage)',
    );

    _transactions.insert(0, record);
    await repository.saveTransaction(record);

    _lastAlertMessage =
        '💳 Kredit über ${principal.toStringAsFixed(0)} € ausgezahlt! Zinssatz: ${(rating.baseInterestRate * 100).toStringAsFixed(1)}% p.a.';
    _updateLeaderboard();
    notifyListeners();
    return true;
  }

  Future<bool> repayLoan(Loan loan, double amount) async {
    if (amount <= 0) return false;
    if (_cash < amount) {
      _lastAlertMessage = 'Nicht genügend Barmittel für diese Kredittilgung!';
      notifyListeners();
      return false;
    }

    final actualRepay = amount > loan.remainingDebt ? loan.remainingDebt : amount;

    _cash -= actualRepay;
    loan.remainingDebt -= actualRepay;
    loan.paidAmount += actualRepay;

    if (loan.remainingDebt <= 0.01) {
      loan.remainingDebt = 0.0;
      loan.isPaid = true;
    }

    await repository.saveCashBalance(_cash);
    await repository.saveLoans(_loans);

    final record = TransactionRecord(
      id: _uuid.v4(),
      symbol: '💸',
      name: loan.isPaid ? 'Kredit vollständig getilgt' : 'Kredittilgung',
      type: TransactionType.loanRepayment,
      amount: 1,
      price: actualRepay,
      totalAmount: actualRepay,
      timestamp: DateTime.now(),
      note: 'Tilgung: -${actualRepay.toStringAsFixed(2)} € (Restschuld: ${loan.remainingDebt.toStringAsFixed(2)} €)',
    );

    _transactions.insert(0, record);
    await repository.saveTransaction(record);

    _lastAlertMessage = loan.isPaid
        ? '🎉 Bravo! Kredit "${loan.title}" vollständig zurückgezahlt!'
        : 'Kreditrate über ${actualRepay.toStringAsFixed(2)} € erfolgreich geleistet.';
    _updateLeaderboard();
    notifyListeners();
    return true;
  }

  // --- LEADERBOARD SYNCHRONISATION ---
  void _updateLeaderboard() {
    final playerEntryIndex = _leaderboard.indexWhere((e) => e.isPlayer);
    final luxuryCount = _luxuryItems.fold<int>(0, (sum, i) => sum + i.ownedCount);

    final playerEntry = LeaderboardEntry(
      id: 'player_user',
      name: 'Du (Börsen-Profi)',
      city: 'Wien / Österreich',
      title: currentRank.title,
      badge: currentRank.badge,
      avatarEmoji: '😎',
      strategy: 'Multi-Asset & Hebel',
      netWorth: netWorth,
      roiPercent: totalRoiPercent * 100,
      isPlayer: true,
      luxuryCount: luxuryCount,
    );

    if (playerEntryIndex != -1) {
      _leaderboard[playerEntryIndex] = playerEntry;
    } else {
      _leaderboard.add(playerEntry);
    }

    // Sortieren nach Net Worth absteigend
    _leaderboard.sort((a, b) => b.netWorth.compareTo(a.netWorth));

    // Ränge 1, 2, 3 neu vergeben
    for (int i = 0; i < _leaderboard.length; i++) {
      _leaderboard[i].rank = i + 1;
    }

    repository.saveLeaderboard(_leaderboard);
  }

  // --- 1. DAILY QUESTS & REWARDS ---
  void claimDailyQuest(String questId) {
    questService.claimQuest(questId, (cashReward, prestigeReward) {
      _cash += cashReward;
      repository.saveCashBalance(_cash);
      _lastAlertMessage = '🎁 Belohnung abgeholt: +${cashReward.toStringAsFixed(0)} € & +$prestigeReward Prestige!';
      _updateLeaderboard();
      notifyListeners();
    });
  }

  // --- 2. 60-SEKUNDEN TURBO-BLITZOPTIONEN ---
  bool placeTurboOption({
    required String assetSymbol,
    required String assetName,
    required double entryPrice,
    required TurboDirection direction,
    required double stake,
    required int durationSeconds,
  }) {
    if (_cash < stake || stake <= 0) return false;

    _cash -= stake;
    repository.saveCashBalance(_cash);

    turboService.placeOption(
      assetSymbol: assetSymbol,
      assetName: assetName,
      entryPrice: entryPrice,
      direction: direction,
      stake: stake,
      durationSeconds: durationSeconds,
    );

    final record = TransactionRecord(
      id: _uuid.v4(),
      symbol: assetSymbol,
      name: 'Turbo-Option (${direction == TurboDirection.call ? 'Call' : 'Put'})',
      type: TransactionType.buy,
      amount: 1,
      price: stake,
      totalAmount: stake,
      timestamp: DateTime.now(),
      note: 'Einsatz $durationSeconds Sekunden Blitz-Option',
    );
    _transactions.insert(0, record);
    repository.saveTransaction(record);
    notifyListeners();
    return true;
  }

  // --- 3. SOCIAL TRADING & COPY-TRADING ---
  Future<bool> copyTrader(CopyTrader trader, double allocatedAmount) async {
    if (_cash < allocatedAmount || allocatedAmount < 500) return false;

    _cash -= allocatedAmount;
    await repository.saveCashBalance(_cash);

    for (final entry in trader.portfolioAllocation.entries) {
      final symbol = entry.key;
      final weight = entry.value;
      final sliceAmount = allocatedAmount * weight;

      final asset = _assets.firstWhere(
        (a) => a.symbol == symbol,
        orElse: () => _assets.first,
      );

      final shares = sliceAmount / asset.currentPrice;

      final existingIndex = _positions.indexWhere((p) => p.symbol == asset.symbol && !p.isLeveraged);
      if (existingIndex != -1) {
        final existing = _positions[existingIndex];
        final totalOld = existing.amount * existing.averageBuyPrice;
        final totalNew = totalOld + sliceAmount;
        final newShares = existing.amount + shares;
        _positions[existingIndex] = existing.copyWith(
          amount: newShares,
          averageBuyPrice: totalNew / newShares,
          currentPrice: asset.currentPrice,
        );
      } else {
        _positions.add(Position(
          id: _uuid.v4(),
          assetId: asset.id,
          symbol: asset.symbol,
          name: asset.name,
          type: asset.type,
          amount: shares,
          averageBuyPrice: asset.currentPrice,
          currentPrice: asset.currentPrice,
          openedAt: DateTime.now(),
        ));
      }
    }

    final record = TransactionRecord(
      id: _uuid.v4(),
      symbol: 'COPY',
      name: 'Social Trading: ${trader.name}',
      type: TransactionType.buy,
      amount: 1,
      price: allocatedAmount,
      totalAmount: allocatedAmount,
      timestamp: DateTime.now(),
      note: 'Kopiert Portfolio von ${trader.name}',
    );
    _transactions.insert(0, record);

    await repository.savePositions(_positions);
    await repository.saveTransaction(record);
    _lastAlertMessage = '🤝 Du kopierst jetzt ${trader.name} mit ${allocatedAmount.toStringAsFixed(0)} €!';
    _updateLeaderboard();
    notifyListeners();
    return true;
  }

  // --- 4. DIVIDENDEN & PASSIVES EINKOMMEN ---
  void payoutSimulatedDividends() {
    final payout = monthlyPassiveIncome;
    if (payout <= 0) return;

    _cash += payout;
    repository.saveCashBalance(_cash);

    final record = TransactionRecord(
      id: _uuid.v4(),
      symbol: 'DIV',
      name: 'Monatliche Dividendenausschüttung',
      type: TransactionType.dividendPayout,
      amount: 1,
      price: payout,
      totalAmount: payout,
      realizedPnL: payout,
      timestamp: DateTime.now(),
      note: 'Passives Einkommen aus Aktien- und ETF-Dividenden',
    );
    _transactions.insert(0, record);
    repository.saveTransaction(record);
    _lastAlertMessage = '💵 Dividenden gutgeschrieben: +${payout.toStringAsFixed(2)} €!';
    _updateLeaderboard();
    notifyListeners();
  }

  // Spiel zurücksetzen (falls vom Nutzer gewünscht)
  Future<void> resetGame() async {
    await repository.resetGameToInitial();
    await _init();
  }

  @override
  void dispose() {
    marketEngine.stop();
    newsService.dispose();
    turboService.dispose();
    super.dispose();
  }
}
