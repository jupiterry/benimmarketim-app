import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/chat_model.dart';
import '../viewmodels/chat_viewmodel.dart';
import 'widgets/cart_proposal_card.dart';
import 'widgets/market_ui.dart';

class ChatDetailPage extends StatefulWidget {
  final String chatId;

  const ChatDetailPage({super.key, required this.chatId});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Timer? _typingTimer;
  ChatViewModel? _chatViewModel;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final viewModel = context.read<ChatViewModel>();
      _chatViewModel = viewModel;
      await viewModel.connectSocket();
      await _loadChatAndJoin(viewModel);
    });
  }

  Future<void> _loadChatAndJoin(ChatViewModel viewModel) async {
    if (viewModel.activeChat?.id == widget.chatId &&
        viewModel.messages.isNotEmpty) {
      return;
    }

    final chat = viewModel.chats.firstWhere(
      (item) => item.id == widget.chatId,
      orElse: () => ChatModel(
        id: widget.chatId,
        type: 'general',
        status: 'active',
        lastMessage: '',
        lastMessageAt: DateTime.now(),
        lastMessageSender: '',
        userUnreadCount: 0,
      ),
    );
    await viewModel.openChat(chat);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _chatViewModel?.closeActiveChat();
    super.dispose();
  }

  void _onMessageChanged() {
    final viewModel = _chatViewModel;
    if (viewModel == null) return;

    if (_messageController.text.trim().isEmpty) {
      viewModel.sendStopTyping();
      return;
    }

    viewModel.sendTyping();
    _typingTimer?.cancel();
    _typingTimer = Timer(
      const Duration(seconds: 2),
      viewModel.sendStopTyping,
    );
  }

  void _scheduleScrollToBottom(int messageCount) {
    if (messageCount == _lastMessageCount) return;
    _lastMessageCount = messageCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatViewModel>(
              builder: (context, viewModel, _) {
                if (viewModel.isLoading && viewModel.messages.isEmpty) {
                  return const _MessagesLoading();
                }
                if (viewModel.messages.isEmpty) {
                  return const _EmptyConversation();
                }

                _scheduleScrollToBottom(
                  viewModel.messages.length + (viewModel.isTyping ? 1 : 0),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                  itemCount:
                      viewModel.messages.length + (viewModel.isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == viewModel.messages.length) {
                      return const _TypingIndicator();
                    }

                    final message = viewModel.messages[index];
                    final showDate = index == 0 ||
                        !_isSameDay(
                          message.createdAt,
                          viewModel.messages[index - 1].createdAt,
                        );
                    return Column(
                      children: [
                        if (showDate) _DateDivider(date: message.createdAt),
                        _MessageBubble(message: message),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Consumer<ChatViewModel>(
            builder: (context, viewModel, _) {
              if (viewModel.activeChat?.status == 'closed') {
                return const _ClosedChatBar();
              }
              return _buildMessageInput(viewModel);
            },
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 76,
      backgroundColor: MarketPalette.greenDeep,
      surfaceTintColor: MarketPalette.greenDeep,
      elevation: 0,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Center(
          child: MarketHeaderButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Geri',
            onTap: () => context.pop(),
          ),
        ),
      ),
      titleSpacing: 10,
      title: Consumer<ChatViewModel>(
        builder: (context, viewModel, _) {
          final chat = viewModel.activeChat;
          final isClosed = chat?.status == 'closed';
          return Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MarketPalette.lime,
                  borderRadius: BorderRadius.circular(MarketRadius.md),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: MarketPalette.greenDeep,
                  size: 24,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat?.type == 'order'
                          ? 'Sipariş Desteği'
                          : 'Benim Marketim Asistanı',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MarketText.heading(color: Colors.white, size: 16),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: viewModel.isTyping
                                ? MarketPalette.orange
                                : isClosed
                                    ? MarketPalette.subtle
                                    : MarketPalette.lime,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          viewModel.isTyping
                              ? 'Yanıt yazılıyor...'
                              : isClosed
                                  ? 'Görüşme kapatıldı'
                                  : 'Destek görüşmesi açık',
                          style: MarketText.caption(color: Colors.white.withValues(alpha: .78), size: 12, weight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageInput(ChatViewModel viewModel) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        11,
        14,
        MediaQuery.paddingOf(context).bottom + 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: MarketPalette.line)),
        boxShadow: [
          BoxShadow(
            color: MarketPalette.ink.withValues(alpha: .06),
            blurRadius: 20,
            offset: const Offset(0, -7),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 37,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                '📦 Siparişim Nerede?',
                '🛒 Ürün Sor',
                '🎟 Kampanyalar',
                '🖨 Fotokopi',
                '👨‍💼 Canlı Destek',
              ]
                  .map((label) => Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ActionChip(
                          label: Text(
                            label,
                            style: MarketText.label(
                              color: MarketPalette.greenDark,
                              size: 12,
                            ),
                          ),
                          onPressed: viewModel.isSending
                              ? null
                              : () async {
                                  _messageController.clear();
                                  await viewModel.sendMessage(label);
                                },
                          backgroundColor: MarketPalette.greenSoft,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(MarketRadius.lg)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  decoration: BoxDecoration(
                    color: MarketPalette.canvas,
                    border: Border.all(color: MarketPalette.line),
                    borderRadius: BorderRadius.circular(MarketRadius.md),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    style: MarketText.body(),
                    decoration: InputDecoration(
                      hintText: 'Mesajını yaz...',
                      hintStyle: MarketText.body(color: MarketPalette.subtle),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: 'Mesajı gönder',
                child: Material(
                color: viewModel.isSending
                    ? MarketPalette.subtle
                    : MarketPalette.green,
                borderRadius: BorderRadius.circular(MarketRadius.md),
                child: InkWell(
                  onTap: viewModel.isSending
                      ? null
                      : () => _sendMessage(viewModel),
                  borderRadius: BorderRadius.circular(MarketRadius.md),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: viewModel.isSending
                        ? const Padding(
                            padding: EdgeInsets.all(17),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 23,
                          ),
                  ),
                ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(ChatViewModel viewModel) async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    viewModel.sendStopTyping();
    final success = await viewModel.sendMessage(content);
    if (!mounted || success) return;

    showMarketSnack(
      context,
      'Mesaj gönderilemedi. Tekrar deneyebilirsin.',
      error: true,
    );
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == 'user';
    final isSystem = message.type == 'system';

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: MarketPalette.fill,
              borderRadius: BorderRadius.circular(MarketRadius.sm),
            ),
            child: Text(
              message.content,
              textAlign: TextAlign.center,
              style: MarketText.caption(size: 12, weight: FontWeight.w600),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 58 : 0,
        right: isUser ? 0 : 58,
        bottom: 10,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: MarketPalette.greenSoft,
                borderRadius: BorderRadius.circular(MarketRadius.sm),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: MarketPalette.greenDark,
                size: 18,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 8),
              decoration: BoxDecoration(
                color: isUser ? MarketPalette.greenDark : Colors.white,
                border: isUser ? null : Border.all(color: MarketPalette.line),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(MarketRadius.lg),
                  topRight: const Radius.circular(MarketRadius.lg),
                  bottomLeft: Radius.circular(isUser ? 19 : 5),
                  bottomRight: Radius.circular(isUser ? 5 : 19),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser && message.senderName.isNotEmpty) ...[
                    Text(
                      message.senderName,
                      style: MarketText.label(color: MarketPalette.green, size: 11, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message.content,
                    style: MarketText.body(color: isUser ? Colors.white : MarketPalette.ink, size: 13, height: 1.42),
                  ),
                  if (!isUser && message.cartProposal != null)
                    CartProposalCard(
                      key: ValueKey('cart-${message.id}'),
                      proposal: message.cartProposal!,
                    ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: MarketText.caption(color: isUser ? Colors.white.withValues(alpha: .8) : MarketPalette.muted, size: 11),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 13,
                          color: message.isRead
                              ? const Color(0xFF9DDCFF)
                              : Colors.white.withValues(alpha: .62),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;

  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final text = _sameDay(date, now)
        ? 'Bugün'
        : _sameDay(date, yesterday)
            ? 'Dün'
            : '${date.day}.${date.month}.${date.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: MarketPalette.fill,
            borderRadius: BorderRadius.circular(MarketRadius.sm),
          ),
          child: Text(
            text,
            style: MarketText.label(color: MarketPalette.muted, size: 11),
          ),
        ),
      ),
    );
  }

  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: MarketPalette.greenSoft,
              borderRadius: BorderRadius.circular(MarketRadius.sm),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: MarketPalette.greenDark,
              size: 18,
            ),
          ),
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: MarketPalette.line),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(MarketRadius.lg),
                topRight: Radius.circular(MarketRadius.lg),
                bottomRight: Radius.circular(MarketRadius.lg),
                bottomLeft: Radius.circular(5),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(delay: 0),
                SizedBox(width: 4),
                _TypingDot(delay: 130),
                SizedBox(width: 4),
                _TypingDot(delay: 260),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _animation = Tween<double>(begin: .35, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      // "Hareketi azalt" açıksa noktalar sabit kalır.
      if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
      _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: MarketPalette.muted,
          shape: BoxShape.circle,
        ),
        child: SizedBox(width: 7, height: 7),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                color: MarketPalette.greenSoft,
                borderRadius: BorderRadius.circular(MarketRadius.xl),
              ),
              child: const Icon(
                Icons.waving_hand_rounded,
                color: MarketPalette.green,
                size: 43,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Sohbeti başlat',
              style: MarketText.title(size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'Sorunu veya merak ettiğin konuyu aşağıya yaz. Destek ekibimiz buradan yanıtlasın.',
              textAlign: TextAlign.center,
              style: MarketText.body(color: MarketPalette.muted, size: 12, weight: FontWeight.w400, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagesLoading extends StatelessWidget {
  const _MessagesLoading();

  @override
  Widget build(BuildContext context) {
    return const MarketSkeletonPulse(
      semanticLabel: 'Mesajlar yükleniyor',
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: MarketSkeleton(width: 220, height: 54, radius: MarketRadius.lg),
            ),
            SizedBox(height: MarketSpace.md),
            Align(
              alignment: Alignment.centerRight,
              child: MarketSkeleton(width: 170, height: 42, radius: MarketRadius.lg),
            ),
            SizedBox(height: MarketSpace.md),
            Align(
              alignment: Alignment.centerLeft,
              child: MarketSkeleton(width: 250, height: 70, radius: MarketRadius.lg),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosedChatBar extends StatelessWidget {
  const _ClosedChatBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: const BoxDecoration(
          color: MarketPalette.fill,
          border: Border(top: BorderSide(color: MarketPalette.line)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              color: MarketPalette.muted,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Bu destek görüşmesi kapatılmış',
              style: MarketText.label(color: MarketPalette.muted, size: 11),
            ),
          ],
        ),
      ),
    );
  }
}
