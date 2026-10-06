import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'widgets/market_ui.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;

  static const _ratingTexts = ['Çok kötü', 'Kötü', 'Orta', 'İyi', 'Mükemmel'];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rating == 0) {
      showMarketSnack(context, 'Lütfen bir puan ver', error: true);
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
                          child: Column(
                            children: [
                              Text('Deneyimini nasıl değerlendirirsin?',
                                  textAlign: TextAlign.center,
                                  style: MarketText.heading(size: 16)),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (index) {
                                  final selected = index < _rating;
                                  return IconButton(
                                    tooltip: _ratingTexts[index],
                                    iconSize: 40,
                                    onPressed: () => setState(() => _rating = index + 1),
                                    icon: Icon(
                                      selected ? Icons.star_rounded : Icons.star_outline_rounded,
                                      color: selected
                                          ? MarketPalette.orange
                                          : MarketPalette.lineStrong,
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _rating == 0
                                    ? 'Puan vermek için yıldızlara dokun'
                                    : _ratingTexts[_rating - 1],
                                style: MarketText.label(
                                  color: _rating == 0
                                      ? MarketPalette.muted
                                      : MarketPalette.orangeInk,
                                  size: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        MarketCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mesajın', style: MarketText.heading(size: 16)),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _messageController,
                                style: MarketText.body(size: 14),
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
                        FilledButton(
                          onPressed: _isSubmitting ? null : _submitFeedback,
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Gönder'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
