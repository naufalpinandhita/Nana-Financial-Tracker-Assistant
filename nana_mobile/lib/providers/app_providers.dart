import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/wallet.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/dashboard_summary.dart';
import '../models/user_profile.dart';
import '../models/system_status.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

class WalletsNotifier extends StateNotifier<AsyncValue<List<Wallet>>> {
  final ApiService apiService;

  WalletsNotifier(this.apiService) : super(const AsyncValue.loading()) {
    fetchWallets();
  }

  Future<void> fetchWallets() async {
    try {
      state = const AsyncValue.loading();
      final wallets = await apiService.getWallets();
      state = AsyncValue.data(wallets);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addWallet({
    required String name,
    required String type,
    double? initialBalance,
    String? icon,
    String? color,
  }) async {
    await apiService.createWallet(
      name: name,
      type: type,
      initialBalance: initialBalance,
      icon: icon,
      color: color,
    );
    await fetchWallets();
  }

  Future<void> deleteWallet(String id) async {
    await apiService.deleteWallet(id);
    await fetchWallets();
  }
}

final walletsProvider = StateNotifierProvider<WalletsNotifier, AsyncValue<List<Wallet>>>((ref) {
  return WalletsNotifier(ref.watch(apiServiceProvider));
});

class CategoriesNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  final ApiService apiService;

  CategoriesNotifier(this.apiService) : super(const AsyncValue.loading()) {
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    try {
      state = const AsyncValue.loading();
      final categories = await apiService.getCategories();
      state = AsyncValue.data(categories);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final categoriesProvider = StateNotifierProvider<CategoriesNotifier, AsyncValue<List<Category>>>((ref) {
  return CategoriesNotifier(ref.watch(apiServiceProvider));
});

class TransactionsNotifier extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  final ApiService apiService;

  TransactionsNotifier(this.apiService) : super(const AsyncValue.loading()) {
    fetchTransactions();
  }

  Future<void> fetchTransactions({String? walletId}) async {
    try {
      state = const AsyncValue.loading();
      final txs = await apiService.getTransactions(walletId: walletId);
      state = AsyncValue.data(txs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTransaction({
    required String walletId,
    String? targetWalletId,
    String? categoryId,
    required String type,
    required double amount,
    required String date,
    String? note,
  }) async {
    await apiService.createTransaction(
      walletId: walletId,
      targetWalletId: targetWalletId,
      categoryId: categoryId,
      type: type,
      amount: amount,
      date: date,
      note: note,
    );
    await fetchTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    await apiService.deleteTransaction(id);
    await fetchTransactions();
  }
}

final transactionsProvider = StateNotifierProvider<TransactionsNotifier, AsyncValue<List<TransactionModel>>>((ref) {
  return TransactionsNotifier(ref.watch(apiServiceProvider));
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final selectedDate = ref.watch(selectedAnalyticsMonthProvider);
  final monthStr = DateFormat('yyyy-MM').format(selectedDate);
  return await api.getDashboardSummary(month: monthStr);
});

class ProfileNotifier extends StateNotifier<AsyncValue<UserProfile>> {
  final ApiService apiService;

  ProfileNotifier(this.apiService) : super(const AsyncValue.loading()) {
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    try {
      state = const AsyncValue.loading();
      final profile = await apiService.getProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      final updated = await apiService.updateProfile(data);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<UserProfile>>((ref) {
  return ProfileNotifier(ref.watch(apiServiceProvider));
});

final systemStatusProvider = FutureProvider<SystemStatus>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getSystemStatus();
});

final selectedAnalyticsMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final aiAdviceProvider = FutureProvider.family<String, String>((ref, monthStr) async {
  final api = ref.watch(apiServiceProvider);
  return await api.getAiAdvice(month: monthStr);
});
