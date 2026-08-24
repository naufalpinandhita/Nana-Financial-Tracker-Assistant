class Wallet {
  final String id;
  final String name;
  final String type;
  final double balance;
  final String icon;
  final String color;

  Wallet({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.icon,
    required this.color,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'Bank',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      icon: json['icon'] ?? 'account_balance_wallet',
      color: json['color'] ?? '#003527',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'icon': icon,
      'color': color,
    };
  }
}
