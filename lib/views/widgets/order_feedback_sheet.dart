import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/review_service.dart';
import 'market_ui.dart';

/// Sipariş sonrası deneyim anketi. Gönderildiyse true döner.
Future<bool> showOrderFeedbackSheet(
  BuildContext context, {
  required int milestone,
  String? orderId,
}) async {
  var submitted = false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MarketPalette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(MarketRadius.xl)),
    ),
    builder: (_) => _OrderFeedbackSheet(
      milestone: milestone,
      orderId: orderId,
      onSubmitted: () => submitted = true,
    ),
  );
  return result ?? submitted;
}

class _FeedbackTag {
  final String id;
  final String label;
  const _FeedbackTag(this.id, this.label);
}

// Sunucudaki FEEDBACK_TAGS listesiyle aynı kimlikler
const _positiveTags = [
  _FeedbackTag('hizli', 'Hızlı geldi'),
  _FeedbackTag('taze', 'Ürünler tazeydi'),
  _FeedbackTag('kurye', 'Kurye nazikti'),
  _FeedbackTag('fiyat', 'Fiyatlar uygundu'),
  _FeedbackTag('kolay', 'Uygulama kolaydı'),
];
const _negativeTags = [
  _FeedbackTag('gec', 'Geç geldi'),
  _FeedbackTag('eksik', 'Eksik ürün vardı'),
  _FeedbackTag('yanlis', 'Yanlış ürün geldi'),
  _FeedbackTag('bozuk', 'Ürün bozuk/ezikti'),
  _FeedbackTag('pahali', 'Fiyatlar yüksekti'),
  _FeedbackTag('uygulama', 'Uygulamada sorun yaşadım'),
];
const _ratingLabels = ['', 'Çok kötü', 'Kötü', 'İdare eder', 'İyi', 'Harika'];
const _lowRating = 3; // Bu puan ve altında açıklama zorunludur
const _minComment = 5;

class _OrderFeedbackSheet extends StatefulWidget {
  final int milestone;
  final String? orderId;
  final VoidCallback onSubmitted;

  const _OrderFeedbackSheet({
    required this.milestone,
    required this.onSubmitted,
    this.orderId,
  });

  @override
  State<_OrderFeedbackSheet> createState() => _OrderFeedbackSheetState();
}

class _OrderFeedbackSheetState extends State<_OrderFeedbackSheet> {
  final ApiService _apiService = ApiService();
  final TextEditingController _comment = TextEditingController();
  final Set<String> _selectedTags = {};
  int _rating = 0;
  bool _sending = false;
  bool _done = false;
  String? _error;

  bool get _isLow => _rating > 0 && _rating <= _lowRating;

  String get _title {
    switch (widget.milestone) {
      case 1:
        return 'İlk siparişin nasıldı?';
      case 5:
        return '5 sipariş oldu! Nasıl gidiyor?';
      default:
        return '15. siparişin de tamam. Bizi nasıl buluyorsun?';
    }
  }

