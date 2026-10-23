import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NetWorthPoint {
  final DateTime time;
  final double value;
  const NetWorthPoint(this.time, this.value);
}

/// Net worth samples over time for the dashboard chart. Kept on the device
/// (no Firestore traffic); thinned out once it grows past [maxPoints].
class NetWorthHistory {
  static const maxPoints = 600;
  static const minGap = Duration(minutes: 5);
  static const quickGap = Duration(seconds: 30);
  static const bigMove = 0.005;

  final List<NetWorthPoint> points = [];

  /// Adds a sample when it adds information: every [minGap], or sooner after
  /// a move of at least 0.5 %. Returns whether a point was added.
  bool record(double value, DateTime now) {
    if (!value.isFinite || value <= 0) return false;
    if (points.isNotEmpty) {
      final last = points.last;
      final gap = now.difference(last.time);
      if (gap.isNegative) return false;
      final moved = (value - last.value).abs() / last.value >= bigMove;
      if (gap < minGap && !(moved && gap >= quickGap)) return false;
    }
    points.add(NetWorthPoint(now, value));
    if (points.length > maxPoints) _thin();
    return true;
  }

  /// Drops every second point of the older half so long histories stay small
  /// while recent detail survives.
  void _thin() {
    final half = points.length ~/ 2;
    final older = [for (var i = 0; i < half; i += 2) points[i]];
    final recent = points.sublist(half);
    points
      ..clear()
      ..addAll(older)
      ..addAll(recent);
  }

  /// Points within [window] of the newest sample (all points when null).
  List<NetWorthPoint> within(Duration? window) {
    if (window == null || points.isEmpty) return List.of(points);
    final from = points.last.time.subtract(window);
    return points.where((p) => !p.time.isBefore(from)).toList();
  }

  /// Percentage return over [window] (in percent, e.g. +4.5 for +4.5%) relative
  /// to the earliest sample inside the window, or `fallbackRoiPercent` when
  /// fewer than 2 samples exist.
  double roiOverWindowPercent(
    Duration window, {
    required double currentNetWorth,
    required double fallbackRoiPercent,
  }) {
    final slice = within(window);
    if (slice.isEmpty) return fallbackRoiPercent;
    final baseline = slice.first.value;
    if (!baseline.isFinite || baseline <= 0 || !currentNetWorth.isFinite) {
      return fallbackRoiPercent;
    }
    return ((currentNetWorth - baseline) / baseline) * 100.0;
  }

  /// Maximum peak-to-trough drawdown across recorded history in percent (0..100).
  double get maxDrawdownPercent {
    if (points.length < 2) return 0.0;
    double peak = points.first.value;
    double maxDd = 0.0;
    for (final p in points) {
      if (p.value > peak) peak = p.value;
      if (peak > 0) {
        final dd = ((peak - p.value) / peak) * 100.0;
        if (dd > maxDd) maxDd = dd;
      }
    }
    return maxDd;
  }

  String encode() => jsonEncode([
    for (final p in points) [p.time.millisecondsSinceEpoch, p.value],
  ]);

  void decode(String? raw) {
    points.clear();
    if (raw == null) return;
    try {
      for (final e in jsonDecode(raw) as List) {
        final t = (e[0] as num).toInt();
        final v = (e[1] as num).toDouble();
        if (v.isFinite && v > 0) {
          points.add(NetWorthPoint(DateTime.fromMillisecondsSinceEpoch(t), v));
        }
      }
      points.sort((a, b) => a.time.compareTo(b.time));
    } catch (_) {
      points.clear();
    }
  }

  static String _key(String uid) => 'tg_networth_history_$uid';

  Future<void> load(String uid) async {
    try {
      decode((await SharedPreferences.getInstance()).getString(_key(uid)));
    } catch (_) {
      points.clear();
    }
  }

  Future<void> save(String uid) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key(uid),
        encode(),
      );
    } catch (_) {}
  }
}
