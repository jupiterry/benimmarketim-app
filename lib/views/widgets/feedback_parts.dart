import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/meta_app_events_service.dart';
import '../../services/image_url.dart';
import '../../services/review_service.dart';
import '../../viewmodels/referral_viewmodel.dart';
import 'custom_dialog.dart';
import 'market_ui.dart';

// Geri bildirim ekranlarında (detaylı anket, hızlı 👍/👎, tavsiye sorusu, ilk
// sipariş puanı, /feedback sayfası) ortak parçalar.
// Seçenek kimlikleri sunucudaki backend/lib/feedbackOptions.js ile aynıdır.
//
// Alt sayfalar uygulamanın ortak iskeletini kullanır (market_sheet.dart):
// soru adımları sola hizalı MarketSheetHeader + MarketSheetScaffold, teşekkür
// adımı ortalı [FeedbackThanks]. Ertelemek her yerde "Şimdi değil", bilgi
// kapatmak "Kapat", sayfa içinde geri dönmek başlıktaki geri okudur.

class FeedbackOption {
  final String id;
  final String label;
  const FeedbackOption(this.id, this.label);
}

const feedbackPositiveTags = [
  FeedbackOption('hizli', 'Hızlı geldi'),
  FeedbackOption('taze', 'Ürünler tazeydi'),
  FeedbackOption('kurye', 'Kurye nazikti'),
  FeedbackOption('fiyat', 'Fiyatlar uygundu'),
  FeedbackOption('kolay', 'Uygulama kolaydı'),
];

const feedbackNegativeTags = [
  FeedbackOption('gec', 'Geç geldi'),
  FeedbackOption('eksik', 'Eksik ürün vardı'),
  FeedbackOption('yanlis', 'Yanlış ürün geldi'),
  FeedbackOption('bozuk', 'Ürün bozuk/ezikti'),
  FeedbackOption('kurye_kotu', 'Kurye ilgisizdi'),
  FeedbackOption('paket', 'Paketleme kötüydü'),
  FeedbackOption('pahali', 'Fiyatlar yüksekti'),
  FeedbackOption('uygulama', 'Uygulamada sorun yaşadım'),
];

/// Ürün bazında sorun türleri
const feedbackIssueTypes = [
  FeedbackOption('bozuk', 'Bozuk'),
  FeedbackOption('eksik', 'Eksik'),
  FeedbackOption('yanlis', 'Yanlış'),
];

/// Bu etiketlerden biri seçilince siparişteki ürünler listelenir
const feedbackProductTags = {'eksik', 'yanlis', 'bozuk'};

/// Yıldız puanlarının tek etiket seti (anket, ilk sipariş kartı, /feedback).
/// 0 "puan yok" demektir.
const feedbackRatingLabels = ['', 'Çok kötü', 'Kötü', 'İdare eder', 'İyi', 'Harika'];

/// Seçilen etiketlerden ürün sorunu türü: en son seçilen ürün etiketi
/// (eksik / yanlis / bozuk), yoksa "bozuk".
String feedbackDefaultIssue(Iterable<String> tags) {
  var issue = 'bozuk';
  for (final tag in tags) {
    if (feedbackProductTags.contains(tag)) issue = tag;
  }
  return issue;
}

/// Hareket azaltma açıksa animasyon süresi sıfırdır.
Duration feedbackMotion(BuildContext context,
    [Duration duration = const Duration(milliseconds: 220)]) {
  return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Kısa ekran (ör. 320 × 568): sabit başlık alanı küçük tutulur (alt yazı
/// gösterilmez), sorulara daha çok yer kalır.
bool feedbackShortScreen(BuildContext context) => MediaQuery.sizeOf(context).height < 640;

/// Klavye açık ve üstünde az yer kalmış mı (ör. 320 × 568'de ~315 pt). O zaman
/// form sayfalarının başlığı sabit durmaz, içerikle birlikte kayar
/// ([FeedbackFormScaffold]).
bool feedbackTypingCompact(BuildContext context) {
  final keyboard = MediaQuery.viewInsetsOf(context).bottom;
  return keyboard > 0 && MediaQuery.sizeOf(context).height - keyboard < 560;
}

/// Soru adımlarının alt sayfa iskeleti ([MarketSheetScaffold] + başlık).
///
/// Normalde başlık üstte sabittir. Klavye açıkken yer darsa
/// ([feedbackTypingCompact]) başlık kaydırılan gövdenin başına geçer; böylece
/// tutamak ile sabit alt kısım arasındaki alanın tamamı yazılan alana, sayacına
/// ve hata metnine kalır. Gövde ağaçta hep aynı yerde durur (odak ve klavye
/// kaybolmaz); yalnızca başlığın yeri değişir.
class FeedbackFormScaffold extends StatelessWidget {
  final Widget header;
  final Widget body;
  final Widget? footer;
  final bool busy;

  const FeedbackFormScaffold({
    super.key,
    required this.header,
    required this.body,
    this.footer,
    this.busy = false,
  });

  // MarketSheetScaffold'un varsayılan gövde boşluğu (20, 0, 20, 20)
  static const double _side = 20;
  static const double _bottom = 20;

  @override
  Widget build(BuildContext context) {
    final inline = feedbackTypingCompact(context);
    return MarketSheetScaffold(
      busy: busy,
      header: inline ? null : header,
      // Yan boşluk gövdeye verilir: satır içi başlık kendi boşluğunu kullanır
      bodyPadding: const EdgeInsets.only(bottom: _bottom),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inline) header,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _side),
            child: body,
          ),
        ],
      ),
      footer: footer,
    );
  }
}

