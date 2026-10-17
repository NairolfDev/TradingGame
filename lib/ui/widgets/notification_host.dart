import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/market_schedule.dart';
import '../../data/models/reward_event.dart';
import '../../logic/auth_provider.dart';
import '../../logic/notification_planner.dart';
import '../../logic/notification_service.dart';
import '../../logic/portfolio_provider.dart';
import '../../logic/price_alerts_controller.dart';

/// Connects notifications to the rest of the app:
/// - links this device to the signed-in player for price-alert pushes
/// - turns events that happen while the app is in the background (filled
///   orders, achievements) into system notifications
/// - keeps market-hour and loan reminders scheduled
/// - shows pushes that arrive while the app is open in the in-app overlay
class NotificationHost extends StatefulWidget {
  final Widget child;
  const NotificationHost({super.key, required this.child});

  @override
  State<NotificationHost> createState() => _NotificationHostState();
}

class _NotificationHostState extends State<NotificationHost>
    with WidgetsBindingObserver {
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  StreamSubscription<RewardEvent>? _rewards;
  StreamSubscription<PushText>? _push;
  NotificationService? _service;
  PortfolioProvider? _portfolio;
  AuthProvider? _auth;
  String? _scheduleSignature;
  String? _boundUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<NotificationService>();
    final portfolio = context.read<PortfolioProvider>();
    final auth = context.read<AuthProvider>();
    if (!identical(service, _service) || !identical(portfolio, _portfolio)) {
      _detach();
      _service = service;
      _portfolio = portfolio;
      _auth = auth;
      unawaited(service.init().then((_) => _refresh()));
      _rewards = portfolio.rewards.listen(_onReward);
      _push = service.foregroundMessages.listen(
        (m) => portfolio.announce(
          RewardEvent(kind: RewardKind.alert, title: m.title, detail: m.body),
        ),
      );
      portfolio.addListener(_refresh);
      auth.addListener(_refresh);
      auth.beforeSignOut = service.unregisterDevice;
    }
  }

  void _detach() {
    _rewards?.cancel();
    _push?.cancel();
    _portfolio?.removeListener(_refresh);
    _auth?.removeListener(_refresh);
    if (_auth?.beforeSignOut == _service?.unregisterDevice) {
      _auth?.beforeSignOut = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detach();
    super.dispose();
  }

  void _onReward(RewardEvent e) {
    if (_lifecycle == AppLifecycleState.resumed) return; // overlay handles it
    final category = switch (e.kind) {
      RewardKind.achievement || RewardKind.quest => NotificationCategory.loans,
      _ => NotificationCategory.orders,
    };
    final amount = e.cash == null || e.cash == 0
        ? ''
        : ' (${e.cash! > 0 ? '+' : '−'}${e.cash!.abs().toStringAsFixed(2)} €)';
    unawaited(_service?.showNow(category, e.title, '${e.detail}$amount'));
  }

  void _refresh() {
    if (!mounted) return;
    final service = _service;
    final portfolio = _portfolio;
    final auth = _auth;
    if (service == null || portfolio == null || auth == null) return;

    final uid = auth.isAuthenticated ? auth.currentUser?.uid : null;
    if (uid != _boundUid) {
      _boundUid = uid;
      unawaited(service.bindUser(uid));
      context.read<PriceAlertsController>().bindUser(uid);
    }

    final pending = <MarketRegion, int>{};
    final regions = <MarketRegion>{};
    MarketRegion? regionOf(String assetId) {
      for (final a in portfolio.assets) {
        if (a.id == assetId) return MarketSchedule.forAsset(a).region;
      }
      return null;
    }

    for (final o in portfolio.pendingOrders) {
      final r = regionOf(o.assetId);
      if (r == null) continue;
      regions.add(r);
      pending[r] = (pending[r] ?? 0) + 1;
    }
    for (final p in portfolio.positions) {
      final r = regionOf(p.assetId);
      if (r != null) regions.add(r);
    }
    final loans = portfolio.activeLoans;
    final signature = [
      for (final r in regions.toList()..sort((a, b) => a.index - b.index))
        '${r.name}:${pending[r] ?? 0}',
      for (final l in loans) '${l.id}@${l.dueDate.millisecondsSinceEpoch}',
      for (final c in NotificationCategory.values)
        '${c.name}=${service.isEnabled(c)}',
    ].join('|');
    if (signature == _scheduleSignature) return;
    _scheduleSignature = signature;
    final now = DateTime.now();
    unawaited(
      service.syncSchedule([
        ...planMarketNotifications(
          regions: regions,
          from: now,
          pendingOrders: pending,
        ),
        ...planLoanNotifications(loans, now),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
