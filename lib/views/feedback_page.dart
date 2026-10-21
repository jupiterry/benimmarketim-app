import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'widgets/feedback_parts.dart';
import 'widgets/market_mascot.dart';
import 'widgets/market_ui.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _ratingKey = GlobalKey();
  int _rating = 0;
  bool _ratingMissing = false;
  bool _isSubmitting = false;

  /// Yönetici yanıtı ya da telafi kuponu olan önceki geri bildirimler
  List<Map<String, dynamic>> _answered = [];
  bool _loadingAnswered = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnswered());
  }

  Future<void> _loadAnswered() async {
    if (!context.read<AuthViewModel>().isLoggedIn) {
      if (mounted) setState(() => _loadingAnswered = false);
      return;
    }
    final items = await ApiService().getMyFeedbacks();
    if (!mounted) return;
    setState(() {
      _loadingAnswered = false;
      _answered = items.where((item) {
        final reply = item['adminReply'];
        final comp = item['compensation'];
        return (reply is Map && (reply['text'] ?? '').toString().trim().isNotEmpty) ||
            (comp is Map && (comp['code'] ?? '').toString().isNotEmpty);
      }).take(5).toList();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final formValid = _formKey.currentState!.validate();
    final ratingMissing = _rating == 0;
    if (!formValid || ratingMissing) {
      HapticFeedback.mediumImpact();
      setState(() => _ratingMissing = ratingMissing);
      if (ratingMissing && _ratingKey.currentContext != null) {
        Scrollable.ensureVisible(
          _ratingKey.currentContext!,
          duration: feedbackMotion(context, const Duration(milliseconds: 300)),
          curve: Curves.easeOutCubic,
          alignment: .1,
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // Önceden yalnızca bekleme simüle ediliyordu; artık sunucuya gönderilir.
      await ApiService().createFeedback(
        rating: _rating,
        ratings: {'overall': _rating},
        title: 'Genel Değerlendirme',
        message: _messageController.text.trim(),
        category: 'Genel',
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      showMarketSnack(context, 'Geri bildirimin için teşekkürler!');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final text = e.toString();
      showMarketSnack(
        context,
        text.startsWith('Exception: ')
            ? text.replaceFirst('Exception: ', '')
            : 'Geri bildirim gönderilemedi. Lütfen tekrar dene.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthViewModel, bool>((a) => a.isLoggedIn);

    return Scaffold(
      backgroundColor: MarketPalette.canvas,
      body: ListView(
        padding: EdgeInsets.zero,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const MarketHeader(
            title: 'Geri bildirim',
            subtitle: 'Görüşlerin Benim Marketim\'i daha iyi yapıyor',
            icon: Icons.rate_review_rounded,
            compact: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
            child: !loggedIn
                ? MarketCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Önce giriş yap', style: MarketText.title(size: 22)),
                        const SizedBox(height: 6),
                        Text(
                          'Geri bildirimini hesabınla ilişkilendirebilmemiz için giriş yapman gerekiyor.',
                          style: MarketText.body(color: MarketPalette.muted, size: 14),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.push('/login'),
                          child: const Text('Giriş yap'),
                        ),
                      ],
                    ),
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MarketCard(
                          key: _ratingKey,
                          borderColor: _ratingMissing ? MarketPalette.red : MarketPalette.line,
                          child: Column(
                            children: [
                              Semantics(
                                header: true,
                                child: Text('Deneyimini nasıl değerlendirirsin?',
                                    textAlign: TextAlign.center,
                                    style: MarketText.heading(size: 16)),
                              ),
                              const SizedBox(height: MarketSpace.sm),
                              FeedbackStars(
                                value: _rating,
                                size: 40,
                                onChanged: _isSubmitting
                                    ? null
                                    : (value) => setState(() {
                                          _rating = value;
                                          _ratingMissing = false;
                                        }),
                              ),
                              if (_ratingMissing) ...[
                                const SizedBox(height: MarketSpace.sm),
                                const FeedbackFieldError('Bir puan seç'),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        MarketCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text('Mesajın', style: MarketText.heading(size: 16)),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _messageController,
                                enabled: !_isSubmitting,
                                style: MarketText.body(size: 14),
                                textCapitalization: TextCapitalization.sentences,
                                // Klavye açılınca "Gönder" de görünsün
                                scrollPadding: const EdgeInsets.only(bottom: 120),
                                decoration: const InputDecoration(
                                  hintText: 'Neyi sevdin, neyi geliştirelim?',
                                  fillColor: MarketPalette.canvas,
                                ),
                                minLines: 5,
                                maxLines: 8,
                                maxLength: 500,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Lütfen bir mesaj yaz';
                                  }
                                  if (value.trim().length < 10) {
                                    return 'Mesajın en az 10 karakter olmalı';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        FeedbackSubmitButton(
                          busy: _isSubmitting,
                          onPressed: _submitFeedback,
                        ),
                        ..._buildHistory(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Önceki geri bildirimler formun ALTINDA: yüklenince form yerinden oynamaz.
  List<Widget> _buildHistory() {
    if (!_loadingAnswered && _answered.isEmpty) return const [];
    return [
      const SizedBox(height: MarketSpace.section),
      Semantics(
        header: true,
        child: Text('Önceki geri bildirimlerin', style: MarketText.heading(size: 18)),
      ),
      const SizedBox(height: 4),
      Text('Ekibimizin yanıtları ve telafi kuponların', style: MarketText.caption()),
      const SizedBox(height: MarketSpace.md),
      if (_loadingAnswered)
        const MarketSkeletonPulse(
          child: Column(
            children: [
              MarketSkeleton(height: 96, radius: MarketRadius.lg),
              SizedBox(height: 10),
              MarketSkeleton(height: 96, radius: MarketRadius.lg),
            ],
          ),
        )
      else
        for (final item in _answered) _AnsweredFeedbackCard(item: item),
    ];
  }
}

/// Önceki geri bildirim + yönetici yanıtı (+ varsa telafi kuponu)
class _AnsweredFeedbackCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _AnsweredFeedbackCard({required this.item});

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.selectionClick();
    showMarketSnack(context, 'Kupon kodu kopyalandı', icon: Icons.copy_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final reply = item['adminReply'] is Map ? item['adminReply'] as Map : const {};
    final replyText = (reply['text'] ?? '').toString().trim();
    final comp = item['compensation'] is Map ? item['compensation'] as Map : const {};
    final code = (comp['code'] ?? '').toString();
    final amount = (comp['amount'] as num?) ?? 0;
    final message = (item['message'] ?? '').toString().trim();
    final title = (item['title'] ?? '').toString().trim();
    final rating = (item['rating'] as num?)?.toInt() ?? 0;
    final created = DateTime.tryParse((item['createdAt'] ?? '').toString());
    final date = created == null ? '' : formatTrDateTime(created, withTime: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MarketCard(
        shadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.isEmpty ? 'Geri bildirim' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MarketText.label(size: 13, color: MarketPalette.inkSoft),
                  ),
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(width: MarketSpace.sm),
                  Text(date, style: MarketText.caption()),
                ],
              ],
            ),
            if (rating > 0) ...[
              const SizedBox(height: 4),
              Semantics(
                label: '5 üzerinden $rating yıldız',
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      for (var star = 1; star <= 5; star++)
                        Icon(
                          star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 14,
                          color: star <= rating ? MarketPalette.orange : MarketPalette.subtle,
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: MarketText.body(size: 13)),
            ],
            if (replyText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MarketPalette.greenSoft,
                  borderRadius: BorderRadius.circular(MarketRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const ExcludeSemantics(child: MarketMascot(size: 22)),
                        const SizedBox(width: 6),
                        Text('Benim Marketim', style: MarketText.label(color: MarketPalette.greenDark, size: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(replyText, style: MarketText.body(size: 14)),
                  ],
                ),
              ),
            ],
            if (code.isNotEmpty) ...[
              const SizedBox(height: 10),
              _CompensationCoupon(
                code: code,
                amount: amount,
                onCopy: () => _copyCode(context, code),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Telafi kuponu: tutar, kod ve "Kopyala".
class _CompensationCoupon extends StatelessWidget {
  final String code;
  final num amount;
  final VoidCallback onCopy;

  const _CompensationCoupon({required this.code, required this.amount, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: MarketPalette.orangeSoft,
        borderRadius: BorderRadius.circular(MarketRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: MarketPalette.orangeInk, size: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amount > 0 ? '${formatTlShort(amount)} telafi kuponun hazır' : 'Telafi kuponun hazır',
                  style: MarketText.label(color: MarketPalette.orangeInk, size: 13),
                ),
                const SizedBox(height: 2),
                Text(code, style: MarketText.code(color: MarketPalette.ink, size: 14)),
                const SizedBox(height: 2),
                Text('Sepette kupon olarak kullanabilirsin.',
                    style: MarketText.caption(color: MarketPalette.orangeInk)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onCopy,
            style: TextButton.styleFrom(
              foregroundColor: MarketPalette.orangeInk,
              minimumSize: const Size(0, MarketSize.tapTarget),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text('Kopyala', semanticsLabel: 'Kupon kodunu kopyala: $code'),
          ),
        ],
      ),
    );
  }
}
