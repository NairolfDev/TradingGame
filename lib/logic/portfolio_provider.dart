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
import 'net_worth_history.dart';
import '../data/models/market_schedule.dart';
import '../data/models/loan_model.dart';
import '../data/models/reward_event.dart';
import '../data/repositories/trading_repository.dart';
import '../data/repositories/local_trading_repository.dart';
import '../data/repositories/firebase_trading_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'bank_hours.dart';
import 'market_engine.dart';
import 'trading_fee_service.dart';
import 'bond_coupon_service.dart';
import 'credit_rating_service.dart';
import 'news_service.dart';
import 'quest_service.dart';
import 'dividend_service.dart';
import '../data/models/copy_trader.dart';
import '../data/models/daily_quest.dart';
import '../data/models/automation_order.dart';
import '../data/models/achievement.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/savings_plan.dart';
import 'savings_plan_service.dart';
import 'automation_service.dart';
import 'achievement_service.dart';
import 'live_market_data_service.dart';
import '../data/models/user_model.dart';
import '../data/countries.dart';

class PortfolioProvider extends ChangeNotifier {
  UserModel? _playerProfile;
  void updatePlayerProfile(UserModel? profile) {
    _playerProfile = profile;
  }

  String get playerCountry =>
      countryNames[_playerProfile?.countryCode] ?? 'Land nicht gewählt';
  TradingRepository repository;
  final MarketEngine marketEngine = MarketEngine();
  final NewsService newsService = NewsService();
  final QuestService questService = QuestService();
  final AutomationService automationService = AutomationService();
  final AchievementService achievementService = AchievementService();
  final LiveMarketDataService liveDataService = LiveMarketDataService();
  final SavingsPlanService savingsPlanService = SavingsPlanService();
  final Uuid _uuid = const Uuid();

  static const String _keySimplisticMode = 'tg_is_simplistic_mode';
  static const String _keyRealisticOrderDelay = 'tg_is_realistic_order_delay';

  bool _isSimplisticMode = false;
  bool _isRealisticOrderDelay = true;

  double _cash = 50000.0;
  List<Asset> _assets = [];
  List<Position> _positions = [];
  List<TransactionRecord> _transactions = [];
  List<LuxuryItem> _luxuryItems = [];
  List<PendingOrder> _pendingOrders = [];
  List<LeaderboardEntry> _leaderboard = [];
  List<Loan> _loans = [];
  final List<NewsEvent> _newsEvents = [];
  StreamSubscription<List<LeaderboardEntry>>? _leaderboardSubscription;
  StreamSubscription<User?>? _authSubscription;
  Timer? _liveMarketRefreshTimer;

  /// Net worth over time for the dashboard chart (device-local).
  final NetWorthHistory netWorthHistory = NetWorthHistory();

  void _recordNetWorth() {
    if (_isLoading) return;
    if (netWorthHistory.record(netWorth, DateTime.now())) {
      unawaited(netWorthHistory.save(_activeUid));
      notifyListeners();
    }
  }
  bool _refreshingQuotes = false;
  final Map<String, DateTime> _quoteUpdatedAt = {};
  final Map<String, LiveQuoteResult> _quoteDetails = {};
  final Set<String> _visibleMarketAssetIds = {};
  String _activeUid = 'local_player';

  bool _isInsolvent = false;
  DateTime? _insolvencyLockoutUntil;
  DateTime? _lastLoanTakenAt;

  bool _isLoading = true;
  String? _lastAlertMessage;

  PortfolioProvider({required this.repository}) {
    if (repository is FirebaseTradingRepository) {
      _activeUid = (repository as FirebaseTradingRepository).userId;
    }
    _init();
  }

  // Getters
  double get cash => _cash;
  List<Asset> get assets => _assets;
  List<Position> get positions => _positions;
  List<TransactionRecord> get transactions => _transactions;
  List<AutomationOrder> get activeAutomationOrders =>
      automationService.activeOrders;
  List<AutomationOrder> get allAutomationOrders => automationService.allOrders;
  int get unlockedAutomationSlotsCount => automationService.unlockedSlotsCount;
  double? get nextAutomationSlotCost => automationService.nextSlotCost;
  List<Achievement> get achievements => achievementService.achievements;
  int get unlockedAchievementsCount => achievementService.unlockedCount;
  List<Asset> get watchlistAssets =>
      _assets.where((a) => a.isWatchlisted).toList();
  bool get isSimplisticMode => _isSimplisticMode;
  bool get isRealisticOrderDelay => _isRealisticOrderDelay;
  DateTime? quoteUpdatedAt(Asset asset) => _quoteUpdatedAt[asset.id];
  String quoteStatus(Asset asset) {
    final updated = quoteUpdatedAt(asset);
    if (updated == null) return 'Kurs nicht verfügbar';
    final quote = _quoteDetails[asset.id];
    final time =
        '${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}';
    final date = '${updated.day}.${updated.month}.';
    final fx = quote?.usesSnapshotFx == true
        ? ' · EUR zum aktuellen FX-Kurs'
        : '';
    return '${quote?.source ?? 'Anbieter'} · Stand $date $time · ggf. verzögert$fx';
  }

  /// One short line for lists; the full provider/FX details stay in
  /// [quoteStatus] on the instrument page.
  String quoteStatusShort(Asset asset) {
    final updated = quoteUpdatedAt(asset);
    if (updated == null) return 'Kurs nicht verfügbar';
    final time =
        '${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}';
    return 'Stand ${updated.day}.${updated.month}. $time · ggf. verzögert';
  }

  void setVisibleMarketAssets(Iterable<Asset> assets) {
    final ids = assets.map((a) => a.id).take(50).toSet();
    if (setEquals(ids, _visibleMarketAssetIds)) return;
    _visibleMarketAssetIds
      ..clear()
      ..addAll(ids);
    if (ids.isNotEmpty) fetchLiveMarketQuotes();
  }

  List<SavingsPlan> get savingsPlans => savingsPlanService.plans;
  List<SavingsPlan> get activeSavingsPlans => savingsPlanService.activePlans;