/// Adım ve bölüm geçişleri için yumuşak boy değişimi.
class FeedbackReveal extends StatelessWidget {
  final Widget child;
  const FeedbackReveal({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: feedbackMotion(context),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

/// Sunucunun gönderdiği sipariş özeti (GET /feedback/prompt → order / quick)
class FeedbackOrder {
  final String orderId;
  final String shortId;
  final String deliveryPointName;
  final List<FeedbackOrderProduct> products;

  const FeedbackOrder({
    required this.orderId,
    required this.shortId,
    required this.deliveryPointName,
    required this.products,
  });

  static FeedbackOrder? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['orderId'];
    if (id is! String || id.isEmpty) return null;
    final products = json['products'] is List
        ? (json['products'] as List)
            .whereType<Map>()
            .map((item) => FeedbackOrderProduct(
                  productId: item['productId'] is String ? item['productId'] as String : null,
                  name: (item['name'] ?? '').toString(),
                  image: item['image'] is String ? item['image'] as String : null,
                  quantity: (item['quantity'] as num?)?.toInt() ?? 0,
                ))
            .where((item) => item.name.isNotEmpty)
            .toList()
        : <FeedbackOrderProduct>[];
    return FeedbackOrder(
      orderId: id,
      shortId: (json['shortId'] ?? '').toString(),
      deliveryPointName: (json['deliveryPointName'] ?? '').toString(),
      products: products,
    );
  }

  /// "#B7K2Q · 4 ürün · Kız KYK Yurdu"
  String get summary => [
        if (shortId.isNotEmpty) '#$shortId',
        '${products.length} ürün',
        if (deliveryPointName.isNotEmpty) deliveryPointName,
      ].join(' · ');
}

class FeedbackOrderProduct {
  final String? productId;
  final String name;
  final String? image;
  final int quantity;

  const FeedbackOrderProduct({
    required this.productId,
    required this.name,
    required this.image,
    required this.quantity,
  });

  String get key => productId ?? name;
}

/// Alt sayfa başlığının üstündeki sipariş hapı (MarketSheetHeader.meta).
class FeedbackOrderPill extends StatelessWidget {
  final FeedbackOrder order;
  const FeedbackOrderPill({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sipariş ${order.summary}',
      child: ExcludeSemantics(
        child: MarketPill(icon: Icons.receipt_long_rounded, label: order.summary),
      ),
    );
  }
}

/// Seçilebilir hap. Uygulamanın ortak çipidir (MarketChip): 48 pt dokunma
/// alanı, seçiliyken ✓ ve ekran okuyucuya "seçili" bilgisi.
/// [negative] seçiliyken kırmızı tonu kullanır.
class FeedbackChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool negative;

  const FeedbackChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.negative = false,
  });

  @override
  Widget build(BuildContext context) {
    return MarketChip(
      label: label,
      selected: selected,
      tone: negative ? MarketChipTone.danger : MarketChipTone.neutral,
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
    );
  }
}

/// Çip listesi aralıkları (çipin kendi 4 pt'lik üst/alt dokunma payı dahil).
class FeedbackChipWrap extends StatelessWidget {
  final List<Widget> children;
  const FeedbackChipWrap({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: MarketSpace.sm, runSpacing: 2, children: children);
  }
}

