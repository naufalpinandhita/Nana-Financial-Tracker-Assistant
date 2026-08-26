class UserProfile {
  final String id;
  final String name;
  final String? username;
  final String avatarUrl;
  final String email;
  final String waNumber;
  final bool waBotEnabled;
  final String aiProviderType;
  final String aiBaseUrl;
  final String aiApiKey;
  final String aiModel;

  UserProfile({
    required this.id,
    required this.name,
    this.username,
    required this.avatarUrl,
    required this.email,
    required this.waNumber,
    required this.waBotEnabled,
    this.aiProviderType = '9router',
    this.aiBaseUrl = 'http://192.168.18.27:20128/v1',
    this.aiApiKey = '',
    required this.aiModel,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] ?? '',
      email: json['email'] ?? '',
      waNumber: json['wa_number'] ?? '',
      waBotEnabled: json['wa_bot_enabled'] == 1 || json['wa_bot_enabled'] == true,
      aiProviderType: json['ai_provider_type'] ?? '9router',
      aiBaseUrl: json['ai_base_url'] ?? 'http://192.168.18.27:20128/v1',
      aiApiKey: json['ai_api_key'] ?? '',
      aiModel: json['ai_model'] ?? 'gpt-3.5-turbo',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (username != null) 'username': username,
      'avatar_url': avatarUrl,
      'email': email,
      'wa_number': waNumber,
      'wa_bot_enabled': waBotEnabled ? 1 : 0,
      'ai_model': aiModel,
    };
  }
}
