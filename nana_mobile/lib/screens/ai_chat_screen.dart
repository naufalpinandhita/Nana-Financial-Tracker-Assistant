import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/luminous_ledger_theme.dart';
import '../models/user_profile.dart';

class ChatMessageItem {
  final String sender; // 'user' or 'ai'
  final String text;
  final DateTime timestamp;
  final String? modelUsed;

  ChatMessageItem({
    required this.sender,
    required this.text,
    required this.timestamp,
    this.modelUsed,
  });
}

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessageItem> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final savedMessages = await ref.read(apiServiceProvider).getAiChatMessages();
      if (mounted) {
        setState(() {
          _messages.clear();
          if (savedMessages.isEmpty) {
            _messages.add(
              ChatMessageItem(
                sender: 'ai',
                text: 'Halo Nopal! Saya terhubung langsung ke database node Proxmox dan saldo finansial Anda. Ada yang bisa saya bantu hari ini?',
                timestamp: DateTime.now(),
                modelUsed: 'System Prompt v1.2',
              ),
            );
          } else {
            for (final item in savedMessages) {
              _messages.add(
                ChatMessageItem(
                  sender: item['sender'] ?? 'ai',
                  text: item['text'] ?? '',
                  timestamp: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
                  modelUsed: item['model_used'],
                ),
              );
            }
          }
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final query = _textController.text.trim();
    if (query.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add(
        ChatMessageItem(
          sender: 'user',
          text: query,
          timestamp: DateTime.now(),
        ),
      );
      _isTyping = true;
    });
    _scrollToBottom();

    // Prepare message history
    final history = _messages
        .where((m) => m.modelUsed != 'System Prompt v1.2')
        .map((m) => {
              'role': m.sender == 'user' ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    try {
      final res = await ref.read(apiServiceProvider).sendAiChatMessage(query, history);
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessageItem(
              sender: 'ai',
              text: res['response'] ?? 'Tidak ada respon.',
              timestamp: DateTime.now(),
              modelUsed: res['modelUsed'],
            ),
          );
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessageItem(
              sender: 'ai',
              text: 'Maaf, terjadi kesalahan koneksi ke AI Gateway server.',
              timestamp: DateTime.now(),
            ),
          );
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemStatusAsync = ref.watch(systemStatusProvider);
    final profileAsync = ref.watch(profileProvider);

    final activeModelName = profileAsync.value?.aiModel ??
        systemStatusAsync.value?.activeAiModel ??
        'gpt-3.5-turbo';

    return Scaffold(
      backgroundColor: LuminousLedgerColors.background,
      body: Stack(
        children: [
          // Background Gradient Blobs
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFB0F0D6).withValues(alpha: 0.25),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.2,
            right: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(),
              ),
            ),
          ),

          // Main Chat Area
          Column(
            children: [
              // Chat Messages List
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                    top: 100,
                    bottom: 120,
                    left: 16,
                    right: 16,
                  ),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < _messages.length) {
                      return _buildMessageBubble(_messages[index]);
                    } else {
                      return _buildTypingIndicator();
                    }
                  },
                ),
              ),
            ],
          ),

          // Header
          _buildHeader(context, profileAsync.value, activeModelName),

          // Input Bar at Bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildInputBar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserProfile? profile, String modelName) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 6,
              bottom: 10,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: LuminousLedgerColors.background.withValues(alpha: 0.85),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: LuminousLedgerColors.primary),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: LuminousLedgerColors.primaryContainer,
                  child: Icon(Icons.auto_awesome, size: 18, color: Color(0xFFB0F0D6)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Nana AI Assistant',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: LuminousLedgerColors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFB0F0D6),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              modelName.toLowerCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: LuminousLedgerColors.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: LuminousLedgerColors.primary),
                  tooltip: 'Hapus Riwayat Chat',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hapus Riwayat Chat'),
                        content: const Text('Apakah Anda yakin ingin menghapus seluruh riwayat percakapan AI?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('BATAL')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('HAPUS'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ref.read(apiServiceProvider).clearAiChatMessages();
                      if (mounted) {
                        setState(() {
                          _messages.clear();
                          _messages.add(
                            ChatMessageItem(
                              sender: 'ai',
                              text: 'Riwayat obrolan telah dibersihkan. Ada yang ingin Anda tanyakan seputar saldo atau transaksi?',
                              timestamp: DateTime.now(),
                              modelUsed: 'System Prompt v1.2',
                            ),
                          );
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageItem item) {
    final isUser = item.sender == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: LuminousLedgerColors.surfaceContainerHigh,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.smart_toy_outlined, size: 18, color: LuminousLedgerColors.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: isUser
                  ? BoxDecoration(
                      color: LuminousLedgerColors.primaryContainer.withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(4),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border.all(color: const Color(0xFFB0F0D6).withValues(alpha: 0.4)),
                    )
                  : BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    Text(
                      item.text,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: LuminousLedgerColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    MarkdownBody(
                      data: item.text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 14, height: 1.4, color: LuminousLedgerColors.onSurface),
                        strong: const TextStyle(fontWeight: FontWeight.bold, color: LuminousLedgerColors.primary),
                        em: const TextStyle(fontStyle: FontStyle.italic, color: LuminousLedgerColors.onSurfaceVariant),
                        listBullet: const TextStyle(fontSize: 14, color: LuminousLedgerColors.primary, fontWeight: FontWeight.bold),
                        h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: LuminousLedgerColors.primary),
                        h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LuminousLedgerColors.primary),
                        h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: LuminousLedgerColors.primary),
                        code: LuminousLedgerTheme.financialStyle(
                          fontSize: 12,
                          color: LuminousLedgerColors.primary,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: LuminousLedgerColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: LuminousLedgerColors.outlineVariant.withValues(alpha: 0.3)),
                        ),
                        horizontalRuleDecoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: LuminousLedgerColors.outlineVariant.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (item.modelUsed != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.memory, size: 10, color: LuminousLedgerColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          item.modelUsed!,
                          style: LuminousLedgerTheme.financialStyle(
                            fontSize: 10,
                            color: LuminousLedgerColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: LuminousLedgerColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 18, color: LuminousLedgerColors.secondaryFixed),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: LuminousLedgerColors.surfaceContainerHigh,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.smart_toy_outlined, size: 18, color: LuminousLedgerColors.primary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: LuminousLedgerColors.primary),
                ),
                SizedBox(width: 8),
                Text(
                  'Nana AI sedang mengetik...',
                  style: TextStyle(fontSize: 12, color: LuminousLedgerColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.only(
            top: 10,
            bottom: MediaQuery.of(context).padding.bottom + 10,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: LuminousLedgerColors.background.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: LuminousLedgerColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: LuminousLedgerColors.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: TextField(
                    controller: _textController,
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(fontSize: 14, color: LuminousLedgerColors.onSurface),
                    decoration: const InputDecoration(
                      hintText: 'Tanya Nana AI seputar saldo & budget...',
                      hintStyle: TextStyle(fontSize: 13, color: LuminousLedgerColors.onSurfaceVariant),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: LuminousLedgerColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