/// Yıldız satırı. Her yıldız 48 × 48 dokunma alanıdır (5 yıldız 240 pt; 320
/// pt'lik telefonlara sığar). Boş yıldız [MarketPalette.subtle] çizgisiyle
/// beyaz zeminde ~3:1 görünür. [showLabel] altta canlı etiket gösterir:
/// puan yokken "Puan vermek için dokun", sonra [feedbackRatingLabels].
class FeedbackStars extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;
  final double size;
  final bool showLabel;
  final MainAxisAlignment alignment;

  const FeedbackStars({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 36,
    this.showLabel = true,
    this.alignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          _StarCell(
            star: star,
            filled: star <= value,
            selected: star == value,
            size: size,
            onTap: onChanged == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onChanged!(star);
                  },
          ),
      ],
    );
    final stars = alignment == MainAxisAlignment.center
        ? Center(child: row)
        : Align(alignment: Alignment.centerLeft, child: row);
    if (!showLabel) return stars;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment == MainAxisAlignment.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        stars,
        const SizedBox(height: 2),
        FeedbackRatingLabel(value: value),
      ],
    );
  }
}

/// Yıldızların altındaki canlı etiket ("Puan vermek için dokun" → "İyi").
class FeedbackRatingLabel extends StatelessWidget {
  final int value;
  const FeedbackRatingLabel({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final empty = value <= 0;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 20),
      child: Semantics(
        liveRegion: true,
        child: AnimatedSwitcher(
          duration: feedbackMotion(context, const Duration(milliseconds: 150)),
          child: Text(
            empty ? 'Puan vermek için dokun' : feedbackRatingLabels[value.clamp(1, 5)],
            key: ValueKey(value),
            style: empty
                ? MarketText.caption(color: MarketPalette.muted, size: 13)
                : MarketText.label(color: MarketPalette.orangeInk, size: 14),
          ),
        ),
      ),
    );
  }
}

class _StarCell extends StatefulWidget {
  final int star;
  final bool filled;
  final bool selected;
  final double size;
  final VoidCallback? onTap;

  const _StarCell({
    required this.star,
    required this.filled,
    required this.selected,
    required this.size,
    required this.onTap,
  });

  @override
  State<_StarCell> createState() => _StarCellState();
}

