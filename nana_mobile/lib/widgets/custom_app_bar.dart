import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/luminous_ledger_theme.dart';
import '../screens/profile_screen.dart';
import '../screens/ai_chat_screen.dart';

class CustomAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;

  const CustomAppBar({super.key, this.title = 'Nana'});

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return ClipRRect(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                child: Row(
                  children: [
                    profileAsync.when(
                      data: (profile) {
                        ImageProvider? avatarImage;
                        if (profile.avatarUrl.startsWith('data:image')) {
                          try {
                            final base64Content = profile.avatarUrl.split(',').last;
                            avatarImage = MemoryImage(base64Decode(base64Content));
                          } catch (_) {}
                        } else if (profile.avatarUrl.startsWith('http')) {
                          avatarImage = NetworkImage(profile.avatarUrl);
                        }

                        return CircleAvatar(
                          radius: 18,
                          backgroundColor: LuminousLedgerColors.primaryContainer,
                          backgroundImage: avatarImage,
                          child: avatarImage == null
                              ? Text(
                                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'N',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: LuminousLedgerColors.secondaryFixed),
                                )
                              : null,
                        );
                      },
                      loading: () => const CircleAvatar(
                        radius: 18,
                        backgroundColor: LuminousLedgerColors.surfaceContainerHigh,
                      ),
                      error: (_, _) => const CircleAvatar(
                        radius: 18,
                        backgroundColor: LuminousLedgerColors.primaryContainer,
                        child: Icon(Icons.person, size: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: LuminousLedgerColors.surfaceTint,
                          ),
                        ),
                        profileAsync.when(
                          data: (profile) => Text(
                            profile.username,
                            style: const TextStyle(
                              fontSize: 11,
                              color: LuminousLedgerColors.onSurfaceVariant,
                            ),
                          ),
                          loading: () => const SizedBox(),
                          error: (_, _) => const SizedBox(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: LuminousLedgerColors.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFB0F0D6).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AiChatScreen()),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: LuminousLedgerColors.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'AI Chat',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: LuminousLedgerColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      );
                    },
                    icon: const Icon(
                      Icons.person_outline,
                      color: LuminousLedgerColors.primary,
                    ),
                    tooltip: 'Profil Saya',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