  String get _subtitle {
    switch (widget.milestone) {
      case 1:
        return 'İlk deneyimin bizim için çok değerli. 10 saniyeni ayırır mısın?';
      case 5:
        return 'Bizi düzenli kullanan biri olarak fikrini merak ediyoruz.';
      default:
        return 'En sadık müşterilerimizdensin. Neyi daha iyi yapabiliriz?';
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _setRating(int value) {
    setState(() {
      // Olumlu ve olumsuz seçenekler farklı olduğu için taraf değişince seçim sıfırlanır
      final wasLow = _isLow;
      _rating = value;
      if (wasLow != _isLow) _selectedTags.clear();
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_sending) return;
    final comment = _comment.text.trim();
    if (_rating == 0) {
      setState(() => _error = 'Lütfen bir puan seç.');
      return;
    }
    if (_isLow && comment.length < _minComment) {
      setState(() => _error = 'Neyi daha iyi yapabileceğimizi kısaca yazar mısın?');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await _apiService.submitOrderFeedback(
      rating: _rating,
      milestone: widget.milestone,
      tags: _selectedTags.toList(),
      comment: comment,
      orderId: widget.orderId,
    );
    if (error == null) widget.onSubmitted();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = error;
      _done = error == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          MarketSpace.xl,
          MarketSpace.md,
          MarketSpace.xl,
          MarketSpace.xl + bottomInset,
        ),
        child: SingleChildScrollView(
          child: _done ? _buildThanks(context) : _buildForm(context),
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          width: 44,
          height: 5,
          margin: const EdgeInsets.only(bottom: MarketSpace.lg),
          decoration: BoxDecoration(
            color: MarketPalette.lineStrong,
            borderRadius: BorderRadius.circular(MarketRadius.pill),
          ),
        ),
      );

  Widget _buildForm(BuildContext context) {
    final tags = _isLow ? _negativeTags : _positiveTags;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _handle(),
        Text(_title, style: MarketText.title()),
        const SizedBox(height: MarketSpace.sm),
        Text(_subtitle, style: MarketText.body(color: MarketPalette.muted)),
        const SizedBox(height: MarketSpace.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                onPressed: _sending ? null : () => _setRating(star),
                iconSize: 44,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                tooltip: '$star yıldız',
                icon: Icon(
                  star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: star <= _rating ? MarketPalette.orange : MarketPalette.lineStrong,
                ),
              ),
          ],
        ),
        SizedBox(
          height: 22,
          child: Center(
            child: Text(
              _ratingLabels[_rating],
              style: MarketText.label(color: MarketPalette.inkSoft),
            ),
          ),
        ),
        if (_rating > 0) ...[
          const SizedBox(height: MarketSpace.lg),
          Text(
            _isLow ? 'Ne ters gitti?' : 'En çok neyi beğendin?',
            style: MarketText.heading(size: 15),
          ),
          const SizedBox(height: MarketSpace.md),
          Wrap(
            spacing: MarketSpace.sm,
            runSpacing: MarketSpace.sm,
            children: [
              for (final tag in tags)
                _TagChip(
                  label: tag.label,
                  selected: _selectedTags.contains(tag.id),
                  onTap: _sending
                      ? null
                      : () => setState(() {
                            if (!_selectedTags.remove(tag.id)) {
                              _selectedTags.add(tag.id);
                            }
                          }),
                ),
            ],
          ),
          const SizedBox(height: MarketSpace.lg),
          TextField(
            controller: _comment,
            enabled: !_sending,
            maxLines: 3,
            maxLength: 1000,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: _isLow
                  ? 'Ne olduğunu kısaca yazar mısın? (zorunlu)'
                  : 'Eklemek istediğin bir şey var mı? (isteğe bağlı)',
              counterText: '',
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: MarketSpace.md),
          Text(_error!, style: MarketText.label(color: MarketPalette.red)),
        ],
        const SizedBox(height: MarketSpace.xl),
        FilledButton(
          onPressed: _sending ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: Text(_sending ? 'Gönderiliyor…' : 'Gönder'),
        ),
        const SizedBox(height: MarketSpace.sm),
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Sonra'),
        ),
      ],
    );
  }

  Widget _buildThanks(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _handle(),
        const Center(
          child: MarketIconTile(
            icon: Icons.favorite_rounded,
            size: 60,
            background: MarketPalette.greenSoft,
            foreground: MarketPalette.green,
          ),
        ),
        const SizedBox(height: MarketSpace.lg),
        Text('Teşekkürler!', textAlign: TextAlign.center, style: MarketText.title()),
        const SizedBox(height: MarketSpace.sm),
        Text(
          _isLow
              ? 'Yazdıklarını ekibimiz okuyacak ve gerekirse seninle iletişime geçecek.'
              : 'Görüşün bize ulaştı. Daha iyisini yapmak için kullanacağız.',
          textAlign: TextAlign.center,
          style: MarketText.body(color: MarketPalette.muted),
        ),
        const SizedBox(height: MarketSpace.xl),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: const Text('Tamam'),
        ),
        const SizedBox(height: MarketSpace.sm),
        // Verilen puandan bağımsız olarak herkese gösterilir
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).pop(true);
            ReviewService.instance.openStoreListing();
          },
          icon: const Icon(Icons.star_outline_rounded),
          label: const Text('Mağazada da puan ver'),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _TagChip({required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? MarketPalette.greenSoft : MarketPalette.surfaceMuted,
      borderRadius: BorderRadius.circular(MarketRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MarketRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MarketRadius.pill),
            border: Border.all(
              color: selected ? MarketPalette.green : MarketPalette.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: MarketText.label(
              color: selected ? MarketPalette.greenDark : MarketPalette.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}
