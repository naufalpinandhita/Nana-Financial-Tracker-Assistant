import 'dart:convert';
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
  String? token;

  ApiService({String? baseUrl, this.token}) {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      this.baseUrl = baseUrl;
    } else {
      this.baseUrl = defaultOfficialUrl;
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> _getWithFallback(String path) async {
    final urls = [
      '$baseUrl$path',
      'http://10.0.3.2:3000/api$path',
      'http://10.0.2.2:3000/api$path',
      'http://192.168.18.4:3000/api$path',
      'http://192.168.18.27:3000/api$path',
    ];

    final headers = await _getHeaders();

    for (final url in urls) {
      try {
        final res = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 3));
        if (res.statusCode != 404) {
          if (url.contains('/api')) {
            baseUrl = url.substring(0, url.indexOf('/api') + 4);
          }
          return res;
        }
      } catch (_) {
        continue;
      }
    }
    throw Exception('Tidak dapat terhubung ke server backend');
  }

  Future<http.Response> _postWithFallback(String path, Map<String, dynamic> body) async {
    final urls = [
      '$baseUrl$path',
      'http://10.0.3.2:3000/api$path',
      'http://10.0.2.2:3000/api$path',
      'http://192.168.18.4:3000/api$path',
      'http://192.168.18.27:3000/api$path',
    ];

    final headers = await _getHeaders();

    for (final url in urls) {
      try {
        final res = await http.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 3));
        if (res.statusCode != 404) {
          if (url.contains('/api')) {
            baseUrl = url.substring(0, url.indexOf('/api') + 4);
          }
          return res;
        }
      } catch (_) {
        continue;
      }
    }
    throw Exception('Tidak dapat terhubung ke server backend');
  }

  // --- AUTH METHODS ---
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _postWithFallback('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Server mengembalikan respon tidak valid (Status ${res.statusCode})');
    }
    if (res.statusCode == 201) {
      return json['data'];
    }
    throw Exception(json['error'] ?? 'Gagal mendaftar akun');
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final res = await _postWithFallback('/auth/login', {
      'identifier': identifier,
      'password': password,
    });
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Server mengembalikan respon tidak valid (Status ${res.statusCode})');
    }
    if (res.statusCode == 200) {
      return json['data'];
    }
    throw Exception(json['error'] ?? 'Gagal masuk akun');
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    String? idToken,
    String? email,
    String? name,
    String? googleId,
    String? avatarUrl,
  }) async {
    final res = await _postWithFallback('/auth/google', {
      if (idToken != null) 'idToken': idToken,
      if (email != null) 'email': email,
      if (name != null) 'name': name,
      if (googleId != null) 'googleId': googleId,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Server mengembalikan respon tidak valid (Status ${res.statusCode})');
    }
    if (res.statusCode == 200) {
      return json['data'];
    }
    throw Exception(json['error'] ?? 'Gagal autentikasi Google');
  }

  Future<UserProfile?> getMe() async {
    try {
      final res = await _getWithFallback('/auth/me');
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return UserProfile.fromJson(json['data']);
      }
    } catch (_) {}
    return null;
  }

  // --- APP API METHODS ---

  /// Step 2 of registration: set username and optional avatar
  Future<UserProfile> setupProfile({
    required String username,
    String? avatarUrl,
  }) async {
    final res = await _postWithFallback('/auth/setup-profile', {
      'username': username,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Server mengembalikan respon tidak valid');
    }
    if (res.statusCode == 200) {
      return UserProfile.fromJson(json['data']);
    }
    throw Exception(json['error'] ?? 'Gagal menyimpan profil');
  }

  /// Check if a username is available (no auth required)
  Future<bool> checkUsernameAvailable(String username) async {
    try {
      final res = await _getWithFallback('/auth/check-username/$username');
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return json['available'] == true;
      }
    } catch (_) {}
    return false;
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

  Future<Wallet> updateWallet({
    required String id,
    String? name,
    String? type,
    String? icon,
    String? color,
  }) async {
    final headers = await _getHeaders();
    final res = await http.put(
      Uri.parse('$baseUrl/wallets/$id'),
      headers: headers,
      body: jsonEncode({
        if (name != null) 'name': name,
        if (type != null) 'type': type,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
      }),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return Wallet.fromJson(json['data']);
    }
    final errorJson = jsonDecode(res.body);
    throw Exception(errorJson['error'] ?? 'Gagal memperbarui dompet');
  }

  Future<void> deleteWallet(String id) async {
    final headers = await _getHeaders();
    final res = await http.delete(Uri.parse('$baseUrl/wallets/$id'), headers: headers);
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
    final headers = await _getHeaders();
    final res = await http.delete(Uri.parse('$baseUrl/transactions/$id'), headers: headers);
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
      final headers = await _getHeaders();
      final res = await http.delete(Uri.parse('$baseUrl/ai/chat/messages'), headers: headers).timeout(const Duration(seconds: 4));
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
      name: 'Pengguna Nana',
      username: 'User',
      avatarUrl: '',
      email: 'user@nana.home',
      waNumber: '',
      waBotEnabled: true,
      aiModel: 'gpt-3.5-turbo',
    );
  }

  Future<UserProfile> updateProfile(Map<String, dynamic> data) async {
    final res = await _postWithFallback('/profile', data);
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      return UserProfile.fromJson(json['data']);
    }
    final errorJson = jsonDecode(res.body);
    throw Exception(errorJson['error'] ?? 'Gagal memperbarui profil');
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
      activeAiModel: 'gpt-3.5-turbo',
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

  /// Start WA QR pairing flow for the current user
  Future<void> connectWa() async {
    final res = await _postWithFallback('/wa/connect', {});
    if (res.statusCode != 200) {
      final errorJson = jsonDecode(res.body);
      throw Exception(errorJson['error'] ?? 'Gagal memulai koneksi WhatsApp');
    }
  }

  /// Request an 8-digit pairing code for [phoneNumber] (e.g. "628123456789")
  Future<String> requestWaPairingCode(String phoneNumber) async {
    final res = await _postWithFallback('/wa/request-pairing-code', {
      'phoneNumber': phoneNumber,
    });
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw Exception('Server mengembalikan respon tidak valid');
    }
    if (res.statusCode == 200) {
      return json['data']?['code'] ?? '';
    }
    throw Exception(json['error'] ?? 'Gagal mendapatkan kode pairing');
  }

  /// Disconnect WA for the current user
  Future<void> disconnectWa() async {
    final res = await _postWithFallback('/wa/disconnect', {});
    if (res.statusCode != 200) {
      final errorJson = jsonDecode(res.body);
      throw Exception(errorJson['error'] ?? 'Gagal memutus koneksi WhatsApp');
    }
  }
}