class _StarCellState extends State<_StarCell> with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.18).chain(CurveTween(curve: Curves.easeOut)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.18, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 55,
    ),
  ]).animate(_bounce);

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _tap() {
    if (!MediaQuery.disableAnimationsOf(context)) _bounce.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final label = '${widget.star} yıldız, ${feedbackRatingLabels[widget.star]}';
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: widget.selected,
      enabled: widget.onTap != null,
      label: label,
      child: Tooltip(
        message: '${widget.star} yıldız',
        excludeFromSemantics: true,
        child: InkResponse(
          onTap: widget.onTap == null ? null : _tap,
          radius: 26,
          child: SizedBox(
            width: MarketSize.tapTarget,
            height: MarketSize.tapTarget,
            child: Center(
              child: ScaleTransition(
                scale: _scale,
                child: Icon(
                  widget.filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: widget.size,
                  color: widget.filled ? MarketPalette.orange : MarketPalette.subtle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ürün küçük resmi (yoksa sepet simgesi).
class FeedbackProductThumb extends StatelessWidget {
  final String? image;
  final double size;
  final double radius;

  const FeedbackProductThumb({
    super.key,
    required this.image,
    this.size = 40,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MarketPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.shopping_basket_outlined,
          size: size * .5, color: MarketPalette.subtle),
    );
    final url = image?.trim() ?? '';
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        child: Image.network(
          optimizedImageUrl(url, width: MarketImageSize.thumb),
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

/// Siparişteki ürünler: müşteri sorunlu ürünü seçer, sorun türü varsayılan
/// olarak en son seçilen ürün etiketidir ([defaultIssue]); seçili satırda
/// "Bozuk · Eksik · Yanlış" ile değiştirilebilir.
/// [selected]: ürün anahtarı → sorun türü (bozuk / eksik / yanlis)
class ProblemItemsPicker extends StatefulWidget {
  final List<FeedbackOrderProduct> products;
  final Map<String, String> selected;
  final ValueChanged<Map<String, String>> onChanged;
  final bool enabled;
  final String defaultIssue;

  const ProblemItemsPicker({
    super.key,
    required this.products,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.defaultIssue = 'bozuk',
  });

  @override
  State<ProblemItemsPicker> createState() => _ProblemItemsPickerState();
}

class _ProblemItemsPickerState extends State<ProblemItemsPicker> {
  static const _collapsedCount = 6;
  bool _showAll = false;

  void _toggle(FeedbackOrderProduct product) {
    HapticFeedback.selectionClick();
    final next = Map<String, String>.from(widget.selected);
    if (next.containsKey(product.key)) {
      next.remove(product.key);
    } else {
      next[product.key] = widget.defaultIssue;
    }
    widget.onChanged(next);
  }

  void _setIssue(FeedbackOrderProduct product, String issue) {
    HapticFeedback.selectionClick();
    widget.onChanged({...widget.selected, product.key: issue});
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.products;
    if (products.isEmpty) return const SizedBox.shrink();
    final collapsed = !_showAll && products.length > _collapsedCount;
    final visible = collapsed ? products.take(_collapsedCount) : products;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Hangi üründe sorun vardı?', style: MarketText.heading()),
        ),
        const SizedBox(height: 2),
        Text('Ürünü seç; ekibimiz kontrol edecek.', style: MarketText.caption()),
        const SizedBox(height: MarketSpace.md),
        for (final product in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: MarketSpace.sm),
            child: _ProblemItemRow(
              product: product,
              issue: widget.selected[product.key],
              enabled: widget.enabled,
              onTap: () => _toggle(product),
              onIssue: (issue) => _setIssue(product, issue),
            ),
          ),
        if (collapsed)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showAll = true),
              style: TextButton.styleFrom(minimumSize: const Size(0, MarketSize.tapTarget)),
              icon: const Icon(Icons.expand_more_rounded, size: 20),
              label: Text('Tümünü göster (${products.length})'),
            ),
          ),
      ],
    );
  }
}

class _ProblemItemRow extends StatelessWidget {
  final FeedbackOrderProduct product;
  final String? issue;
  final bool enabled;
  final VoidCallback onTap;
  final ValueChanged<String> onIssue;

  const _ProblemItemRow({
    required this.product,
    required this.issue,
    required this.enabled,
    required this.onTap,
    required this.onIssue,
  });

  @override
  Widget build(BuildContext context) {
    final selected = issue != null;
    final name = productDisplayName(product.name);
    final issueLabel = feedbackIssueTypes
        .firstWhere((type) => type.id == issue, orElse: () => feedbackIssueTypes.first)
        .label;
    final shape = BorderRadius.circular(MarketRadius.md);
    return AnimatedContainer(
      duration: feedbackMotion(context, const Duration(milliseconds: 160)),
      decoration: BoxDecoration(
        color: selected ? MarketPalette.redSoft : MarketPalette.surface,
        borderRadius: shape,
        border: Border.all(
          color: selected ? MarketPalette.redLine : MarketPalette.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              checked: selected,
              label: selected ? '$name, sorun: $issueLabel' : name,
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: enabled ? onTap : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          _CheckDot(selected: selected),
                          const SizedBox(width: 10),
                          FeedbackProductThumb(image: product.image),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: MarketText.label(size: 13),
                                ),
                                if (product.quantity > 1)
                                  Text('×${product.quantity}', style: MarketText.caption()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            FeedbackReveal(
              child: !selected
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: _IssueSegments(
                        value: issue!,
                        enabled: enabled,
                        onChanged: onIssue,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckDot extends StatelessWidget {
  final bool selected;
  const _CheckDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: feedbackMotion(context, const Duration(milliseconds: 160)),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? MarketPalette.red : MarketPalette.surface,
        border: Border.all(
          color: selected ? MarketPalette.red : MarketPalette.subtle,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}

/// "Bozuk · Eksik · Yanlış" seçici: 36 pt görünür, 44 pt dokunma alanı.
class _IssueSegments extends StatelessWidget {
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _IssueSegments({required this.value, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < feedbackIssueTypes.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _IssueSegment(
              option: feedbackIssueTypes[i],
              selected: feedbackIssueTypes[i].id == value,
              onTap: enabled ? () => onChanged(feedbackIssueTypes[i].id) : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _IssueSegment extends StatelessWidget {
  final FeedbackOption option;
  final bool selected;
  final VoidCallback? onTap;

  const _IssueSegment({required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: option.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: AnimatedContainer(
              duration: feedbackMotion(context, const Duration(milliseconds: 140)),
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? MarketPalette.red : MarketPalette.surface,
                borderRadius: BorderRadius.circular(MarketRadius.sm),
                border: Border.all(color: selected ? MarketPalette.red : MarketPalette.redLine),
              ),
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MarketText.label(
                  size: 13,
                  color: selected ? Colors.white : MarketPalette.red,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sunucuya gidecek sorunlu ürün listesi
List<Map<String, String>> problemItemsPayload(
  List<FeedbackOrderProduct> products,
  Map<String, String> selected,
) {
  return [
    for (final product in products)
      if (selected[product.key] != null)
        {
          if (product.productId != null) 'productId': product.productId!,
          'name': product.name,
          'issue': selected[product.key]!,
        },
  ];
}

/// Başlıklı yorum alanı. [minChars] verilirse sağda canlı sayaç ("3/5",
/// yeterli olunca ✓) gösterilir.
class FeedbackCommentField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String hint;
  final int? minChars;
  final bool enabled;
  final String? errorText;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final FocusNode? focusNode;

  const FeedbackCommentField({
    super.key,
    required this.controller,
    this.label,
    required this.hint,
    this.minChars,
    this.enabled = true,
    this.errorText,
    this.maxLength = 1000,
    this.minLines = 2,
    this.maxLines = 4,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(label!, style: MarketText.heading()),
                ),
              ),
              if (minChars != null) _CommentCounter(controller: controller, minChars: minChars!),
            ],
          ),
          const SizedBox(height: MarketSpace.sm),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          maxLength: maxLength,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
          style: MarketText.body(size: 14),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            errorText: errorText,
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _CommentCounter extends StatelessWidget {
  final TextEditingController controller;
  final int minChars;
  const _CommentCounter({required this.controller, required this.minChars});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final length = value.text.trim().length;
        final done = length >= minChars;
        return Semantics(
          label: done ? 'Yeterli uzunlukta' : 'En az $minChars karakter, şu an $length',
          child: ExcludeSemantics(
            child: done
                ? const Icon(Icons.check_circle_rounded, size: 18, color: MarketPalette.green)
                : Text('${length.clamp(0, minChars)}/$minChars',
                    style: MarketText.caption(color: MarketPalette.muted)),
          ),
        );
      },
    );
  }
}

/// Sunucu hatası kutusu (form sayfalarının alt kısmında, "Gönder"in üstünde).
class FeedbackErrorNotice extends StatelessWidget {
  final String text;
  const FeedbackErrorNotice({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: MarketNotice(
        icon: Icons.error_outline_rounded,
        text: text,
        background: MarketPalette.redSoft,
        foreground: MarketPalette.red,
      ),
    );
  }
}

/// Alanın altındaki kısa doğrulama hatası ("Bir puan seç").
class FeedbackFieldError extends StatelessWidget {
  final String text;
  const FeedbackFieldError(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: MarketPalette.red),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: MarketText.caption(color: MarketPalette.red, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// 54 pt "Gönder" butonu. Gönderilirken yeşil kalır, dönen gösterge ve
/// "Gönderiliyor…" gösterir.
class FeedbackSubmitButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final double height;

  const FeedbackSubmitButton({
    super.key,
    this.label = 'Gönder',
    required this.busy,
    required this.onPressed,
    this.height = MarketSize.button,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(height),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        disabledBackgroundColor: busy ? MarketPalette.green : null,
        disabledForegroundColor: busy ? Colors.white : null,
      ),
      child: Semantics(
        liveRegion: true,
        child: busy
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Text('Gönderiliyor…'),
                  ],
                ),
              )
            : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Erteleme düğmesi ("Şimdi değil"): 48 pt, gri yazı.
class FeedbackLaterButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  const FeedbackLaterButton({super.key, required this.onPressed, this.label = 'Şimdi değil'});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: MarketPalette.muted,
        minimumSize: const Size(0, MarketSize.tapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Text(label),
    );
  }
}

/// Form sayfalarının sabit alt kısmı: varsa sunucu hatası, sonra
/// ["Şimdi değil"] + ["Gönder"]. Sunucu hatasından sonra buton "Tekrar dene" olur.
class FeedbackSheetFooter extends StatelessWidget {
  final bool busy;
  final VoidCallback? onSubmit;
  final VoidCallback? onLater;
  final String? serverError;
  final String label;

  const FeedbackSheetFooter({
    super.key,
    required this.busy,
    required this.onSubmit,
    this.onLater,
    this.serverError,
    this.label = 'Gönder',
  });

  @override
  Widget build(BuildContext context) {
    final submit = FeedbackSubmitButton(
      label: serverError != null ? 'Tekrar dene' : label,
      busy: busy,
      onPressed: onSubmit,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (serverError != null) ...[
          FeedbackErrorNotice(text: serverError!),
          const SizedBox(height: MarketSpace.md),
        ],
        if (onLater == null)
          submit
        else
          Row(
            children: [
              FeedbackLaterButton(onPressed: busy ? null : onLater),
              const SizedBox(width: MarketSpace.sm),
              Expanded(child: submit),
            ],
          ),
      ],
    );
  }
}

/// Yazılmış ama gönderilmemiş yanıt varken kapatmadan önce sorar.
/// Kapatılacaksa true döner.
Future<bool> confirmDiscardFeedback(BuildContext context) {
  return showMarketConfirm(
    context,
    icon: Icons.edit_note_rounded,
    title: 'Yazdıkların silinsin mi?',
    message: 'Yanıtını henüz göndermedin. Kapatırsan yazdıkların silinecek.',
    confirmLabel: 'Yine de kapat',
    cancelLabel: 'Yazmaya devam et',
  );
}

/// Form alt sayfalarının geri tuşu / dışarı dokunma / "Kapat" kuralı:
/// * gönderilirken kapanmaz,
/// * [onBack] verilmişse sayfa içinde bir önceki adıma döner,
/// * [dirty] (yazılmış yanıt) varsa önce sorar, onaylanırsa false ile kapanır.
class FeedbackPopGuard extends StatelessWidget {
  final bool busy;
  final bool dirty;
  final VoidCallback? onBack;
  final Widget child;

  const FeedbackPopGuard({
    super.key,
    required this.busy,
    required this.dirty,
    this.onBack,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !busy && !dirty && onBack == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || busy) return;
        if (onBack != null) {
          onBack!();
          return;
        }
        if (dirty) {
          final navigator = Navigator.of(context);
          if (await confirmDiscardFeedback(context)) navigator.pop(false);
        }
      },
      child: child,
    );
  }
}

/// Başlıktaki "Kapat" (✕) için: yazılmış yanıt varsa sorar, sonra false ile kapatır.
Future<void> closeFeedbackSheet(BuildContext context, {required bool dirty}) async {
  final navigator = Navigator.of(context);
  if (dirty && !await confirmDiscardFeedback(context)) return;
  navigator.pop(false);
}

/// Teşekkür adımının ruh hali.
enum FeedbackMood { happy, neutral, unhappy }

/// Teşekkür adımının alt sayfa iç boşluğu (MarketSheetScaffold.bodyPadding).
const feedbackThanksPadding = EdgeInsets.fromLTRB(24, 8, 24, 16);

/// Teşekkür ekranı (ortalı "an" düzeni). Memnun müşteriye mağaza puanı ve
/// davet kodu, memnun olmayan müşteriye destek görüşmesi gösterilir.
///
/// * [mood] verilmezse [happy]'den çıkar (happy / unhappy). NPS 7-8 için neutral.
/// * [wroteComment]: memnun olmayan müşteri bir şey yazmadıysa "yazdıklarını
///   okuyacağız" denmez; destekle konuşma yolu gösterilir.
/// * [promoter]: NPS 9-10. Davet kartı her zaman gösterilir (diğer memnun
///   yanıtlarda en fazla 14 günde bir).
///
/// Tek başına bir içeriktir; alt sayfada `MarketSheetScaffold(body: ...)`
/// içinde [feedbackThanksPadding] ile kullanılır.
class FeedbackThanks extends StatefulWidget {
  final bool happy;
  final FeedbackMood? mood;
  final String? supportChatId;
  final bool wroteComment;
  final bool promoter;

  const FeedbackThanks({
    super.key,
    required this.happy,
    this.mood,
    this.supportChatId,
    this.wroteComment = true,
    this.promoter = false,
  });

  @override
  State<FeedbackThanks> createState() => _FeedbackThanksState();
}

class _FeedbackThanksState extends State<FeedbackThanks> {
  static const _referralShownKey = 'feedback_thanks_referral_at';
  static const _referralInterval = Duration(days: 14);

  bool _storeSuggested = false;
  bool _referralAllowed = false;
  bool _referralMarked = false;

  FeedbackMood get _mood =>
      widget.mood ?? (widget.happy ? FeedbackMood.happy : FeedbackMood.unhappy);

  @override
  void initState() {
    super.initState();
    if (_mood == FeedbackMood.happy) {
      _prepareHappyExtras();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final referral = context.read<ReferralViewModel>();
        if (referral.referral == null && !referral.isLoading) referral.loadReferralInfo();
      });
    }
    // Yalnızca gönderim başarılı olduğunda bu ekran görünür
    HapticFeedback.lightImpact();
  }

  Future<void> _prepareHappyExtras() async {
    try {
      final store = await ReviewService.instance.canSuggestStore();
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_referralShownKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final referral = widget.promoter || now - last >= _referralInterval.inMilliseconds;
      if (!mounted) return;
      setState(() {
        _storeSuggested = store;
        _referralAllowed = referral;
      });
    } catch (_) {
      // Ek kartlar gösterilmez; teşekkür yine görünür
    }
  }

  void _markReferralShown() {
    if (_referralMarked) return;
    _referralMarked = true;
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setInt(_referralShownKey, DateTime.now().millisecondsSinceEpoch),
      onError: (_) => false,
    );
  }

  void _openStore() {
    final host = Navigator.of(context).context;
    Navigator.of(context).pop(true);
    ReviewService.instance.openStoreListing().then((ok) {
      if (!ok && host.mounted) {
        showMarketSnack(host, 'Mağaza açılamadı. Lütfen daha sonra tekrar dene.', error: true);
      }
    });
  }

  void _openChat(String path) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop(true);
    router.push(path);
  }

  @override
  Widget build(BuildContext context) {
    final mood = _mood;
    final chatId = widget.supportChatId;

    final IconData icon;
    final Color iconBackground;
    final Color iconForeground;
    final String title;
    final String message;
    switch (mood) {
      case FeedbackMood.happy:
        icon = Icons.favorite_rounded;
        iconBackground = MarketPalette.greenSoft;
        iconForeground = MarketPalette.green;
        title = 'Teşekkürler!';
        message = 'Görüşün bize ulaştı. Memnun kalmana çok sevindik 💚';
      case FeedbackMood.neutral:
        icon = Icons.thumb_up_alt_rounded;
        iconBackground = MarketPalette.orangeSoft;
        iconForeground = MarketPalette.orangeInk;
        title = 'Teşekkürler!';
        message = "Notunu aldık. 10'u hak etmek için çalışmaya devam ediyoruz.";
      case FeedbackMood.unhappy:
        icon = Icons.support_agent_rounded;
        iconBackground = MarketPalette.orangeSoft;
        iconForeground = MarketPalette.orangeInk;
        if (chatId != null) {
          title = 'Üzgünüz, hemen ilgileniyoruz';
          message = 'Destek ekibimiz bildirimini gördü, sohbetten sana dönüş yapacak.';
        } else {
          title = 'Üzgünüz, bunu düzelteceğiz';
          message = widget.wroteComment
              ? 'Yazdıklarını ekibimiz okuyacak, gerekirse seninle iletişime geçeceğiz.'
              : 'Bildirimin ekibimize ulaştı. Daha hızlı yardım için destekten bize yazabilirsin.';
        }
    }

    final Widget primary;
    Widget? secondary;
    if (mood == FeedbackMood.unhappy && chatId != null) {
      primary = FilledButton.icon(
        onPressed: () => _openChat('/chat/$chatId'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(MarketSize.button)),
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
        label: const Text('Destek görüşmesini aç'),
      );
      secondary = _ThanksTextButton(
        label: 'Kapat',
        onPressed: () => Navigator.of(context).pop(true),
      );
    } else {
      primary = FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(MarketSize.button)),
        child: const Text('Tamam'),
      );
      if (mood == FeedbackMood.unhappy && !widget.wroteComment) {
        secondary = _ThanksTextButton(
          label: 'Destekle konuş',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: () => _openChat('/chat'),
        );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: MarketIconTile(
            icon: icon,
            size: 60,
            background: iconBackground,
            foreground: iconForeground,
          ),
        ),
        const SizedBox(height: MarketSpace.lg),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(title, textAlign: TextAlign.center, style: MarketText.title()),
        ),
        const SizedBox(height: MarketSpace.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: MarketText.body(color: MarketPalette.muted, size: 14),
        ),
        if (mood == FeedbackMood.happy)
          FeedbackReveal(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_storeSuggested) ...[
                  const SizedBox(height: MarketSpace.xl),
                  _StoreCard(onTap: _openStore),
                ],
                if (_referralAllowed)
                  Consumer<ReferralViewModel>(
                    builder: (context, vm, _) {
                      final referral = vm.referral;
                      if (referral == null || !referral.isActive || referral.code.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) => _markReferralShown());
                      return Padding(
                        padding: EdgeInsets.only(
                          top: _storeSuggested ? MarketSpace.md : MarketSpace.xl,
                        ),
                        child: _ReferralCard(
                          code: referral.code,
                          link: referral.link,
                          inviteePercent: referral.inviteeDiscountPercent,
                          rewardPercent: referral.rewardDiscountPercent,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        const SizedBox(height: MarketSpace.xxl),
        primary,
        if (secondary != null) ...[const SizedBox(height: MarketSpace.xs), secondary],
      ],
    );
  }
}

class _ThanksTextButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const _ThanksTextButton({required this.label, this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: MarketPalette.inkSoft,
      minimumSize: const Size.fromHeight(MarketSize.tapTarget),
    );
    if (icon == null) {
      return TextButton(onPressed: onPressed, style: style, child: Text(label));
    }
    return TextButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// "Bizi Google Play'de puanlar mısın?" kartı (mağaza sayfasını açar).
class _StoreCard extends StatelessWidget {
  final VoidCallback onTap;
  const _StoreCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final service = ReviewService.instance;
    return Semantics(
      button: true,
      label: service.storeAsk,
      hint: 'Mağaza sayfası açılır',
      child: ExcludeSemantics(
        child: Material(
          color: MarketPalette.orangeSoft,
          borderRadius: BorderRadius.circular(MarketRadius.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(MarketRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star_rounded, size: 22, color: MarketPalette.orange),
                    ),
                    const SizedBox(width: MarketSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(service.storeAsk, style: MarketText.label(size: 14)),
                          const SizedBox(height: 2),
                          Text(
                            "Yorumun, Devrek'te bizi henüz tanımayanların bizi bulmasına yardım ediyor.",
                            style: MarketText.caption(color: MarketPalette.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: MarketSpace.sm),
                    const Icon(Icons.open_in_new_rounded, size: 18, color: MarketPalette.muted),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Davet kodu kartı: kod dokununca kopyalanır (kısa süre "Kopyalandı" görünür),
/// yanında "Paylaş".
class _ReferralCard extends StatefulWidget {
  final String code;
  final String link;
  final int inviteePercent;
  final int rewardPercent;

  const _ReferralCard({
    required this.code,
    required this.link,
    required this.inviteePercent,
    required this.rewardPercent,
  });

  @override
  State<_ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<_ReferralCard> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.code));
    HapticFeedback.selectionClick();
    _reset?.cancel();
    setState(() => _copied = true);
    _reset = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _share() {
    HapticFeedback.lightImpact();
    unawaited(MetaAppEventsService.instance
        .logShare(contentType: 'referral', contentId: widget.code));
    Share.share(
      '🎁 Benim Marketim\'e davetlisin!\n\n"${widget.code}" koduyla kayıt ol, ilk siparişinde %${widget.inviteePercent} indirim kazan!\n\n${widget.link}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MarketPalette.limeSoft,
        borderRadius: BorderRadius.circular(MarketRadius.md),
        border: Border.all(color: MarketPalette.limeLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Arkadaşını getir, ikiniz de kazanın', style: MarketText.heading()),
          const SizedBox(height: 4),
          Text(
            'Arkadaşın ilk siparişinde %${widget.inviteePercent} indirim alır, sen de %${widget.rewardPercent} indirim kuponu kazanırsın.',
            style: MarketText.caption(color: MarketPalette.inkSoft),
          ),
          const SizedBox(height: MarketSpace.md),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  liveRegion: _copied,
                  label: _copied ? 'Davet kodu kopyalandı' : 'Davet kodu ${widget.code}, kopyala',
                  child: ExcludeSemantics(
                    child: Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MarketRadius.sm),
                        side: const BorderSide(color: MarketPalette.limeLine),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _copy,
                        child: SizedBox(
                          height: MarketSize.tapTarget,
                          child: AnimatedSwitcher(
                            duration: feedbackMotion(context, const Duration(milliseconds: 160)),
                            child: _copied
                                ? Row(
                                    key: const ValueKey('copied'),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check_rounded, size: 16, color: MarketPalette.green),
                                      const SizedBox(width: 6),
                                      Text('Kopyalandı',
                                          style: MarketText.label(color: MarketPalette.greenDark, size: 14)),
                                    ],
                                  )
                                : Padding(
                                    key: const ValueKey('code'),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              widget.code,
                                              style: MarketText.code(
                                                      size: 16, color: MarketPalette.greenDeep)
                                                  .copyWith(letterSpacing: 1.5),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.copy_rounded, size: 16, color: MarketPalette.greenDark),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: MarketSpace.sm),
              OutlinedButton.icon(
                onPressed: _share,
                style: OutlinedButton.styleFrom(
                  foregroundColor: MarketPalette.greenDark,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: MarketPalette.greenLine),
                  minimumSize: const Size(0, MarketSize.tapTarget),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Paylaş'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Alt sayfa tutamacı. Eski içerikler için (ör. sipariş iptal nedeni) korunur;
/// yeni alt sayfalar MarketSheetScaffold'un kendi tutamacını kullanır.
class FeedbackSheetHandle extends StatelessWidget {
  const FeedbackSheetHandle({super.key});

  @override
  Widget build(BuildContext context) =>
      const MarketSheetHandle(margin: EdgeInsets.only(bottom: MarketSpace.lg));
}

/// Klavyeyle birlikte yükselen, kaydırılabilir alt sayfa gövdesi. Kendi
/// iskeleti olmayan içerikler [showFeedbackSheet] ile bunun içinde açılır.
class FeedbackSheetBody extends StatelessWidget {
  final Widget child;
  const FeedbackSheetBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          MarketSpace.xl,
          MarketSpace.md,
          MarketSpace.xl,
          MarketSpace.xl + bottomInset,
        ),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

/// Ortak alt sayfa açıcı: [child] boşluklu, kaydırılabilir gövdeye
/// ([FeedbackSheetBody]) konur. Uygulamanın alt sayfa ayarlarını
/// (beyaz zemin, karartma, ekranın en fazla %92'si) kullanır.
Future<T?> showFeedbackSheet<T>(BuildContext context, Widget child) {
  return showMarketSheet<T>(
    context,
    builder: (_) => FeedbackSheetBody(child: child),
  );
}
