class SystemStatus {
  final String serverStatus;
  final String hostname;
  final String platform;
  final String cpuModel;
  final int cpuCores;
  final int cpuUsagePercent;
  final String ramUsedGb;
  final String ramTotalGb;
  final String uptime;
  final int txCount;
  final int walletCount;
  final bool aiGatewayOnline;
  final int aiGatewayLatencyMs;
  final String activeAiModel;
  final bool waBotEnabled;
  final String waBotStatus;
  final String? waQrCode;
  final String? waConnectedNumber;

  SystemStatus({
    required this.serverStatus,
    required this.hostname,
    required this.platform,
    required this.cpuModel,
    required this.cpuCores,
    required this.cpuUsagePercent,
    required this.ramUsedGb,
    required this.ramTotalGb,
    required this.uptime,
    required this.txCount,
    required this.walletCount,
    required this.aiGatewayOnline,
    required this.aiGatewayLatencyMs,
    required this.activeAiModel,
    required this.waBotEnabled,
    this.waBotStatus = 'DISCONNECTED',
    this.waQrCode,
    this.waConnectedNumber,
  });

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    return SystemStatus(
      serverStatus: json['server_status'] ?? 'online',
      hostname: json['hostname'] ?? 'proxmox-home',
      platform: json['platform'] ?? 'Linux',
      cpuModel: json['cpu_model'] ?? 'Generic CPU',
      cpuCores: json['cpu_cores'] ?? 8,
      cpuUsagePercent: json['cpu_usage_percent'] ?? 25,
      ramUsedGb: json['ram_used_gb'] ?? '2.4',
      ramTotalGb: json['ram_total_gb'] ?? '16.0',
      uptime: json['uptime'] ?? '1d 4h',
      txCount: json['tx_count'] ?? 0,
      walletCount: json['wallet_count'] ?? 0,
      aiGatewayOnline: json['ai_gateway_online'] ?? true,
      aiGatewayLatencyMs: json['ai_gateway_latency_ms'] ?? 15,
      activeAiModel: json['active_ai_model'] ?? 'Llama 3 (70B)',
      waBotEnabled: json['wa_bot_enabled'] ?? true,
      waBotStatus: json['wa_bot_status'] ?? 'DISCONNECTED',
      waQrCode: json['wa_qr_code'],
      waConnectedNumber: json['wa_connected_number'],
    );
  }
}
