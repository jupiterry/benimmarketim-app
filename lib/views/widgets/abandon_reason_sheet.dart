import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'feedback_parts.dart';
import 'market_ui.dart';

// Sunucudaki ABANDON_REASONS ile aynı kimlikler (backend/lib/feedbackOptions.js)
const _reasons = [
  FeedbackOption('fiyat', 'Fiyatlar yüksek'),
  FeedbackOption('teslimat', 'Teslimat süresi uzun'),
  FeedbackOption('urun_yok', 'Aradığım ürün yok'),
  FeedbackOption('minimum', 'Minimum sepet tutarı yüksek'),
  FeedbackOption('sonra', 'Sonra sipariş vereceğim'),
  FeedbackOption('diger', 'Diğer'),
];
const _interval = Duration(days: 7);

/// Sepetini boşaltan müşteriye tek soru: "Neden vazgeçtin?".
/// Haftada en fazla bir kez, yalnızca giriş yapmış kullanıcıya sorulur.
Future<void> maybeAskAbandonReason(BuildContext context) async {
  final auth = context.read<AuthViewModel>();
  final userId = auth.user?.id;
  if (!auth.isLoggedIn || userId == null || userId.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  final key = 'abandon_asked_$userId';
  final last = prefs.getInt(key) ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch;
  if (now - last < _interval.inMilliseconds) return;
  await prefs.setInt(key, now);
  if (!context.mounted) return;
  await showFeedbackSheet<void>(context, const _AbandonReasonSheet());
}

class _AbandonReasonSheet extends StatefulWidget {
  const _AbandonReasonSheet();

  @override
  State<_AbandonReasonSheet> createState() => _AbandonReasonSheetState();
}

class _AbandonReasonSheetState extends State<_AbandonReasonSheet> {
  bool _sent = false;

  Future<void> _pick(String reason) async {
    setState(() => _sent = true);
    // Yanıt beklenmeden teşekkür edilir; gönderim hatası kullanıcıyı ilgilendirmez
    unawaited(ApiService().submitAbandonReason(reason: reason));
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FeedbackSheetHandle(),
        if (_sent) ...[
          const Center(
            child: MarketIconTile(
              icon: Icons.favorite_rounded,
              size: 52,
              background: MarketPalette.greenSoft,
              foreground: MarketPalette.green,
            ),
          ),
          const SizedBox(height: MarketSpace.md),
          Text('Teşekkürler, not aldık!', textAlign: TextAlign.center, style: MarketText.title(size: 20)),
          const SizedBox(height: MarketSpace.xl),
        ] else ...[
          Text('Neden vazgeçtin?', style: MarketText.title(size: 20)),
          const SizedBox(height: MarketSpace.sm),
          Text('Tek dokunuş yeter; daha iyisini yapmamıza yardım eder.',
              style: MarketText.body(color: MarketPalette.muted)),
          const SizedBox(height: MarketSpace.lg),
          Wrap(
            spacing: MarketSpace.sm,
            runSpacing: MarketSpace.sm,
            children: [
              for (final reason in _reasons)
                FeedbackChip(label: reason.label, selected: false, onTap: () => _pick(reason.id)),
            ],
          ),
          const SizedBox(height: MarketSpace.md),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Geç'),
          ),
        ],
      ],
    );
  }
}
