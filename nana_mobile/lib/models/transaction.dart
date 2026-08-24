class TransactionModel {
  final String id;
  final String walletId;
  final String? targetWalletId;
  final String? categoryId;
  final String type; // 'income' | 'expense' | 'transfer'
  final double amount;
  final String date;
  final String? note;
  final String? walletName;
  final String? targetWalletName;
  final String? categoryName;

  TransactionModel({
    required this.id,
    required this.walletId,
    this.targetWalletId,
    this.categoryId,
    required this.type,
    required this.amount,
    required this.date,
    this.note,
    this.walletName,
    this.targetWalletName,
    this.categoryName,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? '',
      walletId: json['wallet_id'] ?? '',
      targetWalletId: json['target_wallet_id'],
      categoryId: json['category_id'],
      type: json['type'] ?? 'expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date'] ?? '',
      note: json['note'],
      walletName: json['wallet_name'],
      targetWalletName: json['target_wallet_name'],
      categoryName: json['category_name'],
    );
  }
}
