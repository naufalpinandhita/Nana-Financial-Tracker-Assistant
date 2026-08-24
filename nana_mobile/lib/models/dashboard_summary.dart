class ExpenseCategorySummary {
  final String categoryName;
  final String categoryColor;
  final double totalAmount;

  ExpenseCategorySummary({
    required this.categoryName,
    required this.categoryColor,
    required this.totalAmount,
  });

  factory ExpenseCategorySummary.fromJson(Map<String, dynamic> json) {
    return ExpenseCategorySummary(
      categoryName: json['category_name'] ?? '',
      categoryColor: json['category_color'] ?? '#064e3b',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DashboardSummary {
  final double totalBalance;
  final double monthIncome;
  final double monthExpense;
  final double netSavings;
  final int walletCount;
  final List<ExpenseCategorySummary> expenseByCategory;

  DashboardSummary({
    required this.totalBalance,
    required this.monthIncome,
    required this.monthExpense,
    required this.netSavings,
    required this.walletCount,
    required this.expenseByCategory,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    var rawCategories = json['expenseByCategory'] as List? ?? [];
    List<ExpenseCategorySummary> categoriesList =
        rawCategories.map((c) => ExpenseCategorySummary.fromJson(c)).toList();

    return DashboardSummary(
      totalBalance: (json['totalBalance'] as num?)?.toDouble() ?? 0.0,
      monthIncome: (json['monthIncome'] as num?)?.toDouble() ?? 0.0,
      monthExpense: (json['monthExpense'] as num?)?.toDouble() ?? 0.0,
      netSavings: (json['netSavings'] as num?)?.toDouble() ?? 0.0,
      walletCount: json['walletCount'] ?? 0,
      expenseByCategory: categoriesList,
    );
  }
}
