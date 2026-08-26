import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/app_providers.dart';
import '../services/api_service.dart';
import '../theme/luminous_ledger_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_app_bar.dart';
import '../models/system_status.dart';
import 'dashboard_screen.dart';
import 'analytics_screen.dart';
import 'wallet_management_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final int _selectedBottomNavIndex = 3; // Active: Settings
  bool _isTestingGateway = false;
  bool _isFetchingModels = false;
  bool _isConnectingWa = false;

  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  List<Map<String, String>> _availableModels = [];
  String _selectedProvider = '9router';

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: 'http://localhost:20128/v1');
    _apiKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final systemStatusAsync = ref.watch(systemStatusProvider);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: LuminousLedgerColors.background,
      body: Stack(
        children: [
          // Main Scrollable Body Canvas
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(systemStatusProvider);
              ref.read(profileProvider.notifier).fetchProfile();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 90.0, // Top space for header app bar
                bottom: 110.0, // Bottom space for navbar
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Header & E2E Encrypted Badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Infrastructure & AI',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: LuminousLedgerColors.primary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Manage private self-hosted nodes and gateway settings.',
                        style: TextStyle(
                          fontSize: 14,
                          color: LuminousLedgerColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: LuminousLedgerColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: LuminousLedgerColors.primary.withOpacity(0.2),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, size: 14, color: LuminousLedgerColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'END-TO-END ENCRYPTED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: LuminousLedgerColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section 1: Proxmox Node Status (Dark Glass Card)
                  systemStatusAsync.when(
                    data: (status) => _buildProxmoxNodeStatusCard(context, status),
                    loading: () => _buildDarkGlassCard(
                      child: const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator(color: Colors.white)),
                      ),
                    ),
                    error: (err, _) => _buildDarkGlassCard(
                      child: Text('Gagal memuat status: ${err.toString()}', style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 1: Server Backend Configuration (Cloud / Self-Host)
                  _buildServerConfigCard(context),
                  const SizedBox(height: 20),

                  // Section 2: WhatsApp Bot Card (Dark Glass Card)
                  systemStatusAsync.when(
                    data: (status) => profileAsync.when(
                      data: (profile) => _buildWhatsAppBotCard(context, profile.waBotEnabled, profile.waNumber, status),
                      loading: () => _buildDarkGlassCard(
                        child: const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Colors.white))),
                      ),
                      error: (err1, st1) => _buildWhatsAppBotCard(context, true, '+628****7890', status),
                    ),
                    loading: () => _buildDarkGlassCard(
                      child: const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Colors.white))),
                    ),
                    error: (err2, st2) => profileAsync.when(
                      data: (profile) => _buildWhatsAppBotCard(context, profile.waBotEnabled, profile.waNumber, null),
                      loading: () => _buildDarkGlassCard(
                        child: const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Colors.white))),
                      ),
                      error: (err3, st3) => _buildWhatsAppBotCard(context, true, '+628****7890', null),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 3: AI Gateway (9Router) Card (Dark Glass Card + Ambient Glow)
                  systemStatusAsync.when(
                    data: (status) => _buildAIGatewayCard(context, status),
                    loading: () => _buildDarkGlassCard(
                      child: const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Colors.white))),
                    ),
                    error: (err4, st4) => _buildAIGatewayCard(context, null),
                  ),
                ],
              ),
            ),
          ),

          // Custom Glassmorphic Top App Bar
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomAppBar(title: 'Infrastructure'),
          ),

          // Custom Bottom Navigation Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: LuminousLedgerColors.background.withValues(alpha: 0.85),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          offset: const Offset(0, -4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          index: 0,
                          icon: Icons.home_outlined,
                          label: 'Home',
                          isActive: _selectedBottomNavIndex == 0,
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const DashboardScreen()),
                            );
                          },
                        ),
                        _buildNavItem(
                          index: 1,
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Wallet',
                          isActive: _selectedBottomNavIndex == 1,
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const WalletManagementScreen()),
                            );
                          },
                        ),
                        _buildNavItem(
                          index: 2,
                          icon: Icons.insights_outlined,
                          label: 'Analytics',
                          isActive: _selectedBottomNavIndex == 2,
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                            );
                          },
                        ),
                        _buildNavItem(
                          index: 3,
                          icon: Icons.settings,
                          label: 'Settings',
                          isActive: _selectedBottomNavIndex == 3,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Section 1 Widget: Proxmox Node Status
  Widget _buildProxmoxNodeStatusCard(BuildContext context, SystemStatus status) {
    final cpuUsageRatio = (status.cpuUsagePercent / 100).clamp(0.0, 1.0);

    return _buildDarkGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dns, color: Color(0xFFB0F0D6), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Proxmox Node Status (${status.hostname})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFB0F0D6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFA8CFBC),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // CPU & RAM Usage Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CPU Usage',
                            style: LuminousLedgerTheme.financialStyle(
                              fontSize: 12,
                              color: const Color(0xFFD8DBD7),
                            ),
                          ),
                          Text(
                            '${status.cpuUsagePercent}%',
                            style: LuminousLedgerTheme.financialStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFB0F0D6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: cpuUsageRatio,
                        backgroundColor: const Color(0xFF2E312F),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFB0F0D6)),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${status.cpuCores} Cores - ${status.cpuModel}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFFD8DBD7)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RAM',
                            style: LuminousLedgerTheme.financialStyle(
                              fontSize: 12,
                              color: const Color(0xFFD8DBD7),
                            ),
                          ),
                          Text(
                            '${status.ramUsedGb}GB/${status.ramTotalGb}GB',
                            style: LuminousLedgerTheme.financialStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFA8CFBC),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (double.tryParse(status.ramUsedGb) ?? 1.0) / (double.tryParse(status.ramTotalGb) ?? 16.0),
                        backgroundColor: const Color(0xFF2E312F),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA8CFBC)),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        status.platform,
                        style: const TextStyle(fontSize: 10, color: Color(0xFFD8DBD7)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Grid Metrics: Uptime, Temp, Transaksi, Dompet
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            childAspectRatio: 2.4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _StatMetricBox(title: 'SERVER UPTIME', value: status.uptime),
              _StatMetricBox(title: 'SYSTEM LATENCY', value: '${status.aiGatewayLatencyMs} ms'),
              _StatMetricBox(title: 'TRANSAKSI TERSIMPAN', value: '${status.txCount} Transaksi'),
              _StatMetricBox(title: 'DOMPET TERHUBUNG', value: '${status.walletCount} Dompet'),
            ],
          ),
        ],
      ),
    );
  }

  // Section 2 Widget: WhatsApp Bot Status & Controls
  Widget _buildWhatsAppBotCard(BuildContext context, bool isWaBotActive, String waNumber, SystemStatus? status) {
    final waStatus = status?.waBotStatus ?? 'DISCONNECTED';
    final qrCode = status?.waQrCode;
    final displayWaNumber = status?.waConnectedNumber ?? (waStatus == 'CONNECTED' ? waNumber : 'Belum Terhubung');

    Color badgeColor = Colors.red;
    String badgeText = 'TERPUTUS';
    IconData badgeIcon = Icons.error_outline;

    if (waStatus == 'CONNECTED') {
      badgeColor = const Color(0xFFB0F0D6);
      badgeText = 'TERHUBUNG';
      badgeIcon = Icons.check_circle_outline;
    } else if (waStatus == 'CONNECTING' || qrCode != null) {
      badgeColor = Colors.orange;
      badgeText = 'MENUNGGU SCAN';
      badgeIcon = Icons.qr_code_scanner;
    }

    return _buildDarkGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum, color: Color(0xFFA8CFBC), size: 20),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'WhatsApp Bot',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Agent enable/disable toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Agent Status',
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    Text(
                      isWaBotActive ? 'Aktif & Mendengarkan Chat' : 'Nonaktif',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFD8DBD7)),
                    ),
                  ],
                ),
                Switch(
                  value: isWaBotActive,
                  activeThumbColor: LuminousLedgerColors.primary,
                  activeTrackColor: LuminousLedgerColors.secondaryFixed,
                  onChanged: (val) async {
                    final messenger = ScaffoldMessenger.of(context);
                    await ref.read(profileProvider.notifier).updateProfile({
                      'wa_bot_enabled': val ? 1 : 0,
                    });
                    ref.invalidate(systemStatusProvider);
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(val ? 'WhatsApp Bot diaktifkan' : 'WhatsApp Bot dinonaktifkan')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action buttons row
          if (waStatus != 'CONNECTED') ...[
            // Connect button — opens pairing modal
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isConnectingWa ? null : () => _showPairingModal(context),
                icon: _isConnectingWa
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF003527)))
                    : Icon(
                        qrCode != null ? Icons.qr_code_2 : Icons.link,
                        color: const Color(0xFF003527),
                        size: 18,
                      ),
                label: Text(
                  qrCode != null ? 'LIHAT QR CODE / KODE PAIRING' : 'HUBUNGKAN WHATSAPP',
                  style: const TextStyle(
                    color: Color(0xFF003527),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB0F0D6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (waStatus == 'CONNECTED') ...[
            // Disconnect button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _disconnectWa(context),
                icon: const Icon(Icons.link_off, size: 16, color: Colors.redAccent),
                label: const Text(
                  'PUTUSKAN WHATSAPP',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Linked number display
          const Text(
            'Nomor WA Terhubung',
            style: TextStyle(fontSize: 12, color: Color(0xFFD8DBD7)),
          ),
          const SizedBox(height: 6),
          TextField(
            enabled: false,
            controller: TextEditingController(text: displayWaNumber),
            style: LuminousLedgerTheme.financialStyle(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.phone_iphone, size: 18, color: Color(0xFFD8DBD7)),
              filled: true,
              fillColor: const Color(0xFF2E312F),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectWa(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiServiceProvider).disconnectWa();
      ref.invalidate(systemStatusProvider);
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('WhatsApp berhasil diputus.')));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Gagal memutus: ${e.toString().replaceAll('Exception: ', '')}')));
      }
    }
  }

  /// Shows bottom sheet with two tabs: QR Code and Pairing Code
  void _showPairingModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return _PairingBottomSheet(apiService: ref.read(apiServiceProvider));
      },
    ).then((_) {
      // Refresh status after modal closes
      ref.invalidate(systemStatusProvider);
    });
  }

  Widget _buildServerConfigCard(BuildContext context) {
    final currentServerUrl = ref.watch(customServerUrlProvider);
    final isOfficial = currentServerUrl == ApiService.defaultOfficialUrl;
    final controller = TextEditingController(text: currentServerUrl);

    return _buildDarkGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done, color: Color(0xFFB0F0D6), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Backend Server URL',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOfficial ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOfficial ? 'Cloud Default' : 'Self-Hosted',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOfficial ? const Color(0xFFB0F0D6) : Colors.lightBlueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Default terhubung ke Cloud Hosted Backend. Pengguna self-host dapat mengubah URL server ke IP/domain lokal sendiri di sini.',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.dns, size: 18, color: Color(0xFFD8DBD7)),
              filled: true,
              fillColor: const Color(0xFF2E312F),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFB0F0D6)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!isOfficial) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(customServerUrlProvider.notifier).setUrl(ApiService.defaultOfficialUrl);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Server dikembalikan ke Default Cloud Hosted')),
                    );
                  },
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Reset Cloud Default', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: () {
                  final newUrl = controller.text.trim();
                  ref.read(customServerUrlProvider.notifier).setUrl(newUrl);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Server URL diperbarui: $newUrl')),
                  );
                },
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Simpan Server', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003527),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIGatewayCard(BuildContext context, SystemStatus? status) {
    final profileAsync = ref.watch(profileProvider);
    final activeModel = profileAsync.value?.aiModel ?? status?.activeAiModel ?? 'gpt-3.5-turbo';
    final currentProvider = profileAsync.value?.aiProviderType ?? '9router';
    final currentBaseUrl = profileAsync.value?.aiBaseUrl ?? 'http://localhost:20128/v1';
    final currentApiKey = profileAsync.value?.aiApiKey ?? '';

    // Initialize controller text if unchanged
    if (_baseUrlController.text != currentBaseUrl && !_isFetchingModels) {
      _baseUrlController.text = currentBaseUrl;
    }
    if (_apiKeyController.text != currentApiKey && !_isFetchingModels) {
      _apiKeyController.text = currentApiKey;
    }
    _selectedProvider = currentProvider;

    return _buildDarkGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.router, color: Color(0xFFB0F0D6), size: 22),
              const SizedBox(width: 8),
              const Text(
                'AI Gateway & Provider',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status?.aiGatewayOnline == true ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status?.aiGatewayOnline == true ? 'Online (${status?.aiGatewayLatencyMs}ms)' : 'Offline/Fallback',
                  style: TextStyle(
                    fontSize: 11,
                    color: status?.aiGatewayOnline == true ? const Color(0xFFB0F0D6) : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Provider Preset Selector
          const Text(
            'PROVIDER AI PRESET',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD8DBD7),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildProviderChip('9router', '9Router Proxmox', 'http://192.168.18.27:20128/v1'),
                const SizedBox(width: 8),
                _buildProviderChip('openai', 'OpenAI Official', 'https://api.openai.com/v1'),
                const SizedBox(width: 8),
                _buildProviderChip('ollama', 'Ollama Local', 'http://192.168.18.42:11434/v1'),
                const SizedBox(width: 8),
                _buildProviderChip('custom', 'Custom Provider', _baseUrlController.text),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Base URL Field
          const Text(
            'API BASE URL',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD8DBD7), letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _baseUrlController,
            style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.link, size: 18, color: Color(0xFFD8DBD7)),
              filled: true,
              fillColor: const Color(0xFF2E312F),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFB0F0D6)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // API Key Field
          const Text(
            'API KEY (OPSIONAL UNTUK PROVIDER DENGAN AUTH)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD8DBD7), letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.key, size: 18, color: Color(0xFFD8DBD7)),
              hintText: 'sk-... atau kosongkan jika tidak butuh auth',
              hintStyle: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: const Color(0xFF2E312F),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFB0F0D6)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Fetch Models Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isFetchingModels ? null : () => _fetchModelsFromProvider(context),
              icon: _isFetchingModels
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF003527)))
                  : const Icon(Icons.search, size: 16, color: Color(0xFF003527)),
              label: Text(
                _isFetchingModels ? 'MENETAPKAN & DETEKSI MODEL...' : 'DETEKSI DOKUMEN & MODEL TERSEDIA',
                style: const TextStyle(
                  color: Color(0xFF003527),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB0F0D6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Model Selection Dropdown (Combobox)
          const Text(
            'MODEL AI TERPILIH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD8DBD7),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2E312F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFB0F0D6).withOpacity(0.4)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: (_availableModels.any((m) => m['id'] == activeModel))
                    ? activeModel
                    : (_availableModels.isNotEmpty ? _availableModels.first['id'] : activeModel),
                isExpanded: true,
                dropdownColor: const Color(0xFF191C1B),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFB0F0D6)),
                style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                items: (_availableModels.isEmpty
                        ? [{'id': activeModel, 'name': activeModel}]
                        : _availableModels)
                    .map((m) {
                  final modelId = m['id']!;
                  return DropdownMenuItem<String>(
                    value: modelId,
                    child: Text(
                      m['name'] ?? modelId,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (newModelId) {
                  if (newModelId != null) {
                    _updateSelectedModel(newModelId);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Test Connection Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isTestingGateway ? null : () => _testGatewayConnection(context),
              icon: _isTestingGateway
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.speed, size: 16, color: Colors.white),
              label: Text(
                _isTestingGateway ? 'UJI KONEKSI PROVIDER...' : 'UJI KONEKSI AI GATEWAY',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderChip(String id, String label, String defaultUrl) {
    final isSelected = _selectedProvider == id;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF003527) : Colors.white,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFB0F0D6),
      backgroundColor: const Color(0xFF2E312F),
      onSelected: (bool selected) async {
        if (selected) {
          setState(() {
            _selectedProvider = id;
            _baseUrlController.text = defaultUrl;
          });
          await ref.read(profileProvider.notifier).updateProfile({
            'ai_provider_type': id,
            'ai_base_url': defaultUrl,
          });
          ref.invalidate(systemStatusProvider);
        }
      },
    );
  }

  Future<void> _fetchModelsFromProvider(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isFetchingModels = true);

    final url = _baseUrlController.text.trim();
    final key = _apiKeyController.text.trim();

    await ref.read(profileProvider.notifier).updateProfile({
      'ai_provider_type': _selectedProvider,
      'ai_base_url': url,
      'ai_api_key': key,
    });

    final models = await ref.read(apiServiceProvider).fetchAiModels(baseUrl: url, apiKey: key);

    if (mounted) {
      setState(() {
        _isFetchingModels = false;
        _availableModels = models;
      });

      if (models.isNotEmpty) {
        // Auto select first detected model if active model is not in list
        final currentModel = ref.read(profileProvider).value?.aiModel;
        if (!models.any((m) => m['id'] == currentModel)) {
          await _updateSelectedModel(models.first['id']!);
        }
        messenger.showSnackBar(
          SnackBar(content: Text('Berhasil mendeteksi ${models.length} model dari provider!')),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Gagal mengambil daftar model. Periksa Base URL & API Key.')),
        );
      }
    }
  }

  Future<void> _updateSelectedModel(String modelId) async {
    await ref.read(profileProvider.notifier).updateProfile({
      'ai_provider_type': _selectedProvider,
      'ai_base_url': _baseUrlController.text.trim(),
      'ai_api_key': _apiKeyController.text.trim(),
      'ai_model': modelId,
    });
    ref.invalidate(systemStatusProvider);
  }

  Future<void> _testGatewayConnection(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isTestingGateway = true);
    ref.invalidate(systemStatusProvider);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isTestingGateway = false);
      final status = ref.read(systemStatusProvider).value;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            status?.aiGatewayOnline == true
                ? 'Koneksi 9Router Gateway Terhubung! (${status?.aiGatewayLatencyMs}ms)'
                : 'Koneksi 9Router Gateway berhasil diuji (Mode Fallback Siap).',
          ),
        ),
      );
    }
  }

  Widget _buildDarkGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2E312F).withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(4, 4),
            blurRadius: 12,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.05),
            offset: const Offset(-2, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: isActive
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: isActive
            ? BoxDecoration(
                color: LuminousLedgerColors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? LuminousLedgerColors.secondaryFixed
                  : LuminousLedgerColors.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? LuminousLedgerColors.secondaryFixed
                    : LuminousLedgerColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with two tabs: QR Code and Pairing Code
class _PairingBottomSheet extends ConsumerStatefulWidget {
  final ApiService apiService;
  const _PairingBottomSheet({required this.apiService});

  @override
  ConsumerState<_PairingBottomSheet> createState() => _PairingBottomSheetState();
}

class _PairingBottomSheetState extends ConsumerState<_PairingBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _phoneController = TextEditingController();
  bool _isRequestingCode = false;
  bool _isStartingQr = false;
  String? _pairingCode;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _startQrFlow() async {
    setState(() {
      _isStartingQr = true;
      _errorMessage = null;
    });
    try {
      await widget.apiService.connectWa();
      ref.invalidate(systemStatusProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isStartingQr = false);
    }
  }

  Future<void> _requestPairingCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Masukkan nomor telepon terlebih dahulu');
      return;
    }
    setState(() {
      _isRequestingCode = true;
      _pairingCode = null;
      _errorMessage = null;
    });
    try {
      final code = await widget.apiService.requestWaPairingCode(phone);
      if (mounted) {
        setState(() => _pairingCode = code);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isRequestingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemStatusAsync = ref.watch(systemStatusProvider);
    final status = systemStatusAsync.asData?.value;
    final currentQr = status?.waQrCode;
    final isConnected = status?.waBotStatus == 'CONNECTED';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF191C1B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, -5)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            isConnected ? 'WhatsApp Terhubung!' : 'Pairing WhatsApp Bot',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            isConnected
                ? 'Bot WhatsApp Nana siap mencatat transaksi via chat.'
                : 'Pilih metode pairing yang sesuai dengan perangkat kamu.',
            style: const TextStyle(fontSize: 12, color: Color(0xFFD8DBD7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          if (isConnected) ...[
            // Connected state — show success
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF003527).withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB0F0D6).withOpacity(0.4)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFFB0F0D6), size: 56),
                  SizedBox(height: 12),
                  Text(
                    'Berhasil Terhubung',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFB0F0D6)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Kirim pesan ke WhatsApp kamu untuk mencatat transaksi.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFD8DBD7)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFFB0F0D6),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: const Color(0xFF003527),
                unselectedLabelColor: const Color(0xFFD8DBD7),
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'QR Code'),
                  Tab(text: 'Kode Pairing'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab content
            SizedBox(
              height: 320,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // --- Tab 1: QR Code ---
                  _buildQrTab(currentQr),
                  // --- Tab 2: Pairing Code ---
                  _buildPairingCodeTab(),
                ],
              ),
            ),
          ],

          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Close button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isConnected ? 'Selesai' : 'Tutup'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrTab(String? currentQr) {
    return Column(
      children: [
        // QR display
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: const Color(0xFFB0F0D6).withOpacity(0.3), blurRadius: 15, spreadRadius: 2),
            ],
          ),
          child: currentQr != null && currentQr.isNotEmpty
              ? QrImageView(data: currentQr, version: QrVersions.auto, size: 180.0, backgroundColor: Colors.white)
              : SizedBox(
                  width: 180, height: 180,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: LuminousLedgerColors.primary),
                      const SizedBox(height: 12),
                      const Text('Menunggu QR...', style: TextStyle(fontSize: 11, color: Colors.black54), textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(systemStatusProvider),
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 12),
        // Instruction
        const Text(
          'Buka WhatsApp → Perangkat Tertaut → Tautkan Perangkat → Scan QR',
          style: TextStyle(fontSize: 11, color: Color(0xFFD8DBD7)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (currentQr == null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isStartingQr ? null : _startQrFlow,
              icon: _isStartingQr
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF003527)))
                  : const Icon(Icons.qr_code_2, size: 16, color: Color(0xFF003527)),
              label: Text(
                _isStartingQr ? 'Memulai...' : 'Mulai Sesi QR',
                style: const TextStyle(color: Color(0xFF003527), fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB0F0D6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPairingCodeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NOMOR WHATSAPP KAMU',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD8DBD7), letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'contoh: 628123456789',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
            prefixIcon: const Icon(Icons.phone, size: 18, color: Color(0xFFD8DBD7)),
            filled: true,
            fillColor: const Color(0xFF2E312F),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFB0F0D6)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Format E.164 tanpa "+": 628xxxxxxxxxx',
          style: TextStyle(fontSize: 10, color: Color(0xFF8A9E97)),
        ),
        const SizedBox(height: 16),

        // Pairing code display
        if (_pairingCode != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF003527).withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFB0F0D6).withOpacity(0.5)),
            ),
            child: Column(
              children: [
                const Text('KODE PAIRING', style: TextStyle(fontSize: 10, color: Color(0xFFD8DBD7), letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  _pairingCode!,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB0F0D6),
                    letterSpacing: 6,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kode berlaku ±160 detik',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8A9E97)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Buka WhatsApp → Perangkat Tertaut → Tautkan dengan Nomor Telepon → Masukkan kode di atas',
            style: TextStyle(fontSize: 11, color: Color(0xFFD8DBD7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isRequestingCode ? null : _requestPairingCode,
            icon: _isRequestingCode
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF003527)))
                : const Icon(Icons.key, size: 16, color: Color(0xFF003527)),
            label: Text(
              _isRequestingCode ? 'Meminta Kode...' : (_pairingCode != null ? 'Minta Kode Baru' : 'Dapatkan Kode Pairing'),
              style: const TextStyle(color: Color(0xFF003527), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB0F0D6),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatMetricBox extends StatelessWidget {
  final String title;
  final String value;

  const _StatMetricBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFFD8DBD7),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: LuminousLedgerTheme.financialStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}