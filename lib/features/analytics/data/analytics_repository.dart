import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stats_summary.dart';

part 'analytics_repository.g.dart';

@riverpod
AnalyticsRepository analyticsRepository(Ref ref) =>
    AnalyticsRepository(Supabase.instance.client);

enum StatsPeriod { threeMonths, sixMonths, oneYear, allTime }

extension StatsPeriodX on StatsPeriod {
  DateTime get since {
    final now = DateTime.now();
    switch (this) {
      case StatsPeriod.threeMonths:
        return now.subtract(const Duration(days: 90));
      case StatsPeriod.sixMonths:
        return now.subtract(const Duration(days: 180));
      case StatsPeriod.oneYear:
        return now.subtract(const Duration(days: 365));
      case StatsPeriod.allTime:
        return DateTime(2020);
    }
  }

  String get label {
    switch (this) {
      case StatsPeriod.threeMonths: return '3 mois';
      case StatsPeriod.sixMonths: return '6 mois';
      case StatsPeriod.oneYear: return '1 an';
      case StatsPeriod.allTime: return 'Tout';
    }
  }
}

class AnalyticsRepository {
  final SupabaseClient _client;
  AnalyticsRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<StatsSummary> getSummary(StatsPeriod period) async {
    final since = period.since;
    final sinceStr = since.toIso8601String().split('T')[0];

    // Fetch deliveries in range
    final deliveries = await _client
        .from('deliveries')
        .select('id, delivered_at, total_bio_price, total_conv_price')
        .eq('user_id', _userId)
        .gte('delivered_at', sinceStr)
        .not('total_bio_price', 'is', null)
        .order('delivered_at', ascending: true);

    final rows = (deliveries as List);

    if (rows.isEmpty) {
      return StatsSummary(
        totalDeliveries: 0,
        avgBasketBio: 0,
        avgBasketConv: 0,
        totalSavings: 0,
        totalSpentBio: 0,
        totalSpentConv: 0,
        weeklyData: [],
        monthlyData: [],
        categoryData: [],
      );
    }

    // Compute aggregates
    double totalBio = 0, totalConv = 0;
    for (final d in rows) {
      totalBio += (d['total_bio_price'] as num?)?.toDouble() ?? 0;
      totalConv += (d['total_conv_price'] as num?)?.toDouble() ?? 0;
    }
    final count = rows.length;

    // Weekly data (last 12 weeks)
    final weeklyData = _aggregateWeekly(rows);

    // Monthly data
    final monthlyData = _aggregateMonthly(rows);

    // Category distribution
    final categoryData = await _getCategoryData(since);

    return StatsSummary(
      totalDeliveries: count,
      avgBasketBio: count > 0 ? totalBio / count : 0,
      avgBasketConv: count > 0 ? totalConv / count : 0,
      totalSavings: totalConv - totalBio,
      totalSpentBio: totalBio,
      totalSpentConv: totalConv,
      weeklyData: weeklyData,
      monthlyData: monthlyData,
      categoryData: categoryData,
    );
  }

  List<WeeklyData> _aggregateWeekly(List rows) {
    final now = DateTime.now();
    final weeks = <DateTime, Map<String, dynamic>>{};

    // Initialize last 12 weeks
    for (int i = 11; i >= 0; i--) {
      final weekStart = _weekStart(now.subtract(Duration(days: i * 7)));
      weeks[weekStart] = {'bio': 0.0, 'conv': 0.0, 'count': 0};
    }

    for (final row in rows) {
      final date = DateTime.parse(row['delivered_at'] as String);
      final weekStart = _weekStart(date);
      if (weeks.containsKey(weekStart)) {
        weeks[weekStart]!['bio'] =
            (weeks[weekStart]!['bio'] as double) + ((row['total_bio_price'] as num?)?.toDouble() ?? 0);
        weeks[weekStart]!['conv'] =
            (weeks[weekStart]!['conv'] as double) + ((row['total_conv_price'] as num?)?.toDouble() ?? 0);
        weeks[weekStart]!['count'] = (weeks[weekStart]!['count'] as int) + 1;
      }
    }

    return weeks.entries
        .map((e) => WeeklyData(
              weekStart: e.key,
              bioSpent: e.value['bio'] as double,
              convSpent: e.value['conv'] as double,
              deliveryCount: e.value['count'] as int,
            ))
        .toList();
  }

  List<MonthlyData> _aggregateMonthly(List rows) {
    final months = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final date = DateTime.parse(row['delivered_at'] as String);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      months.putIfAbsent(key, () => {
        'date': DateTime(date.year, date.month),
        'bio': 0.0,
        'conv': 0.0,
        'count': 0,
      });
      months[key]!['bio'] = (months[key]!['bio'] as double) +
          ((row['total_bio_price'] as num?)?.toDouble() ?? 0);
      months[key]!['conv'] = (months[key]!['conv'] as double) +
          ((row['total_conv_price'] as num?)?.toDouble() ?? 0);
      months[key]!['count'] = (months[key]!['count'] as int) + 1;
    }

    return months.entries
        .map((e) => MonthlyData(
              month: e.value['date'] as DateTime,
              bioSpent: e.value['bio'] as double,
              convSpent: e.value['conv'] as double,
              savings: (e.value['conv'] as double) - (e.value['bio'] as double),
              deliveryCount: e.value['count'] as int,
            ))
        .toList()
        ..sort((a, b) => a.month.compareTo(b.month));
  }

  Future<List<CategoryData>> _getCategoryData(DateTime since) async {
    try {
      final items = await _client
          .from('basket_items')
          .select('product_name, products(category)')
          .gte('created_at', since.toIso8601String());

      final categories = <String, int>{};
      for (final item in (items as List)) {
        final product = item['products'] as Map<String, dynamic>?;
        final cat = product?['category'] as String? ?? 'Autre';
        categories[cat] = (categories[cat] ?? 0) + 1;
      }

      final total = categories.values.fold(0, (a, b) => a + b);
      if (total == 0) return [];

      final sorted = categories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Top 5 + "Autre"
      final top5 = sorted.take(5).toList();
      final otherCount = sorted.skip(5).fold(0, (sum, e) => sum + e.value);

      final result = top5
          .map((e) => CategoryData(
                category: e.key,
                itemCount: e.value,
                percentage: (e.value / total) * 100,
              ))
          .toList();

      if (otherCount > 0) {
        result.add(CategoryData(
          category: 'Autre',
          itemCount: otherCount,
          percentage: (otherCount / total) * 100,
        ));
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  DateTime _weekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }
}
