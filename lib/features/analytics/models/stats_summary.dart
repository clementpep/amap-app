import 'package:freezed_annotation/freezed_annotation.dart';

part 'stats_summary.freezed.dart';
part 'stats_summary.g.dart';

@freezed
class StatsSummary with _$StatsSummary {
  const factory StatsSummary({
    required int totalDeliveries,
    required double avgBasketBio,
    required double avgBasketConv,
    required double totalSavings,
    required double totalSpentBio,
    required double totalSpentConv,
    required List<WeeklyData> weeklyData,
    required List<MonthlyData> monthlyData,
    required List<CategoryData> categoryData,
  }) = _StatsSummary;

  factory StatsSummary.fromJson(Map<String, dynamic> json) =>
      _$StatsSummaryFromJson(json);
}

@freezed
class WeeklyData with _$WeeklyData {
  const factory WeeklyData({
    required DateTime weekStart,
    required double bioSpent,
    required double convSpent,
    required int deliveryCount,
  }) = _WeeklyData;

  factory WeeklyData.fromJson(Map<String, dynamic> json) =>
      _$WeeklyDataFromJson(json);
}

@freezed
class MonthlyData with _$MonthlyData {
  const factory MonthlyData({
    required DateTime month,
    required double bioSpent,
    required double convSpent,
    required double savings,
    required int deliveryCount,
  }) = _MonthlyData;

  factory MonthlyData.fromJson(Map<String, dynamic> json) =>
      _$MonthlyDataFromJson(json);
}

@freezed
class CategoryData with _$CategoryData {
  const factory CategoryData({
    required String category,
    required int itemCount,
    required double percentage,
  }) = _CategoryData;

  factory CategoryData.fromJson(Map<String, dynamic> json) =>
      _$CategoryDataFromJson(json);
}
