import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../viewmodels/chat_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'widgets/market_palette.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatViewModel>().loadChats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: Consumer2<ChatViewModel, SettingsViewModel>(
        builder: (context, chatViewModel, settings, _) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _SupportHeader(
                  isAvailable: true,
                  hoursMessage:
                      'Mesajınızı bırakın, en kısa sürede yanıtlayalım',
                  onBack: () => context.pop(),
                  onRefresh: chatViewModel.loadChats,
                ),
              ),
              if (chatViewModel.isLoading && chatViewModel.chats.isEmpty)
                const SliverFillRemaining(child: _ChatLoadingState())
              else if (chatViewModel.chats.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyChatState(
                    isAvailable: true,
                    onStart: () => _startNewChat(context),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 25, 20, 14),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MESAJLARIN',
                                style: GoogleFonts.inter(
                                  color: MarketPalette.green,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Destek görüşmeleri',
                                style: GoogleFonts.manrope(
                                  color: MarketPalette.ink,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: MarketPalette.greenSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${chatViewModel.chats.length} görüşme',
                            style: GoogleFonts.inter(
                              color: MarketPalette.greenDark,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: SliverList.separated(
                    itemCount: chatViewModel.chats.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final chat = chatViewModel.chats[index];
                      return _ChatCard(
                        chat: chat,
                        onTap: () {
                          chatViewModel.openChat(chat);
                          context.push('/chat/${chat.id}');
                        },
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: Consumer<ChatViewModel>(
        builder: (context, viewModel, _) {
          if (viewModel.chats.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _startNewChat(context),
            backgroundColor: MarketPalette.green,
            foregroundColor: Colors.white,
            elevation: 3,
            icon: const Icon(Icons.add_comment_rounded, size: 20),
            label: Text(
              'Yeni Sohbet',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _startNewChat(BuildContext context) async {
    final viewModel = context.read<ChatViewModel>();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _StartingChatDialog(),
    );

    try {
      final chat = await viewModel.startChat();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (chat != null) {
        context.push('/chat/${chat.id}');
      } else {
        _showError(viewModel.error ?? 'Sohbet başlatılamadı');
      }
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showError('Sohbet başlatılırken bir sorun oluştu.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: MarketPalette.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          margin: const EdgeInsets.all(18),
        ),
      );
  }
}

class _SupportHeader extends StatelessWidget {
  final bool isAvailable;
  final String hoursMessage;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _SupportHeader({
    required this.isAvailable,
    required this.hoursMessage,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 14,
        20,
        26,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF063F2B),
            Color(0xFF075B39),
            Color(0xFF117A48),
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SupportHeaderButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack,
              ),
              const Spacer(),
              _SupportHeaderButton(
                icon: Icons.refresh_rounded,
                onTap: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: MarketPalette.lime,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: MarketPalette.greenDeep,
                  size: 29,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Canlı Destek',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isAvailable
                                ? MarketPalette.lime
                                : MarketPalette.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            isAvailable
                                ? 'Destek ekibi şu anda yardımcı olabilir'
                                : hoursMessage,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: .72),
                              fontSize: 11,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupportHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SupportHeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  final ChatModel chat;
  final VoidCallback onTap;

  const _ChatCard({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = chat.userUnreadCount > 0;
    final isClosed = chat.status == 'closed';
    final isOrder = chat.type == 'order';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: hasUnread
                  ? MarketPalette.green.withValues(alpha: .38)
                  : MarketPalette.line,
              width: hasUnread ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: MarketPalette.ink.withValues(alpha: .04),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isOrder
                          ? const Color(0xFFFFF1DF)
                          : MarketPalette.greenSoft,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(
                      isOrder
                          ? Icons.shopping_bag_rounded
                          : Icons.support_agent_rounded,
                      color: isOrder
                          ? const Color(0xFFCC6D1B)
                          : MarketPalette.greenDark,
                      size: 25,
                    ),
                  ),
                  if (hasUnread)
                    Positioned(
                      right: -5,
                      top: -6,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: MarketPalette.red,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          chat.userUnreadCount > 9
                              ? '9+'
                              : '${chat.userUnreadCount}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isOrder ? 'Sipariş Desteği' : 'Genel Destek',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: MarketPalette.ink,
                              fontSize: 14,
                              fontWeight:
                                  hasUnread ? FontWeight.w800 : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isClosed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECEFED),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Kapalı',
                              style: GoogleFonts.inter(
                                color: MarketPalette.muted,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      chat.lastMessage.isEmpty
                          ? 'Yeni destek görüşmesi'
                          : chat.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color:
                            hasUnread ? MarketPalette.ink : MarketPalette.muted,
                        fontSize: 11,
                        fontWeight:
                            hasUnread ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatChatTime(chat.lastMessageAt),
                    style: GoogleFonts.inter(
                      color:
                          hasUnread ? MarketPalette.green : MarketPalette.muted,
                      fontSize: 9,
                      fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFB7C0BA),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatChatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'Şimdi';
    if (difference.inMinutes < 60) return '${difference.inMinutes} dk';
    if (difference.inHours < 24) return '${difference.inHours} sa';
    if (difference.inDays < 7) return '${difference.inDays} gün';
    return '${date.day}.${date.month}.${date.year}';
  }
}

class _EmptyChatState extends StatelessWidget {
  final bool isAvailable;
  final VoidCallback onStart;

  const _EmptyChatState({
    required this.isAvailable,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 55),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: MarketPalette.greenSoft,
                  borderRadius: BorderRadius.circular(42),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.forum_rounded,
                      color: MarketPalette.green,
                      size: 62,
                    ),
                    Positioned(
                      right: 20,
                      top: 20,
                      child: Container(
                        width: 25,
                        height: 25,
                        decoration: const BoxDecoration(
                          color: MarketPalette.lime,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: MarketPalette.greenDeep,
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 27),
              Text(
                'Nasıl yardımcı olabiliriz?',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: MarketPalette.ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.45,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Sorunu bize yaz, destek ekibimiz görüşme üzerinden seninle ilgilensin.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: MarketPalette.muted,
                  fontSize: 13,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _FeatureChip(
                    icon: Icons.verified_user_rounded,
                    label: 'Güvenli',
                  ),
                  SizedBox(width: 8),
                  _FeatureChip(
                    icon: Icons.history_rounded,
                    label: 'Kayıtlı',
                  ),
                  SizedBox(width: 8),
                  _FeatureChip(
                    icon: Icons.notifications_active_rounded,
                    label: 'Bildirimli',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(235, 56),
                  backgroundColor: isAvailable
                      ? MarketPalette.green
                      : const Color(0xFFB56A18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                  elevation: 0,
                ),
                icon: Icon(
                  isAvailable
                      ? Icons.add_comment_rounded
                      : Icons.schedule_rounded,
                ),
                label: Text(
                  isAvailable ? 'Sohbet Başlat' : 'Çalışma Saatlerini Gör',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: MarketPalette.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: MarketPalette.green, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: MarketPalette.muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatLoadingState extends StatelessWidget {
  const _ChatLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: MarketPalette.green),
          const SizedBox(height: 15),
          Text(
            'Görüşmeler yükleniyor...',
            style: GoogleFonts.inter(
              color: MarketPalette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartingChatDialog extends StatelessWidget {
  const _StartingChatDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            color: MarketPalette.green,
          ),
        ),
      ),
    );
  }
}