  Future<void> setSimplisticMode(bool enabled) async {
    _isSimplisticMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySimplisticMode, enabled);
    notifyListeners();
  }

  Future<void> setRealisticOrderDelay(bool enabled) async {
    _isRealisticOrderDelay = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRealisticOrderDelay, enabled);
    notifyListeners();
  }

  List<LuxuryItem> get luxuryItems => _luxuryItems;
  List<PendingOrder> get pendingOrders => _pendingOrders
      .where((o) => o.status == PendingOrderStatus.pending)
      .toList();
  List<PendingOrder> get allPendingOrders => _pendingOrders;
  List<LeaderboardEntry> get leaderboard => _leaderboard;

  /// False for guests and accounts without a chosen name: they are not ranked.
  bool get isOnLeaderboard => _isOnLeaderboard;
  bool _isOnLeaderboard = false;
  List<Loan> get loans => _loans;
  List<Loan> get activeLoans => _loans.where((l) => !l.isPaid).toList();
  List<NewsEvent> get newsEvents => _newsEvents;
  NewsEvent? get latestBreakingNews =>
      _newsEvents.isNotEmpty ? _newsEvents.first : null;
  List<DailyQuest> get dailyQuests => questService.quests;
  int get loginStreakDays => questService.loginStreakDays;
  // No public portfolio feed is available yet.
  List<CopyTrader> get copyTraders => const [];
  double get totalAnnualDividends =>
      DividendService.calculateAnnualDividendRunRate(_positions, _assets);
  double get monthlyPassiveIncome =>
      DividendService.calculateMonthlyPassiveIncome(_positions, _assets);
  List<DividendScheduleItem> get dividendSchedule =>
      DividendService.getDividendSchedule(_positions, _assets);

  bool get isLoading => _isLoading;
  String? get lastAlertMessage => _lastAlertMessage;

  final _rewards = StreamController<RewardEvent>.broadcast();

  /// Lets other layers (e.g. a foreground push message) use the same overlay.
  void announce(RewardEvent event) => _reward(event);

  /// Trades, quests and achievements for the celebration overlay.
  Stream<RewardEvent> get rewards => _rewards.stream;
  void _reward(RewardEvent e) {
    if (!_rewards.isClosed) _rewards.add(e);
  }

  // Insolvenz & Kreditsperre (5 echte Kalendertage = 120h)
  bool get isInsolvent => _isInsolvent || (_cash <= 0 && netWorth <= -10000);
  DateTime? get insolvencyLockoutUntil => _insolvencyLockoutUntil;
  DateTime? get lastLoanTakenAt => _lastLoanTakenAt;

  bool get isUnderCreditLockout {
    if (_insolvencyLockoutUntil == null) return false;
    return DateTime.now().isBefore(_insolvencyLockoutUntil!);
  }

  Duration get creditLockoutTimeRemaining {
    if (!isUnderCreditLockout || _insolvencyLockoutUntil == null) {
      return Duration.zero;
    }
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

  /// Clock for the bank's weekday rule; replaceable in tests.
  DateTime Function() bankClock = DateTime.now;

  /// Loans are only granted Monday to Friday.
  bool get isBankOpen => BankHours.isOpen(bankClock());

  bool get canTakeLoan {
    if (!isBankOpen) return false;
    if (_isInsolvent) return false;
    if (isUnderCreditLockout) return false;
    if (isLoanOnCooldown) return false;
    // Maximal 1 aktiver Bankkredit neben dem Startkredit
    final bankLoans = activeLoans
        .where((l) => !l.id.startsWith('initial_start_loan_'))
        .length;
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
  double get pendingOrderValue => pendingOrders.fold(0.0, (sum, order) {
    if (order.isBuy) return sum + order.totalEstimatedCost;
    final asset = _assets.where((a) => a.id == order.assetId).firstOrNull;
    final livePrice = asset?.currentPrice;
    final price = livePrice != null && livePrice.isFinite && livePrice > 0
        ? livePrice
        : order.estimatedPrice;
    if (order.leverage == 1 && !order.isShort) {
      return sum + order.amount * price;
    }
    final entryPrice = order.averageBuyPrice ?? order.estimatedPrice;
    final pnl = (price - entryPrice) * order.amount * (order.isShort ? -1 : 1);
    return sum +
        max(
          0.0,
          (order.collateral ?? order.amount * entryPrice / order.leverage) +
              pnl,
        );
  });

  double get netWorth =>
      _cash +
      totalPositionsValue +
      pendingOrderValue +
      totalLuxuryValue -
      totalDebt;

  CreditRating get creditRating {
    final lossRecords = _transactions.where((t) => (t.realizedPnL ?? 0) < 0);
    final totalLosses = lossRecords.fold<double>(
      0.0,
      (sum, t) => sum + (t.realizedPnL?.abs() ?? 0),
    );
    final liquidations = _transactions
        .where((t) => t.type == TransactionType.liquidation)
        .length;
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
      sum += pos.isLeveraged
          ? pos.collateral
          : (pos.amount * pos.averageBuyPrice);
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

  double get totalInvested => totalPositionsValue;
  double get unrealizedPnLPercent => totalUnrealizedPnLPercent;
  double get totalRealizedPnL =>
      _transactions.fold<double>(0.0, (sum, t) => sum + (t.realizedPnL ?? 0.0));

  // 50,000 cash minus the 25,000 initial loan is the player's starting equity.
  double get netProfit => netWorth - 25000.0;
  double get totalRoiPercent => netProfit / 25000.0;

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
    _leaderboardSubscription?.cancel();
    final stream = repository.streamLeaderboard();
    if (stream != null) {
      _leaderboardSubscription = stream.listen((entries) {
        if (entries.isNotEmpty) {
          _leaderboard = entries;
          notifyListeners();
        }
      });
    }
    _loans = await repository.getLoans();

    if (_loans.isEmpty) {
      final startLoan = Loan.createInitialStartLoan();
      _loans = [startLoan];
      await repository.saveLoans(_loans);
    }

    final insolvencyData = await repository.getInsolvencyStatus();
    _isInsolvent = insolvencyData['isInsolvent'] as bool? ?? false;
    if (insolvencyData['lockoutUntil'] != null) {
      _insolvencyLockoutUntil = DateTime.tryParse(
        insolvencyData['lockoutUntil'] as String,
      );
    }
    if (insolvencyData['lastLoanTakenAt'] != null) {
      _lastLoanTakenAt = DateTime.tryParse(
        insolvencyData['lastLoanTakenAt'] as String,
      );
    }

    // Starte Market Engine
    marketEngine.start(
      initialAssets: _assets,
      priceCallback: _onPriceUpdate,
      newsCallback: _onNewsGenerated,
    );

    // Fabricated news must not move prices supplied by market feeds.

    // Initialisiere Daily Quests
    await _initializeQuests();
    questService.recordTrade(
      tradeAmount: 0,
      isCommodity: false,
      leverage: 1,
      profit: 0,
      totalPositionsCount: _positions.length,
    );

    // Initialisiere Automation Service (Limit-Orders & Bot-Trading)
    await automationService.initialize();

    // Initialisiere Gamification Achievements
    await achievementService.initialize();
    achievementService.onAchievementUnlocked = (ach) {
      _cash += ach.cashReward;
      repository.saveCashBalance(_cash);
      _lastAlertMessage =
          '🏆 Trophäe freigeschaltet: "${ach.title}"! +${ach.cashReward.toStringAsFixed(0)} € & +${ach.prestigeReward} Prestige!';
      _reward(
        RewardEvent(
          kind: RewardKind.achievement,
          title: 'Erfolg freigeschaltet',
          detail: ach.title,
          cash: ach.cashReward,
          prestige: ach.prestigeReward,
        ),
      );
      notifyListeners();
    };

    // Initialisiere Sparpläne & Benutzereinstellungen
    final prefs = await SharedPreferences.getInstance();
    _isSimplisticMode = prefs.getBool(_keySimplisticMode) ?? false;
    _isRealisticOrderDelay = prefs.getBool(_keyRealisticOrderDelay) ?? true;
    await savingsPlanService.initialize();
    await netWorthHistory.load(_activeUid);

    // Initiales Update der Positionspreise, Leaderboard & Achievements
    _updatePositionsWithCurrentAssetPrices();
    _updateLeaderboard();
    _checkAllAchievements();

    // Echte Live-Börsenkurse im Hintergrund abrufen & Auth-Änderungen überwachen
    _listenToAuthChanges();
    _startLiveMarketRefresh();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _initializeQuests() async {
    final profileId = repository is LocalTradingRepository
        ? (repository as LocalTradingRepository).userId
        : (_activeUid == 'local_player' ? 'local' : _activeUid);
    await questService.initialize(profileId: profileId);
  }

  void _listenToAuthChanges() {
    _authSubscription?.cancel();
    try {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        fbUser,
      ) async {
        final newUid = fbUser?.uid ?? 'local_player';
        if (_activeUid != newUid) {
          _activeUid = newUid;
          await _onUserSwitched(fbUser);
        }
      });
    } catch (_) {}
  }

  int _accountVersion = 0;
  Future<void> _onUserSwitched(User? fbUser) async {
    final version = ++_accountVersion;
    _isLoading = true;
    notifyListeners();
    await _couponSettlement;
    if (version != _accountVersion) return;
    if (repository is FirebaseTradingRepository) {
      repository = FirebaseTradingRepository(
        userId: fbUser?.uid ?? 'local_player',
      );
    }
    final account = repository;
    try {
      // A new account starts from its own saved state, never the previous wallet.
      final cash = await account.getCashBalance();
      final positions = await account.getPositions();
      final transactions = await account.getTransactions();
      final luxury = await account.getLuxuryItems();
      final orders = await account.getPendingOrders();
      final loans = await account.getLoans();
      final insolvency = await account.getInsolvencyStatus();
      if (version != _accountVersion) return;
      _cash = cash;
      _positions = positions;
      _transactions = transactions;
      _luxuryItems = luxury;
      _pendingOrders = orders;
      _loans = loans.isEmpty ? [Loan.createInitialStartLoan()] : loans;
      if (loans.isEmpty) await account.saveLoans(_loans);
      if (version != _accountVersion) return;
      _isInsolvent = insolvency['isInsolvent'] as bool? ?? false;
      _insolvencyLockoutUntil = DateTime.tryParse(
        insolvency['lockoutUntil'] as String? ?? '',
      );
      _lastLoanTakenAt = _loans
          .where((loan) => !loan.id.startsWith('initial_start_loan_'))
          .map((loan) => loan.takenAt)
          .fold<DateTime?>(
            null,
            (latest, date) =>
                latest == null || date.isAfter(latest) ? date : latest,
          );
      await _initializeQuests();
      await netWorthHistory.load(_activeUid);
      if (version != _accountVersion) return;
      _updatePositionsWithCurrentAssetPrices();
    } catch (e) {
      debugPrint('Error on user switched: $e');
    } finally {
      if (version == _accountVersion) {
        _isLoading = false;
        _updateLeaderboard();
        notifyListeners();
      }
    }
  }

  void _startLiveMarketRefresh() {
    _liveMarketRefreshTimer?.cancel();
    fetchLiveMarketQuotes();
    _liveMarketRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _recordNetWorth();
      fetchLiveMarketQuotes();
    });
  }

  /// Holt echte Live-Kurse aus Binance & Yahoo / Cloud Function und aktualisiert Assets & Depot
  Future<void> fetchLiveMarketQuotes() async {
    if (_refreshingQuotes) return;
    _refreshingQuotes = true;
    try {
      final wanted = <String>{
        ..._visibleMarketAssetIds,
        ..._assets.where((a) => a.isWatchlisted).map((a) => a.id),
        ..._positions.map((p) => p.assetId),
        ...pendingOrders.map((p) => p.assetId),
      };
      // Dashboard starts with a small default page; never refresh the whole catalog.
      if (wanted.isEmpty) wanted.addAll(_assets.take(20).map((a) => a.id));
      final quotes = await liveDataService.refreshQuotesForAssets(
        _assets.where((a) => wanted.contains(a.id)).toList(),
      );
      if (quotes.isNotEmpty) {
        bool anyChanged = false;
        final updatedAssets = _assets.map((asset) {
          if (quotes.containsKey(asset.symbol)) {
            final q = quotes[asset.symbol]!;
            if (q.currentPrice.isFinite &&
                q.currentPrice > 0 &&
                q.previousClose.isFinite &&
                q.previousClose > 0) {
              if (q.sourceTimestamp == null) return asset;
              _quoteUpdatedAt[asset.id] = q.sourceTimestamp!;
              _quoteDetails[asset.id] = q;
              anyChanged = true;
              return asset.copyWith(
                currentPrice: q.currentPrice,
                previousClose: q.previousClose,
                dailyHigh: q.high ?? asset.dailyHigh,
                dailyLow: q.low ?? asset.dailyLow,
                priceHistory:
                    q.series?.where((v) => v.isFinite && v > 0).toList() ??
                    [q.currentPrice],
              );
            }
          }
          return asset;
        }).toList();

        if (anyChanged) {
          _assets = updatedAssets;
          marketEngine.updateAssetsReference(_assets);
          _updatePositionsWithCurrentAssetPrices();
          _checkAndExecutePendingOrders();
          _checkAndExecuteAutomationOrders();
          _updateLeaderboard();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('fetchLiveMarketQuotes error: $e');
    } finally {
      _refreshingQuotes = false;
    }
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
    if (_isLoading) return;
    _assets = updatedAssets;
    marketEngine.updateAssetsReference(_assets);

    _updatePositionsWithCurrentAssetPrices();
    _checkAndExecutePendingOrders();
    _checkAndExecuteAutomationOrders();
    _checkBondsCouponPayout();
    _updateLeaderboard();
    _checkAllAchievements();

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
        final newPrice = (asset.currentPrice * (1 + news.priceImpact)).clamp(
          0.0001,
          1000000.0,
        );
        final rounded = double.parse(
          newPrice.toStringAsFixed(newPrice > 500 ? 2 : 4),
        );
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

      final price = matchingAsset.currentPrice;
      final updatedPos = price.isFinite && price > 0
          ? pos.copyWith(currentPrice: price)
          : pos;

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

    _updateLeaderboard(forceCloud: true);
    _checkAllAchievements();
  }

  // --- TRADING LOGIK (KAUFEN / VERKAUFEN / VORAB-ORDER) ---

  /// Führt einen Sofort-Kauf aus (falls Markt offen) ODER legt eine Vorab-Order an (falls Markt geschlossen)
  Future<bool> executeBuy({
    required Asset asset,
    required double amount,
    double? cashFraction,
    int leverage = 1,
    bool isShort = false,
  }) async {
    if (_isLoading) return false;
    if (asset.type == AssetType.bond) {
      await _checkBondsCouponPayout(force: true);
    }
    final currentAsset = _assets.where((a) => a.id == asset.id).firstOrNull;
    if (currentAsset == null) return false;
    asset = currentAsset;
    if (cashFraction != null) {
      if (!cashFraction.isFinite || cashFraction <= 0 || cashFraction > 1) {
        return false;
      }
      amount = TradingFeeService.maximumBuyAmount(
        asset: asset,
        cash: _cash * cashFraction,
        leverage: leverage,
      );
    }
    if (!amount.isFinite ||
        amount <= 0 ||
        !asset.currentPrice.isFinite ||
        asset.currentPrice <= 0 ||
        leverage < 1 ||
        leverage > asset.maxLeverage) {
      _lastAlertMessage = 'Ungültige Order: Menge, Kurs oder Hebel prüfen.';
      notifyListeners();
      return false;
    }
    final isOpen = isAssetMarketOpen(asset);
    final breakdown = TradingFeeService.calculateBuyFee(
      asset: asset,
      amount: amount,
      leverage: leverage,
    );
    final totalCost = breakdown.totalCashRequired;
    final fee = breakdown.transactionFee;

    if (!totalCost.isFinite || totalCost > _cash) {
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
        collateral: breakdown.assetCost,
        averageBuyPrice: asset.currentPrice,
        executionReason: 'Wartet auf Börsenöffnung',
      );

      _pendingOrders.insert(0, pendingOrder);
      await repository.savePendingOrders(_pendingOrders);

      _lastAlertMessage =
          '🕒 Börse geschlossen: Vorab-Kauforder für ${asset.symbol} vorgemerkt! Wird automatisch bei Marktöffnung ausgeführt.';
      notifyListeners();
      return true;
    }

    // BÖRSE GEÖFFNET -> WENN REALISTISCHER MODUS AKTIV: 5-15 MINUTEN ROUTING DELAY
    if (_isRealisticOrderDelay) {
      _cash -= totalCost;
      await repository.saveCashBalance(_cash);

      String venue = 'Wiener Börse (WBAG)';
      final sym = asset.symbol.toUpperCase();
      if (sym.endsWith('.VI') ||
          sym == 'EBS' ||
          sym == 'OMV' ||
          sym == 'VOE' ||
          sym == 'ANDR') {
        venue = 'Wiener Börse (WBAG)';
      } else if (sym.endsWith('.DE') ||
          sym.endsWith('.AS') ||
          sym == 'BMW' ||
          sym == 'SAP' ||
          sym == 'ASML') {
        venue = 'Deutsche Börse XETRA';
      } else if (sym.contains('BTC') ||
          sym.contains('ETH') ||
          sym.contains('SOL') ||
          sym.contains('NEAR') ||
          sym.contains('LINK')) {
        venue = 'Crypto Liquidity Pool';
      } else if (sym.contains('=F')) {
        venue = 'CME Globex';
      } else {
        venue = 'NASDAQ / NYSE';
      }

      final delayMinutes = 5 + Random().nextInt(11); // 5 bis 15 Minuten
      final scheduledTime = DateTime.now().add(Duration(minutes: delayMinutes));

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
        collateral: breakdown.assetCost,
        averageBuyPrice: asset.currentPrice,
        scheduledExecutionTime: scheduledTime,
        executionReason: 'Im Orderbuch',
        brokerVenue: venue,
      );

      _pendingOrders.insert(0, pendingOrder);
      await repository.savePendingOrders(_pendingOrders);

      _lastAlertMessage =
          '📡 Kauforder an $venue übermittelt! Geschätzte Ausführung: in ~$delayMinutes Min.';
      notifyListeners();
      return true;
    }

    // BÖRSE GEÖFFNET (INSTANT MODUS) -> SOFORTIGE AUSFÜHRUNG
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
        final newAvgPrice =
            ((existing.amount * existing.averageBuyPrice) +
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
      note: leverage > 1
          ? '${leverage}x Hebel ${isShort ? "Short" : "Long"}'
          : 'Spot Kauf',
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

    _updateLeaderboard(forceCloud: true);
    _lastAlertMessage =
        'Erfolgreich gekauft: ${amount.toStringAsFixed(2)}x ${asset.symbol}';
    _reward(
      RewardEvent(
        kind: RewardKind.buy,
        title: 'Order ausgeführt',
        detail: '${_qty(amount)} × ${asset.symbol} gekauft',
        cash: -totalCost,
      ),
    );
    notifyListeners();
    return true;
  }

  /// Verkauft eine Position (teilweise oder ganz)
  Future<bool> executeSell({
    required Position position,
    required double sellAmount,
    double? sellFraction,
  }) async {
    if (_isLoading) return false;
    if (position.type == AssetType.bond) {
      await _checkBondsCouponPayout(force: true);
    }
    final owned = _positions.where((p) => p.id == position.id).firstOrNull;
    if (sellFraction != null) {
      if (!sellFraction.isFinite || sellFraction <= 0 || sellFraction > 1) {
        return false;
      }
      sellAmount = (owned?.amount ?? 0) * sellFraction;
    }
    if (owned == null ||
        !sellAmount.isFinite ||
        sellAmount <= 0 ||
        !owned.amount.isFinite ||
        sellAmount > owned.amount) {
      _lastAlertMessage =
          'Ungültige Verkaufsmenge oder Position nicht mehr verfügbar.';
      notifyListeners();
      return false;
    }
    position = owned;
    final matchingAssets = _assets.where(
      (a) => a.id == position.assetId || a.symbol == position.symbol,
    );
    if (matchingAssets.isEmpty) {
      _lastAlertMessage =
          'Asset ${position.symbol} nicht im Marktverzeichnis gefunden!';
      notifyListeners();
      return false;
    }
    final asset = matchingAssets.first;

    if (!asset.currentPrice.isFinite || asset.currentPrice <= 0) {
      _lastAlertMessage = 'Ungültiger Verkaufskurs.';
      notifyListeners();
      return false;
    }
    position = position.copyWith(currentPrice: asset.currentPrice);

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

    // WENN REALISTISCHER MODUS AKTIV: 5-15 MINUTEN BÖRSEN-ROUTING
    if (_isRealisticOrderDelay) {
      String venue = 'Wiener Börse (WBAG)';
      final sym = asset.symbol.toUpperCase();
      if (sym.endsWith('.VI') ||
          sym == 'EBS' ||
          sym == 'OMV' ||
          sym == 'VOE' ||
          sym == 'ANDR') {
        venue = 'Wiener Börse (WBAG)';
      } else if (sym.endsWith('.DE') ||
          sym.endsWith('.AS') ||
          sym == 'BMW' ||
          sym == 'SAP' ||
          sym == 'ASML') {
        venue = 'Deutsche Börse XETRA';
      } else if (sym.contains('BTC') ||
          sym.contains('ETH') ||
          sym.contains('SOL') ||
          sym.contains('NEAR')) {
        venue = 'Crypto Liquidity Pool';
      } else if (sym.contains('=F')) {
        venue = 'CME Globex';
      } else {
        venue = 'NASDAQ / NYSE';
      }

      final delayMinutes = 5 + Random().nextInt(11);
      final scheduledTime = DateTime.now().add(Duration(minutes: delayMinutes));

      // Reduziere Position temporär (Sperre für Verkauf)
      if (sellAmount >= position.amount) {
        _positions.removeWhere((p) => p.id == position.id);
      } else {
        final posIdx = _positions.indexWhere((p) => p.id == position.id);
        if (posIdx != -1) {
          final remainingAmount = position.amount - sellAmount;
          final remainingRatio = remainingAmount / position.amount;
          _positions[posIdx] = position.copyWith(
            amount: remainingAmount,
            collateral: position.isLeveraged
                ? (position.collateral * remainingRatio)
                : null,
          );
        }
      }
      await repository.savePositions(_positions);

      final ratio = sellAmount / position.amount;
      final pendingOrder = PendingOrder(
        id: _uuid.v4(),
        assetId: asset.id,
        symbol: asset.symbol,
        name: asset.name,
        assetType: asset.type,
        isBuy: false,
        amount: sellAmount,
        estimatedPrice: asset.currentPrice,
        totalEstimatedCost: sellAmount * asset.currentPrice,
        leverage: position.leverage,
        isShort: position.isShort,
        collateral: position.isLeveraged ? (position.collateral * ratio) : null,
        averageBuyPrice: position.averageBuyPrice,
        scheduledExecutionTime: scheduledTime,
        executionReason: 'Im Orderbuch',
        brokerVenue: venue,
      );

      _pendingOrders.insert(0, pendingOrder);
      await repository.savePendingOrders(_pendingOrders);

      _lastAlertMessage =
          '📡 Verkaufsorder an $venue übermittelt! Geschätzte Ausführung: in ~$delayMinutes Min.';
      notifyListeners();
      return true;
    }

    // Anteiliger PnL und Rückfluss (Instant Modus)
    final ratio = sellAmount / position.amount;
    double cashReturn = 0.0;
    double realizedPnL = 0.0;

    if (!position.isLeveraged) {
      cashReturn = sellAmount * asset.currentPrice;
      realizedPnL =
          (asset.currentPrice - position.averageBuyPrice) * sellAmount;
    } else {
      final portionCollateral = position.collateral * ratio;
      final portionPnL = position.unrealizedPnL * ratio;
      cashReturn = portionCollateral + portionPnL;
      if (cashReturn < 0) cashReturn = 0.0;
      realizedPnL = portionPnL;
    }

    _cash += cashReturn;

    if (sellAmount >= position.amount) {
      _positions.removeWhere((p) => p.id == position.id);
    } else {
      final remainingAmount = position.amount - sellAmount;
      final remainingRatio = remainingAmount / position.amount;
      final index = _positions.indexWhere((p) => p.id == position.id);
      if (index != -1) {
        _positions[index] = position.copyWith(
          amount: remainingAmount,
          currentPrice: asset.currentPrice,
          collateral: position.isLeveraged
              ? (position.collateral * remainingRatio)
              : null,
        );
      }
    }

    await repository.saveCashBalance(_cash);
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
      note:
          'Verkauf Realisiert: ${realizedPnL >= 0 ? "+" : ""}${realizedPnL.toStringAsFixed(2)} €',
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

    _updateLeaderboard(forceCloud: true);
    _lastAlertMessage =
        'Verkauft: ${sellAmount.toStringAsFixed(2)}x ${position.symbol} (Rendite: ${realizedPnL >= 0 ? "+" : ""}${realizedPnL.toStringAsFixed(2)} €)';
    _reward(
      RewardEvent(
        kind: realizedPnL >= 0 ? RewardKind.profit : RewardKind.loss,
        title: realizedPnL >= 0 ? 'Gewinn realisiert!' : 'Verlust realisiert',
        detail: '${_qty(sellAmount)} × ${position.symbol} verkauft',
        cash: realizedPnL,
      ),
    );
    notifyListeners();
    return true;
  }

  /// Prüft bei Marktöffnung und Ablauf der Ausführungszeit (5-15 Min.), ob anstehende Orders ausgeführt werden
  bool _executingPendingOrders = false;
  Future<void> _checkAndExecutePendingOrders() async {
    if (_isLoading || _executingPendingOrders) return;
    _executingPendingOrders = true;
    try {
      bool changes = false;
      final now = DateTime.now();

      for (final order in _pendingOrders) {
        if (order.status != PendingOrderStatus.pending) continue;

        final matchingAssets = _assets.where(
          (a) => a.id == order.assetId || a.symbol == order.symbol,
        );
        if (matchingAssets.isEmpty) continue;
        final matchingAsset = matchingAssets.first;

        if (!matchingAsset.currentPrice.isFinite ||
            matchingAsset.currentPrice <= 0) {
          continue;
        }

        // Börsenöffnungszeiten prüfen
        if (!isAssetMarketOpen(matchingAsset)) continue;

        // Realistische Verzögerung prüfen (5-15 Minuten)
        if (order.scheduledExecutionTime != null &&
            now.isBefore(order.scheduledExecutionTime!)) {
          continue;
        }

        if (matchingAsset.type == AssetType.bond && order.isBuy) {
          await _checkBondsCouponPayout(force: true);
          if (order.status != PendingOrderStatus.pending) continue;
        }
        final fillAmount = order.isBuy
            ? TradingFeeService.maximumBuyAmount(
                asset: matchingAsset,
                cash: order.totalEstimatedCost,
                leverage: order.leverage,
              )
            : order.amount;
        if (!fillAmount.isFinite || fillAmount <= 0) continue;
        // Pending purchases execute the reserved budget at the execution quote.
        order.amount = fillAmount;
        // Order ausführen
        order.status = PendingOrderStatus.executed;
        order.executedAt = now;
        order.executedPrice = matchingAsset.currentPrice;
        changes = true;

        if (order.isBuy) {
          // Kauf-Order abwickeln
          final buyPrice = matchingAsset.currentPrice;
          if (order.leverage == 1 && !order.isShort) {
            final existingIndex = _positions.indexWhere(
              (p) =>
                  p.assetId == matchingAsset.id && !p.isLeveraged && !p.isShort,
            );
            if (existingIndex != -1) {
              final existing = _positions[existingIndex];
              final newTotalAmount = existing.amount + order.amount;
              final newAvgPrice =
                  ((existing.amount * existing.averageBuyPrice) +
                      (order.amount * buyPrice)) /
                  newTotalAmount;
              _positions[existingIndex] = existing.copyWith(
                amount: newTotalAmount,
                averageBuyPrice: newAvgPrice,
                currentPrice: matchingAsset.currentPrice,
              );
            } else {
              _positions.add(
                Position(
                  id: _uuid.v4(),
                  assetId: matchingAsset.id,
                  symbol: matchingAsset.symbol,
                  name: matchingAsset.name,
                  type: matchingAsset.type,
                  amount: order.amount,
                  averageBuyPrice: buyPrice,
                  currentPrice: matchingAsset.currentPrice,
                  leverage: 1,
                  isShort: false,
                ),
              );
            }
          } else {
            final effectiveCollateral =
                (order.amount * buyPrice) / order.leverage;
            _positions.add(
              Position(
                id: _uuid.v4(),
                assetId: matchingAsset.id,
                symbol: matchingAsset.symbol,
                name: matchingAsset.name,
                type: matchingAsset.type,
                amount: order.amount,
                averageBuyPrice: buyPrice,
                currentPrice: matchingAsset.currentPrice,
                leverage: order.leverage,
                isShort: order.isShort,
                collateral: effectiveCollateral,
              ),
            );
          }

          final record = TransactionRecord(
            id: _uuid.v4(),
            symbol: matchingAsset.symbol,
            name: matchingAsset.name,
            type: TransactionType.buy,
            amount: order.amount,
            price: matchingAsset.currentPrice,
            totalAmount: order.totalEstimatedCost,
            timestamp: now,
            note:
                'Börsen-Kauf ausgeführt (${order.brokerVenue ?? "Orderbuch"})',
          );
          _transactions.insert(0, record);
          repository.saveTransaction(record);

          // Orders executed later count for the daily quests as well.
          questService.recordTrade(
            tradeAmount: order.totalEstimatedCost,
            isCommodity: matchingAsset.type == AssetType.commodity,
            leverage: order.leverage,
            profit: 0,
            totalPositionsCount: _positions.length,
          );

          _lastAlertMessage =
              '✅ KAUF AUSGEFÜHRT: ${order.amount.toStringAsFixed(2)}x ${matchingAsset.symbol} @ ${matchingAsset.currentPrice.toStringAsFixed(2)} € eingebucht!';
          _reward(
            RewardEvent(
              kind: RewardKind.orderExecuted,
              title: 'Kauf-Order ausgeführt',
              detail:
                  '${_qty(order.amount)} × ${matchingAsset.symbol} @ ${matchingAsset.currentPrice.toStringAsFixed(2)} €',
              cash: -order.totalEstimatedCost,
            ),
          );
        } else {
          // Verkaufs-Order abwickeln
          double cashReturn = 0.0;
          double realizedPnL = 0.0;

          if (order.leverage > 1 || order.isShort) {
            final effLeverage = order.leverage > 1 ? order.leverage : 1;
            final portionCollateral =
                order.collateral ??
                ((order.amount *
                        (order.averageBuyPrice ?? order.estimatedPrice)) /
                    effLeverage);
            final currentVal = order.amount * matchingAsset.currentPrice;
            final entryVal =
                order.amount * (order.averageBuyPrice ?? order.estimatedPrice);
            final portionPnL = order.isShort
                ? (entryVal - currentVal)
                : (currentVal - entryVal);
            cashReturn = (portionCollateral + portionPnL).clamp(
              0.0,
              double.infinity,
            );
            realizedPnL = portionPnL;
          } else {
            cashReturn = order.amount * matchingAsset.currentPrice;
            realizedPnL =
                (matchingAsset.currentPrice -
                    (order.averageBuyPrice ?? order.estimatedPrice)) *
                order.amount;
          }

          _cash += cashReturn;
          repository.saveCashBalance(_cash);

          final record = TransactionRecord(
            id: _uuid.v4(),
            symbol: matchingAsset.symbol,
            name: matchingAsset.name,
            type: TransactionType.sell,
            amount: order.amount,
            price: matchingAsset.currentPrice,
            totalAmount: cashReturn,
            realizedPnL: realizedPnL,
            timestamp: now,
            note:
                'Börsen-Verkauf ausgeführt (${order.brokerVenue ?? "Orderbuch"})',
          );
          _transactions.insert(0, record);
          repository.saveTransaction(record);

          questService.recordTrade(
            tradeAmount: cashReturn,
            isCommodity: matchingAsset.type == AssetType.commodity,
            leverage: order.leverage,
            profit: realizedPnL,
            totalPositionsCount: _positions.length,
          );

          _lastAlertMessage =
              '✅ VERKAUF AUSGEFÜHRT: ${order.amount.toStringAsFixed(2)}x ${matchingAsset.symbol} für ${cashReturn.toStringAsFixed(2)} € abgerechnet!';
          _reward(
            RewardEvent(
              kind: RewardKind.orderExecuted,
              title: 'Verkaufs-Order ausgeführt',
              detail:
                  '${_qty(order.amount)} × ${matchingAsset.symbol} für ${cashReturn.toStringAsFixed(2)} €',
              cash: realizedPnL,
            ),
          );
        }
      }

      if (changes) {
        repository.savePendingOrders(_pendingOrders);
        repository.savePositions(_positions);
        _checkAllAchievements();
        _updateLeaderboard(forceCloud: true);
        notifyListeners();
      }

      _checkSavingsPlans();
    } finally {
      _executingPendingOrders = false;
    }
  }

  /// Führt fällige Sparpläne automatisch aus
  Future<void> _checkSavingsPlans() async {
    final due = savingsPlanService.getDuePlans();
    for (final plan in due) {
      final matchingAssets = _assets.where((a) => a.symbol == plan.assetSymbol);
      if (matchingAssets.isEmpty) continue;
      final asset = matchingAssets.first;
      if (asset.type == AssetType.bond) {
        await _checkBondsCouponPayout(force: true);
      }
      if (_cash >= plan.amountEur && asset.currentPrice > 0) {
        final shares = plan.amountEur / asset.currentPrice;
        _cash -= plan.amountEur;
        await repository.saveCashBalance(_cash);

        final existingIndex = _positions.indexWhere(
          (p) => p.symbol == asset.symbol && !p.isLeveraged && !p.isShort,
        );
        if (existingIndex != -1) {
          final existing = _positions[existingIndex];
          final newTotalAmount = existing.amount + shares;
          final newAvgPrice =
              ((existing.amount * existing.averageBuyPrice) +
                  (shares * asset.currentPrice)) /
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
              amount: shares,
              averageBuyPrice: asset.currentPrice,
              currentPrice: asset.currentPrice,
              leverage: 1,
              isShort: false,
            ),
          );
        }
        await repository.savePositions(_positions);

        final record = TransactionRecord(
          id: _uuid.v4(),
          symbol: asset.symbol,
          name: asset.name,
          type: TransactionType.buy,
          amount: shares,
          price: asset.currentPrice,
          totalAmount: plan.amountEur,
          timestamp: DateTime.now(),
          note: 'Automatischer Sparplan (${plan.frequency.displayName})',
        );
        _transactions.insert(0, record);
        await repository.saveTransaction(record);
        await savingsPlanService.markExecuted(plan.id, plan.amountEur);
        _lastAlertMessage =
            '🏦 Sparplan ausgeführt: ${plan.amountEur.toStringAsFixed(2)} € in ${plan.assetSymbol} investiert!';
        notifyListeners();
      }
    }
  }

  /// Storniert eine noch nicht ausgeführte Order und erstattet Barmittel oder Depotbestand
  Future<void> cancelPendingOrder(PendingOrder order) async {
    if (order.status != PendingOrderStatus.pending) return;

    if (!order.isBuy && order.assetType == AssetType.bond) {
      await _checkBondsCouponPayout(force: true);
      if (order.status != PendingOrderStatus.pending) return;
    }
    order.status = PendingOrderStatus.cancelled;
    if (order.isBuy) {
      _cash += order.totalEstimatedCost; // Geld zurückerstatten
      await repository.saveCashBalance(_cash);
    } else {
      // Verkaufsmenge zurück in Depotposition einbuchen
      final idx = _positions.indexWhere(
        (p) =>
            (p.assetId == order.assetId || p.symbol == order.symbol) &&
            p.leverage == order.leverage &&
            p.isShort == order.isShort,
      );
      if (idx != -1) {
        _positions[idx] = _positions[idx].copyWith(
          amount: _positions[idx].amount + order.amount,
          collateral: order.collateral != null
              ? (_positions[idx].collateral + order.collateral!)
              : _positions[idx].collateral,
        );
      } else {
        _positions.add(
          Position(
            id: _uuid.v4(),
            assetId: order.assetId,
            symbol: order.symbol,
            name: order.name,
            type: order.assetType,
            amount: order.amount,
            averageBuyPrice: order.averageBuyPrice ?? order.estimatedPrice,
            currentPrice: order.estimatedPrice,
            leverage: order.leverage,
            isShort: order.isShort,
            collateral: order.collateral ?? 0.0,
          ),
        );
      }
      await repository.savePositions(_positions);
    }
    await repository.savePendingOrders(_pendingOrders);
    _updateLeaderboard(forceCloud: true);

    _lastAlertMessage = 'Order für ${order.symbol} storniert.';
    notifyListeners();
  }

  /// Generiert einen offiziellen Bank-Depotauszug als formatierten Text / Export
  String generateDepotStatement() {
    final buffer = StringBuffer();
    final now = DateTime.now();
    buffer.writeln('====================================================');
    buffer.writeln('           TRADING GAME – DEPOTAUSZUG               ');
    buffer.writeln('====================================================');
    buffer.writeln(
      'Erstellungsdatum: ${now.toIso8601String().substring(0, 16)}',
    );
    buffer.writeln('Depot-Inhaber:    Aktiver Händler');
    buffer.writeln('Währung:          EUR (€)');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('FINANZSTATUS:');
    buffer.writeln('Depotgesamtwert:  ${netWorth.toStringAsFixed(2)} €');
    buffer.writeln('Freies Barmittel: ${_cash.toStringAsFixed(2)} €');
    buffer.writeln('Positionswert:    ${totalInvested.toStringAsFixed(2)} €');
    buffer.writeln('Kreditbestand:    ${totalDebt.toStringAsFixed(2)} €');
    buffer.writeln(
      'Realisierte G/V:  ${totalRealizedPnL.toStringAsFixed(2)} €',
    );
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('DEPOTBESTAND:');
    if (_positions.isEmpty) {
      buffer.writeln('Keine offenen Wertpapierpositionen.');
    } else {
      for (final p in _positions) {
        buffer.writeln(
          '- ${p.symbol} (${p.name}): ${p.amount} Stk. @ ${p.averageBuyPrice.toStringAsFixed(2)} € (Wert: ${(p.amount * p.currentPrice).toStringAsFixed(2)} €)',
        );
      }
    }
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('LETZTE TRANSAKTIONEN:');
    final recent = _transactions.take(15);
    if (recent.isEmpty) {
      buffer.writeln('Keine Transaktionen verbucht.');
    } else {
      for (final t in recent) {
        buffer.writeln(
          '[${t.timestamp.toIso8601String().substring(0, 10)}] ${t.type.displayName.toUpperCase()}: ${t.amount}x ${t.symbol} @ ${t.price.toStringAsFixed(2)} € = ${t.totalAmount.toStringAsFixed(2)} €',
        );
      }
    }
    buffer.writeln('====================================================');
    buffer.writeln('Elektronischer Kontoauszug – Trading Game Core API');
    buffer.writeln('====================================================');
    return buffer.toString();
  }

  // --- ANLEIHEN KUPON-AUSSCHÜTTUNG ---
  Future<void> _couponSettlement = Future<void>.value();

  Future<void> _checkBondsCouponPayout({bool force = false}) {
    // Serialize tick and trade settlements so they cannot credit the same span.
    final settlement = _couponSettlement.then((_) => _settleBondCoupons(force));
    _couponSettlement = settlement.catchError((Object error) {
      debugPrint('Kupon-Abrechnung fehlgeschlagen: $error');
    });
    return settlement;
  }

  Future<void> _settleBondCoupons(bool force) async {
    final profileId = repository is LocalTradingRepository
        ? (repository as LocalTradingRepository).userId
        : _activeUid;
    final prefs = await SharedPreferences.getInstance();
    final currentProfileId = repository is LocalTradingRepository
        ? (repository as LocalTradingRepository).userId
        : _activeUid;
    if (_isLoading || profileId != currentProfileId) return;
    final now = DateTime.now();
    double totalCouponPaid = 0;
    for (final pos in List<Position>.of(_positions)) {
      if (pos.type != AssetType.bond || pos.isLeveraged || pos.isShort) {
        continue;
      }
      final asset = _assets.where((a) => a.id == pos.assetId).firstOrNull;
      if (asset == null) continue;
      final key =
          'tg_coupon_cursor_${Uri.encodeComponent(profileId)}_${pos.id}';
      final savedThrough = DateTime.tryParse(prefs.getString(key) ?? '');
      var paidThrough = savedThrough ?? pos.openedAt;
      if (savedThrough == null) {
        // Preserve the last pre-migration payout without relying on history later.
        for (final transaction in _transactions) {
          if (transaction.type == TransactionType.couponPayout &&
              transaction.symbol == pos.symbol &&
              transaction.timestamp.isAfter(paidThrough)) {
            paidThrough = transaction.timestamp;
          }
        }
      }
      final rate = asset.couponRate ?? 0.035;
      final payout = BondCouponService.accrued(
        position: pos,
        annualRate: rate,
        paidThrough: paidThrough,
        now: now,
      );
      // Keep sub-cent interest accrued until payout or a holding change.
      if (!force && payout < 0.01) continue;
      if (now.isBefore(paidThrough)) continue;
      await prefs.setString(key, now.toIso8601String());
      if (payout <= 0) continue;
      _cash += payout;
      totalCouponPaid += payout;
      final record = TransactionRecord(
        id: _uuid.v4(),
        symbol: pos.symbol,
        name: pos.name,
        type: TransactionType.couponPayout,
        amount: 1,
        price: payout,
        totalAmount: payout,
        timestamp: now,
        note: 'Zinskupon ${(rate * 100).toStringAsFixed(1)}% p.a. [${pos.id}]',
      );
      _transactions.insert(0, record);
      await repository.saveCashBalance(_cash);
      await repository.saveTransaction(record);
    }
    if (totalCouponPaid > 0) {
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

    _lastAlertMessage =
        '🎉 Glückwunsch! Du hast ${item.name} erworben. Dein Prestige steigt!';
    _reward(
      RewardEvent(
        kind: RewardKind.purchase,
        title: 'Neuer Besitz!',
        detail: item.name,
        prestige: item.prestigePoints,
      ),
    );
    _updateLeaderboard(forceCloud: true);
    notifyListeners();
    return true;
  }

  // --- KREDIT & SCHULDEN SYSTEM ---
  Future<void> declareInsolvency() async {
    _isInsolvent = true;
    _insolvencyLockoutUntil = DateTime.now().add(
      const Duration(days: 5),
    ); // 5 echte Tage = 120h

    // Notverkauf aller Positionen
    for (final pos in List<Position>.from(_positions)) {
      final recoveryCash = pos.currentValue * 0.8;
      _cash += recoveryCash;
    }
    _positions.clear();
    await repository.savePositions(_positions);

    // Storniere offene Pending Orders & Trading-Bot Orders
    for (final order in _pendingOrders) {
      if (order.status == PendingOrderStatus.pending) {
        order.status = PendingOrderStatus.cancelled;
        if (order.isBuy) {
          _cash += order.totalEstimatedCost;
        }
      }
    }
    await repository.savePendingOrders(_pendingOrders);

    for (final botOrder in List.from(automationService.activeOrders)) {
      await automationService.cancelOrder(botOrder.id);
    }

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

    _lastAlertMessage =
        '🚨 PRIVATINSOLVENZ ANGEMELDET! 5 Tage Kreditsperre aktiv.';
    _updateLeaderboard(forceCloud: true);
    notifyListeners();
  }

  Future<bool> takeLoan({
    required double principal,
    required int durationDays,
  }) async {
    if (!principal.isFinite ||
        principal <= 0 ||
        durationDays <= 0 ||
        durationDays > 365) {
      _lastAlertMessage = 'Kreditbetrag und Laufzeit sind ungültig.';
      notifyListeners();
      return false;
    }
    if (!isBankOpen) {
      _lastAlertMessage = BankHours.closedMessage;
      notifyListeners();
      return false;
    }
    // Erste Kreditaufnahme ist bankenseitig auf maximal 25.000 € gedeckelt
    final previousBankLoans = _transactions.where(
      (t) => t.type == TransactionType.loanPayout,
    );
    if (previousBankLoans.isEmpty && principal > 25000.0) {
      _lastAlertMessage =
          '⚠️ Der erste Bankkredit ist bankenseitig auf maximal 25.000 € begrenzt!';
      notifyListeners();
      return false;
    }

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
        _lastAlertMessage =
            '⚠️ Du hast bereits einen aktiven Bankkredit! Tilge diesen zuerst ab.';
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
      note:
          '${principal.toStringAsFixed(0)} € zu ${(rating.baseInterestRate * 100).toStringAsFixed(1)}% p.a. ($durationDays Tage)',
    );

    _transactions.insert(0, record);
    await repository.saveTransaction(record);

    _lastAlertMessage =
        '💳 Kredit über ${principal.toStringAsFixed(0)} € ausgezahlt! Zinssatz: ${(rating.baseInterestRate * 100).toStringAsFixed(1)}% p.a.';
    _updateLeaderboard(forceCloud: true);
    _checkAllAchievements();
    notifyListeners();
    return true;
  }

  bool get _recoveryLoanReady =>
      _isInsolvent &&
      _insolvencyLockoutUntil != null &&
      !isUnderCreditLockout &&
      !isLoanOnCooldown &&
      !activeLoans.any((l) => l.id.startsWith('sanierung_loan_'));

  bool get canTakeRecoveryLoan => _recoveryLoanReady && isBankOpen;

  /// Everything is in place except the weekday: the UI says "from Monday".
  bool get recoveryLoanWaitsForBank => _recoveryLoanReady && !isBankOpen;

  /// Einmaliger Neustart nach Ablauf der Insolvenz-Kreditsperre.
  Future<bool> takeSanierungsKredit() async {
    if (recoveryLoanWaitsForBank) {
      _lastAlertMessage = BankHours.closedMessage;
      notifyListeners();
      return false;
    }
    if (!canTakeRecoveryLoan) {
      _lastAlertMessage =
          'Sanierungskredit erst nach Insolvenz und Ablauf der Kreditsperre verfügbar.';
      notifyListeners();
      return false;
    }
    final loan = Loan.createSanierungsLoan();
    _cash += loan.principal;
    _loans.insert(0, loan);
    _isInsolvent = false;
    _insolvencyLockoutUntil = null; // Kreditsperre sofort aufheben!
    _lastLoanTakenAt = DateTime.now();

    await repository.saveCashBalance(_cash);
    await repository.saveLoans(_loans);
    await repository.saveInsolvencyStatus(
      isInsolvent: false,
      lockoutUntil: null,
      lastLoanTakenAt: _lastLoanTakenAt,
    );

    final record = TransactionRecord(
      id: _uuid.v4(),
      symbol: '🤝',
      name: 'Bank Notfall-Sanierungskredit erhalten',
      type: TransactionType.loanPayout,
      amount: 1,
      price: loan.principal,
      totalAmount: loan.principal,
      timestamp: DateTime.now(),
      note:
          '10.000 € Sanierungskredit (12% p.a., 90 Tage) – Sofortiger Neustart nach Insolvenz!',
    );

    _transactions.insert(0, record);
    await repository.saveTransaction(record);

    _lastAlertMessage =
        '🤝 Rettungsschirm aktiviert! Die Bank gewährt dir einen 10.000 € Sanierungskredit zum Weiterspielen!';
    _updateLeaderboard(forceCloud: true);
    _checkAllAchievements();
    notifyListeners();
    return true;
  }

  Future<bool> repayLoan(Loan loan, double amount) async {
    if (!amount.isFinite ||
        amount <= 0 ||
        loan.isPaid ||
        !_loans.any((l) => identical(l, loan))) {
      return false;
    }
    final actualRepay = amount > loan.remainingDebt
        ? loan.remainingDebt
        : amount;
    if (actualRepay <= 0) return false;

    if (_cash < actualRepay) {
      _lastAlertMessage = 'Nicht genügend Barmittel für diese Kredittilgung!';
      notifyListeners();
      return false;
    }

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
      note:
          'Tilgung: -${actualRepay.toStringAsFixed(2)} € (Restschuld: ${loan.remainingDebt.toStringAsFixed(2)} €)',
    );

    _transactions.insert(0, record);
    await repository.saveTransaction(record);

    _lastAlertMessage = loan.isPaid
        ? '🎉 Bravo! Kredit "${loan.title}" vollständig zurückgezahlt!'
        : 'Kreditrate über ${actualRepay.toStringAsFixed(2)} € erfolgreich geleistet.';
    _updateLeaderboard(forceCloud: true);
    notifyListeners();
    return true;
  }

  // --- LEADERBOARD SYNCHRONISATION ---
  void _updateLeaderboard({bool forceCloud = false}) {
    if (_isLoading) return;
    _recordNetWorth();
    final luxuryCount = _luxuryItems.fold<int>(
      0,
      (sum, i) => sum + i.ownedCount,
    );

    String myUid = 'player_user';
    String myName = 'Börsen-Profi';
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null && fbUser.uid.isNotEmpty) {
        myUid = fbUser.uid;
        if (fbUser.displayName != null &&
            fbUser.displayName!.trim().isNotEmpty) {
          myName = fbUser.displayName!.trim();
        } else if (fbUser.email != null && fbUser.email!.isNotEmpty) {
          myName = fbUser.email!.split('@').first;
        } else {
          myName = 'Trader ${fbUser.uid.substring(0, 5)}';
        }
      }
    } catch (_) {}

    if (_playerProfile?.uid == myUid) myName = _playerProfile!.displayName;

    // Only signed-in players with a chosen name are ranked; guests and
    // unnamed accounts never appear on (or are written to) the leaderboard.
    var listed = false;
    try {
      final u = FirebaseAuth.instance.currentUser;
      listed = u != null && !u.isAnonymous && _playerProfile?.uid == u.uid;
    } catch (_) {}
    _isOnLeaderboard = listed;
    if (!listed) {
      _leaderboard.removeWhere((e) => e.isPlayer || e.id == myUid);
      return;
    }

    final playerEntry = LeaderboardEntry(
      id: myUid,
      name: 'Du ($myName)',
      city: _playerProfile?.uid == myUid ? playerCountry : 'Land nicht gewählt',
      title: currentRank.title,
      badge: currentRank.badge,
      avatarEmoji: '😎',
      strategy: positions.isEmpty
          ? 'Cash & Multi-Asset'
          : '${positions.first.symbol} & Momentum',
      netWorth: netWorth,
      roiPercent: totalRoiPercent * 100,
      isPlayer: true,
      luxuryCount: luxuryCount,
    );

    final playerEntryIndex = _leaderboard.indexWhere(
      (e) => e.isPlayer || e.id == myUid,
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

    repository.saveLeaderboard(_leaderboard, forceCloud: forceCloud);
  }

  Future<void> reloadLeaderboard() async {
    _leaderboard = await repository.getLeaderboard();
    _updateLeaderboard(forceCloud: true);
    notifyListeners();
  }

  // --- 1. DAILY QUESTS & REWARDS ---
  void claimDailyQuest(String questId) {
    questService.claimQuest(questId, (cashReward, prestigeReward) {
      _cash += cashReward;
      repository.saveCashBalance(_cash);
      _lastAlertMessage =
          '🎁 Belohnung abgeholt: +${cashReward.toStringAsFixed(0)} € & +$prestigeReward Prestige!';
      _reward(
        RewardEvent(
          kind: RewardKind.quest,
          title: 'Belohnung abgeholt',
          detail: 'Tägliche Aufgabe erledigt',
          cash: cashReward.toDouble(),
          prestige: prestigeReward,
        ),
      );
      _updateLeaderboard(forceCloud: true);
      notifyListeners();
    });
  }

  // --- 2. SOCIAL TRADING & COPY-TRADING ---
  Future<bool> copyTrader(CopyTrader trader, double allocatedAmount) async {
    if (!allocatedAmount.isFinite || !copyTraders.contains(trader)) {
      return false;
    }
    if (_cash < allocatedAmount || allocatedAmount < 500) return false;

    _cash -= allocatedAmount;
    await repository.saveCashBalance(_cash);

    for (final entry in trader.portfolioAllocation.entries) {
      final symbol = entry.key;
      final weight = entry.value;
      final sliceAmount = allocatedAmount * weight;

      final matchingAssets = _assets.where((a) => a.symbol == symbol);
      if (matchingAssets.isEmpty) continue;
      final asset = matchingAssets.first;

      final shares = sliceAmount / asset.currentPrice;

      final existingIndex = _positions.indexWhere(
        (p) => p.symbol == asset.symbol && !p.isLeveraged,
      );
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
        _positions.add(
          Position(
            id: _uuid.v4(),
            assetId: asset.id,
            symbol: asset.symbol,
            name: asset.name,
            type: asset.type,
            amount: shares,
            averageBuyPrice: asset.currentPrice,
            currentPrice: asset.currentPrice,
            openedAt: DateTime.now(),
          ),
        );
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
    _lastAlertMessage =
        '🤝 Du kopierst jetzt ${trader.name} mit ${allocatedAmount.toStringAsFixed(0)} €!';
    _updateLeaderboard(forceCloud: true);
    notifyListeners();
    return true;
  }

  // --- 4. DIVIDENDEN & PASSIVES EINKOMMEN ---
  bool get canClaimMonthlyDividends {
    final now = DateTime.now();
    return monthlyPassiveIncome > 0 &&
        !_transactions.any(
          (t) =>
              t.type == TransactionType.dividendPayout &&
              t.timestamp.year == now.year &&
              t.timestamp.month == now.month,
        );
  }

  void payoutSimulatedDividends() {
    if (!canClaimMonthlyDividends) return;
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
    _lastAlertMessage =
        '💵 Dividenden gutgeschrieben: +${payout.toStringAsFixed(2)} €!';
    _updateLeaderboard(forceCloud: true);
    notifyListeners();
  }

  // --- 5. WATCHLIST MANAGEMENT ---
  void toggleWatchlist(Asset asset) {
    asset.isWatchlisted = !asset.isWatchlisted;
    repository.saveAssets(_assets);
    notifyListeners();
  }

  // --- 6. LIMIT-ORDER & BOT-AUTOMATISIERUNG ---
  Future<bool> unlockAutomationSlot() async {
    final success = await automationService.unlockNextSlot(_cash, (cost) {
      _cash -= cost;
      repository.saveCashBalance(_cash);

      final record = TransactionRecord(
        id: _uuid.v4(),
        symbol: 'BOT',
        name: 'Trading-Bot Slot freigeschaltet',
        type: TransactionType.luxuryPurchase,
        amount: 1,
        price: cost,
        totalAmount: cost,
        timestamp: DateTime.now(),
        note: 'Freischaltung Slot ${automationService.unlockedSlotsCount}',
      );
      _transactions.insert(0, record);
      repository.saveTransaction(record);
    });

    if (success) {
      _lastAlertMessage =
          '🤖 Neuer Trading-Bot Slot freigeschaltet! Mehr Automatisierung aktiv.';
      _checkAllAchievements();
      notifyListeners();
    }
    return success;
  }

  Future<AutomationOrder?> placeAutomationOrder({
    required Asset asset,
    required AutomationOrderType orderType,
    required double targetPrice,
    required double amount,
  }) async {
    final order = await automationService.placeOrder(
      assetId: asset.id,
      symbol: asset.symbol,
      name: asset.name,
      orderType: orderType,
      targetPrice: targetPrice,
      amount: amount,
    );

    if (order != null) {
      _lastAlertMessage =
          '🤖 Limit-Order vorgemerkt: ${orderType.displayName} für ${asset.symbol} @ ${targetPrice.toStringAsFixed(2)} €';
    } else {
      _lastAlertMessage =
          '⚠️ Kein freier Bot-Slot verfügbar! Schalte weitere Slots frei.';
    }

    notifyListeners();
    return order;
  }

  Future<bool> cancelAutomationOrder(String orderId) async {
    final success = await automationService.cancelOrder(orderId);
    if (success) {
      _lastAlertMessage = 'Limit-Order storniert.';
      notifyListeners();
    }
    return success;
  }

  Future<void> _checkAndExecuteAutomationOrders() async {
    await automationService.checkAndExecuteOrders(
      assets: _assets,
      onExecute: (order, asset) async {
        if (order.orderType == AutomationOrderType.buyLimit) {
          final success = await executeBuy(asset: asset, amount: order.amount);
          if (success) {
            _lastAlertMessage =
                '🤖 Bot Limit-Kauf ausgeführt: ${order.amount}x ${order.symbol} @ ${asset.currentPrice.toStringAsFixed(2)} €';
          }
        } else {
          // Take-Profit oder Stop-Loss
          final matchingPositions = _positions.where(
            (p) => p.assetId == asset.id || p.symbol == asset.symbol,
          );
          if (matchingPositions.isNotEmpty) {
            final pos = matchingPositions.first;
            final sellAmt = order.amount > pos.amount
                ? pos.amount
                : order.amount;
            final success = await executeSell(
              position: pos,
              sellAmount: sellAmt,
            );
            if (success) {
              _lastAlertMessage =
                  '🤖 Bot Limit-Verkauf (${order.orderType == AutomationOrderType.takeProfit ? "Take-Profit" : "Stop-Loss"}) ausgeführt: ${sellAmt}x ${order.symbol} @ ${asset.currentPrice.toStringAsFixed(2)} €';
            }
          }
        }
        _checkAllAchievements();
        notifyListeners();
      },
    );
  }

  // --- 7. GAMIFICATION & ACHIEVEMENTS EVALUATION ---
  void _checkAllAchievements() {
    final playerEntry = _leaderboard.where((e) => e.isPlayer).firstOrNull;
    final hasCompetitors = _leaderboard.any((e) => !e.isPlayer);
    final playerRank = hasCompetitors ? (playerEntry?.rank ?? 0) : 0;
    final totalTrades = _transactions
        .where(
          (t) =>
              t.type == TransactionType.buy || t.type == TransactionType.sell,
        )
        .length;
    final winningStreak = _calculateWinningStreak();
    final hasWonLeveraged = _transactions.any(
      (t) =>
          (t.note?.contains('Hebel') == true ||
              t.note?.contains('CFD') == true) &&
          (t.realizedPnL ?? 0) > 0,
    );
    final hasSanierungSettled = _loans.any(
      (l) => l.id.startsWith('sanierung_loan_') && l.isPaid,
    );
    final hasBotTriggered = automationService.allOrders.any(
      (o) => o.isTriggered,
    );
    final hasOffMarketCrypto = _transactions.any(
      (t) =>
          (t.symbol.contains('BTC') ||
              t.symbol.contains('ETH') ||
              t.symbol.contains('SOL')) &&
          (t.timestamp.hour < 9 ||
              t.timestamp.hour >= 17 ||
              t.timestamp.weekday >= 6),
    );

    achievementService.checkAchievements(
      netWorth: netWorth,
      totalTradesCount: totalTrades,
      winningStreakCount: winningStreak,
      totalPrestigePoints: totalPrestigePoints,
      monthlyPassiveIncome: monthlyPassiveIncome,
      hasDebt: totalDebt > 0,
      ownedLuxuryCount: _luxuryItems.fold(0, (sum, i) => sum + i.ownedCount),
      hasCopyTrade: _transactions.any(
        (t) => t.note?.contains('Kopiert Portfolio') == true,
      ),
      hasBotOrderTriggered: hasBotTriggered,
      hasWonHighLeverage: hasWonLeveraged,
      leaderboardRank: playerRank,
      hasSettledSanierungskredit: hasSanierungSettled,
      hasTradedOffMarketCrypto: hasOffMarketCrypto,
      uniqueAssetTypesCount: _positions.map((p) => p.type).toSet().length,
    );
  }

  int _calculateWinningStreak() {
    int streak = 0;
    int maxStreak = 0;
    final sells = _transactions
        .where((t) => t.type == TransactionType.sell && t.realizedPnL != null)
        .toList()
        .reversed;
    for (final t in sells) {
      if (t.realizedPnL! > 0) {
        streak++;
        if (streak > maxStreak) maxStreak = streak;
      } else {
        streak = 0;
      }
    }
    return maxStreak;
  }

  // Spiel zurücksetzen (falls vom Nutzer gewünscht)
  Future<void> resetGame() async {
    await repository.resetGameToInitial();
    await _init();
  }

  static String _qty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(4);

  @override
  void dispose() {
    _rewards.close();
    _authSubscription?.cancel();
    _leaderboardSubscription?.cancel();
    _liveMarketRefreshTimer?.cancel();
    marketEngine.stop();
    newsService.dispose();
    super.dispose();
  }
}
