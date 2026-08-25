import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/wallet.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/dashboard_summary.dart';
import '../models/user_profile.dart';
import '../models/system_status.dart';

class ApiService {
  static const String defaultOfficialUrl = 'https://focusing-referral-emma-helicopter.trycloudflare.com/api';
  late String baseUrl;

  ApiService({String? baseUrl}) {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      this.baseUrl = baseUrl;
    } else {
      // Default to Proxmox Home Server Tunnel (Cloudflare) so app connects immediately out-of-the-box
      this.baseUrl = defaultOfficialUrl;
    }
  }

  Future<http.Response> _getWithFallback(String path) async {
    final urls = [
      '$baseUrl$path',
      if (baseUrl.contains('10.0.3.2')) baseUrl.replaceAll('10.0.3.2', '10.0.2.2') + path,
      if (baseUrl.contains('10.0.3.2')) baseUrl.replaceAll('10.0.3.2', '192.168.18.4') + path,
    ];

    for (final url in urls) {
      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
        baseUrl = url.substring(0, url.indexOf('/api') + 4);
        return res;
      } catch (_) {
        continue;
      }
    }
    throw Exception('Tidak dapat terhubung ke server backend');
  }

  Future<http.Response> _postWithFallback(String path, Map<String, dynamic> body) async {
    final urls = [
      '$baseUrl$path',
      if (baseUrl.contains('10.0.3.2')) baseUrl.replaceAll('10.0.3.2', '10.0.2.2') + path,
      if (baseUrl.contains('10.0.3.2')) baseUrl.replaceAll('10.0.3.2', '192.168.18.4') + path,
    ];

    for (final url in urls) {
      try {
        final res = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 4));
        // If we get a response, save working base URL and return
        baseUrl = url.substring(0, url.indexOf('/api') + 4);
        return res;
      } catch (_) {
        continue;
      }
    }
    throw Exception('Tidak dapat terhubung ke server backend');
  }

  Future<List<Wallet>> getWallets() async {
    try {
      final res = await _getWithFallback('/wallets');
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final List data = json['data'] ?? [];
        return data.map((e) => Wallet.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Wallet> createWallet({
    required String name,
    required String type,
    double? initialBalance,
    String? icon,
    String? color,
  }) async {
    final res = await _postWithFallback('/wallets', {
      'name': name,
      'type': type,
      'initialBalance': initialBalance ?? 0,
      'icon': icon ?? 'account_balance_wallet',
      'color': color ?? '#003527',
    });

    if (res.statusCode == 201) {
      final json = jsonDecode(res.body);
      return Wallet.fromJson(json['data']);
    }
    final errorJson = jsonDecode(res.body);
    throw Exception(errorJson['error'] ?? 'Gagal membuat dompet');
  }

  Future<void> deleteWallet(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/wallets/$id'));
    if (res.statusCode != 200) {
      throw Exception('Gagal menghapus dompet');
    }
  }

  Future<List<Category>> getCategories() async {
    try {
      final res = await _getWithFallback('/categories');
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final List data = json['data'] ?? [];
        return data.map((e) => Category.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<TransactionModel>> getTransactions({String? walletId}) async {
    try {
      String path = '/transactions';
      if (walletId != null) {
        path += '?wallet_id=$walletId';
      }
      final res = await _getWithFallback(path);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final List data = json['data'] ?? [];
        return data.map((e) => TransactionModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<TransactionModel> createTransaction({
    required String walletId,
    String? targetWalletId,
    String? categoryId,
    required String type,
    required double amount,
    required String date,
    String? note,
  }) async {
    final res = await _postWithFallback('/transactions', {
      'wallet_id': walletId,
      'target_wallet_id': targetWalletId,
      'category_id': categoryId,
      'type': type,
      'amount': amount,
      'date': date,
      'note': note,
    });

    if (res.statusCode == 201) {
      final json = jsonDecode(res.body);
      return TransactionModel.fromJson(json['data']);
    }
    final errorJson = jsonDecode(res.body);
    throw Exception(errorJson['error'] ?? 'Gagal menyimpan transaksi');
  }

  Future<void> deleteTransaction(String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/wallets/$id'));
    if (res.statusCode != 200) {
      throw Exception('Gagal menghapus transaksi');
    }
  }

  Future<DashboardSummary> getDashboardSummary({String? month}) async {
    try {
      String path = '/dashboard';
      if (month != null) path += '?month=$month';
      final res = await _getWithFallback(path);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return DashboardSummary.fromJson(json['data']);
      }
    } catch (_) {}
    return DashboardSummary(
      totalBalance: 0,
      monthIncome: 0,
      monthExpense: 0,
      netSavings: 0,
      walletCount: 0,
      expenseByCategory: [],
    );
  }

  Future<String> getAiAdvice({String? month}) async {
    try {
      String path = '/ai/advice';
      if (month != null) path += '?month=$month';
      final res = await _getWithFallback(path);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return json['data']?['advice'] ?? 'Saran finansial belum tersedia.';
      }
    } catch (_) {}
    return 'Analisis AI siap membantu merencanakan pengeluaran kamu.';
  }

  Future<Map<String, String>> sendAiChatMessage(String message, List<Map<String, String>> history) async {
    final res = await _postWithFallback('/ai/chat', {
      'message': message,
      'history': history,
    });
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return {
        'response': json['data']?['response'] ?? 'Tidak ada tanggapan dari AI.',
        'modelUsed': json['data']?['modelUsed'] ?? 'AI Gateway',
      };
    }
    final errorJson = jsonDecode(res.body);
    throw Exception(errorJson['error'] ?? 'Gagal menghubungi AI Assistant');
  }

  Future<List<Map<String, dynamic>>> getAiChatMessages() async {
    try {
      final res = await _getWithFallback('/ai/chat/messages');
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final List data = json['data'] ?? [];
        return data.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<void> clearAiChatMessages() async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/ai/chat/messages')).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) {
        throw Exception('Gagal menghapus riwayat chat');
      }
    } catch (_) {}
  }

  Future<List<Map<String, String>>> fetchAiModels({String? baseUrl, String? apiKey}) async {
    try {
      final res = await _postWithFallback('/ai/models', {
        'baseUrl': baseUrl,
        'apiKey': apiKey,
      });
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final List rawData = json['data'] ?? [];
        return rawData
            .map<Map<String, String>>((e) => {
                  'id': e['id'].toString(),
                  'name': e['name'].toString(),
                })
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<UserProfile> uploadProfileAvatar(String base64Image) async {
    final res = await _postWithFallback('/profile/avatar', {
      'avatar_base64': base64Image,
    });
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return UserProfile.fromJson(json['data']);
    }
    final errorJson = jsonDecode(res.body);
    throw Exception(errorJson['error'] ?? 'Gagal mengunggah foto profil');
  }

  Future<UserProfile> getProfile() async {
    try {
      final res = await _getWithFallback('/profile');
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return UserProfile.fromJson(json['data']);
      }
    } catch (_) {}
    return UserProfile(
      id: 'user_default',
      name: 'Naufal Pinandhita',
      username: 'Nopal🐐',
      avatarUrl: '',
      email: 'naufal@nana.home',
      waNumber: '+6281234567890',
      waBotEnabled: true,
      aiModel: 'Llama 3 (70B)',
    );
  }

  Future<UserProfile> updateProfile(Map<String, dynamic> data) async {
    try {
      final res = await _postWithFallback('/profile', data);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return UserProfile.fromJson(json['data']);
      }
      final errorJson = jsonDecode(res.body);
      throw Exception(errorJson['error'] ?? 'Gagal memperbarui profil');
    } catch (e) {
      if (e is Exception && e.toString().contains('Gagal memperbarui profil')) {
        rethrow;
      }
      return UserProfile(
        id: 'user_default',
        name: data['name'] ?? 'Naufal Pinandhita',
        username: data['username'] ?? 'Nopal🐐',
        avatarUrl: data['avatar_url'] ?? '',
        email: data['email'] ?? 'naufal@nana.home',
        waNumber: data['wa_number'] ?? '+6281234567890',
        waBotEnabled: data['wa_bot_enabled'] == 1,
        aiProviderType: data['ai_provider_type'] ?? '9router',
        aiBaseUrl: data['ai_base_url'] ?? 'http://192.168.18.27:20128/v1',
        aiApiKey: data['ai_api_key'] ?? '',
        aiModel: data['ai_model'] ?? 'gpt-3.5-turbo',
      );
    }
  }

  Future<SystemStatus> getSystemStatus() async {
    try {
      final res = await _getWithFallback('/system/status');
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return SystemStatus.fromJson(json['data']);
      }
    } catch (_) {}
    return SystemStatus(
      serverStatus: 'online',
      hostname: 'proxmox-home',
      platform: 'Linux Hono LXC',
      cpuModel: 'Intel i7 / Proxmox Home LXC',
      cpuCores: 8,
      cpuUsagePercent: 24,
      ramUsedGb: '3.2',
      ramTotalGb: '16.0',
      uptime: '3d 12h',
      txCount: 0,
      walletCount: 0,
      aiGatewayOnline: true,
      aiGatewayLatencyMs: 14,
      activeAiModel: 'Llama 3 (70B)',
      waBotEnabled: true,
      waBotStatus: 'DISCONNECTED',
      waQrCode: null,
    );
  }

  Future<Map<String, dynamic>> getWaStatus() async {
    try {
      final res = await _getWithFallback('/wa/status');
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return json['data'] ?? {'status': 'DISCONNECTED', 'qrCode': null};
      }
    } catch (_) {}
    return {'status': 'DISCONNECTED', 'qrCode': null};
  }
}
