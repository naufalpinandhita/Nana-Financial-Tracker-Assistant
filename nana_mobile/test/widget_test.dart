import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nana_mobile/main.dart';
import 'package:nana_mobile/services/api_service.dart';
import 'package:nana_mobile/models/wallet.dart';
import 'package:nana_mobile/models/category.dart';
import 'package:nana_mobile/models/transaction.dart';
import 'package:nana_mobile/models/dashboard_summary.dart';
import 'package:nana_mobile/providers/app_providers.dart';

class MockApiService extends ApiService {
  @override
  Future<List<Wallet>> getWallets() async {
    return [
      Wallet(id: 'w1', name: 'Cash', type: 'Cash', balance: 150000, icon: 'account_balance', color: '#003527'),
    ];
  }

  @override
  Future<List<Category>> getCategories() async {
    return [
      Category(id: 'cat1', name: 'Makanan', type: 'expense', icon: 'restaurant', color: '#ba1a1a'),
    ];
  }

  @override
  Future<List<TransactionModel>> getTransactions({String? walletId}) async {
    return [];
  }

  @override
  Future<DashboardSummary> getDashboardSummary({String? month}) async {
    return DashboardSummary(
      totalBalance: 150000,
      monthIncome: 0,
      monthExpense: 0,
      netSavings: 0,
      walletCount: 1,
      expenseByCategory: [],
    );
  }
}

void main() {
  testWidgets('NanaApp renders DashboardScreen cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(MockApiService()),
        ],
        child: const NanaApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Nana title and net worth text render
    expect(find.text('NANA'), findsOneWidget);
    expect(find.text('Total Net Worth'), findsOneWidget);
    expect(find.text('Dompet Saya'), findsOneWidget);
  });
}
