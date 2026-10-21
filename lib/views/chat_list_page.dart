import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/chat_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import 'widgets/market_ui.dart';

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
      // Misafirin görüşmesi olmaz; giriş ekranına yönlendiren durum gösterilir
      if (!context.read<AuthViewModel>().isLoggedIn) return;
      context.read<ChatViewModel>().loadChats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthViewModel, bool>((a) => a.isLoggedIn);
    final gutter = MarketSpace.gutterOf(context);
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: Consumer2<ChatViewModel, SettingsViewModel>(
        builder: (context, chatViewModel, settings, _) {
          final chats = chatViewModel.chats;
          final hoursNotice = loggedIn && !settings.isWithinOrderHours
              ? Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 0),
                  child: MarketNotice.warning(
                    icon: Icons.schedule_rounded,
                    text: 'Şu an mesai dışındayız. Mesajını bırakabilirsin; ekibimiz '
                        'açılışta (${_hhmm(settings.orderStartHour, settings.orderStartMinute)}) yanıtlar.',
                  ),
                )
              : null;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: MarketScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: MarketHeader(
                  title: 'Canlı destek',
                  subtitle: 'Sorunu yaz, destek ekibi buradan yanıtlasın',
                  icon: Icons.support_agent_rounded,
                  compact: true,
                  actions: [
                    if (loggedIn)
                      MarketHeaderButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Yenile',
                        onTap: chatViewModel.loadChats,
                      ),
                  ],
                ),
              ),
              if (hoursNotice != null) SliverToBoxAdapter(child: hoursNotice),
              if (!loggedIn)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: MarketEmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Giriş yapman gerekiyor',
                    message: 'Destek ekibine yazmak için hesabına giriş yap.',
                    actionLabel: 'Giriş yap',
                    actionIcon: Icons.login_rounded,
                    onAction: () async {
                      final viewModel = context.read<ChatViewModel>();
                      final auth = context.read<AuthViewModel>();
                      await context.push('/login');
                      if (mounted && auth.isLoggedIn) viewModel.loadChats();
                    },
                  ),
                )
              else if (chatViewModel.isLoading && chats.isEmpty)
                const SliverToBoxAdapter(child: MarketListSkeleton())
              else if (chats.isEmpty && chatViewModel.error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: MarketEmptyState.error(
                    title: 'Görüşmeler yüklenemedi',
                    onRetry: chatViewModel.loadChats,
                  ),
                )
              else if (chats.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: MarketEmptyState(
                    icon: Icons.forum_rounded,
                    title: 'Nasıl yardımcı olabiliriz?',
                    message:
                        'Sorunu bize yaz, destek ekibimiz görüşme üzerinden seninle ilgilensin.',
                    actionLabel: 'Görüşme başlat',
                    actionIcon: Icons.add_comment_rounded,
                    onAction: () => _startNewChat(context),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 12),
                  sliver: SliverToBoxAdapter(
                    child: MarketSectionTitle(
                      title: 'Destek görüşmeleri',
                      dense: true,
                      count: chats.length,
                      countLabel: 'görüşme',
                    ),
                  ),
                ),
                SliverPadding(
                  // Alttaki "Yeni görüşme" butonu son kartı örtmesin
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 112),
                  sliver: SliverList.separated(
                    itemCount: chats.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final chat = chats[index];
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
          if (!loggedIn || viewModel.chats.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _startNewChat(context),
            backgroundColor: MarketPalette.green,
            foregroundColor: Colors.white,
            elevation: 3,
            icon: const Icon(Icons.add_comment_rounded, size: 20),
            label: const Text('Yeni görüşme'),
          );
        },
      ),
    );
  }

  static String _hhmm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  Future<void> _startNewChat(BuildContext context) async {
    final viewModel = context.read<ChatViewModel>();
    try {
      final chat = await runWithMarketProgress(
        context,
        message: 'Destek ekibine bağlanılıyor…',
        task: viewModel.startChat,
      );
      if (!context.mounted) return;

      if (chat != null) {
        context.push('/chat/${chat.id}');
      } else {
        _showError(viewModel.error ?? 'Görüşme başlatılamadı. Tekrar dene.');
      }
    } catch (error) {
      if (!context.mounted) return;
      _showError('Görüşme başlatılırken bir sorun oluştu. Tekrar dene.');
    }
  }

  void _showError(String message) {
    showMarketSnack(context, message, error: true);
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
        borderRadius: BorderRadius.circular(MarketRadius.lg),
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
            borderRadius: BorderRadius.circular(MarketRadius.lg),
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
                          ? MarketPalette.orangeSoft
                          : MarketPalette.greenSoft,
                      borderRadius: BorderRadius.circular(MarketRadius.md),
                    ),
                    child: Icon(
                      isOrder
                          ? Icons.shopping_bag_rounded
                          : Icons.support_agent_rounded,
                      color: isOrder
                          ? MarketPalette.orangeInk
                          : MarketPalette.greenDark,
                      size: 25,
                    ),
                  ),
                  if (hasUnread)
                    Positioned(
                      right: -5,
                      top: -6,
                      child: MarketCountBadge(count: chat.userUnreadCount),
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
                            isOrder ? 'Sipariş desteği' : 'Genel destek',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MarketText.label(size: 14, weight: hasUnread ? FontWeight.w800 : FontWeight.w700),
                          ),
                        ),
                        if (isClosed)
                          const MarketPill(
                            label: 'Kapalı',
                            background: MarketPalette.surfaceMuted,
                            foreground: MarketPalette.muted,
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
                      style: MarketText.body(color: hasUnread ? MarketPalette.ink : MarketPalette.muted, size: 13, weight: hasUnread ? FontWeight.w600 : FontWeight.w500),
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
                    style: MarketText.body(color: hasUnread ? MarketPalette.green : MarketPalette.muted, size: 12, weight: hasUnread ? FontWeight.w800 : FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: MarketPalette.subtle,
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
    return formatTrDateTime(date, withTime: false);
  }
}
