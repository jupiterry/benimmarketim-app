/// Sipariş öncesi yasal metinler: Ön Bilgilendirme Formu ve Mesafeli Satış
/// Sözleşmesi (6502 sayılı Kanun ve Mesafeli Sözleşmeler Yönetmeliği).
/// Metinler o anki sepetten üretilir: ürünler, tutarlar, teslimat yeri,
/// ödeme yöntemi siparişe özeldir.
library;

/// Satıcı bilgileri. Web sitesindeki yasal sayfalarla aynı kaynaktan
/// (frontend/src/data/company.js) doldurulmalı. Boş bırakılan alan
/// metinlerde gösterilmez.
abstract final class SellerInfo {
  static const String legalName = 'Benim Marketim Ticaret Limited Şirketi';
  static const String brand = 'Benim Marketim';
  static const String address =
      'Ağalar Mahallesi, 760. Sokak, TOKİ Konutları, No: 19 Devrek / Zonguldak';
  static const String email = 'info@benimmarketim.com';
  static const String website = 'devrekbenimmarketim.com';

  // Yasal olarak gösterilmesi gereken ama henüz bilinmeyen bilgiler.
  // Doldurulunca metinlerde kendiliğinden görünür.
  static const String phone = '';
  static const String mersisNumber = '';
  static const String taxOffice = '';
  static const String taxNumber = '';
}

/// Metinde siparişe özel bir ürün satırı.
class LegalOrderLine {
  final String name;
  final int quantity;
  final double unitPrice;

  const LegalOrderLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => unitPrice * quantity;
}

/// Metinleri üretmek için siparişin o anki bilgileri.
class LegalOrderData {
  final String buyerName;
  final String buyerPhone;

  /// Teslimat yeri ("Kız KYK Yurdu" ya da tam adres)
  final String deliveryPlace;
  final List<LegalOrderLine> lines;

  /// Ürünler toplamı (ürün indirimleri sonrası, kupon öncesi)
  final double productsTotal;
  final double couponDiscount;

  /// Teslimat ücreti; 0 = ücretsiz, null = henüz hesaplanmadı
  final double? deliveryFee;
  final double payable;

  /// "Kapıda nakit" ya da "Kapıda kart (POS)"; seçilmediyse boş
  final String paymentMethod;
  final DateTime date;

  const LegalOrderData({
    required this.buyerName,
    required this.buyerPhone,
    required this.deliveryPlace,
    required this.lines,
    required this.productsTotal,
    required this.couponDiscount,
    required this.deliveryFee,
    required this.payable,
    required this.paymentMethod,
    required this.date,
  });
}

/// Bir metin bölümü: başlık ve paragraflar.
class LegalSection {
  final String title;
  final List<String> paragraphs;

  const LegalSection(this.title, this.paragraphs);
}

/// Yasal metin: başlık ve bölümler.
class LegalDocument {
  final String title;
  final List<LegalSection> sections;

  const LegalDocument(this.title, this.sections);

  /// Paylaşma / kopyalama için düz metin
  String get plainText => [
        title,
        for (final s in sections) ...['', s.title, ...s.paragraphs],
      ].join('\n');
}

typedef MoneyFormat = String Function(num value);

String _date(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}

List<String> _sellerLines() => [
      'Unvan: ${SellerInfo.legalName}',
      'Adres: ${SellerInfo.address}',
      if (SellerInfo.phone.isNotEmpty) 'Telefon: ${SellerInfo.phone}',
      'E-posta: ${SellerInfo.email}',
      if (SellerInfo.mersisNumber.isNotEmpty)
        'MERSİS No: ${SellerInfo.mersisNumber}',
      if (SellerInfo.taxOffice.isNotEmpty || SellerInfo.taxNumber.isNotEmpty)
        'Vergi Dairesi / No: ${SellerInfo.taxOffice} / ${SellerInfo.taxNumber}',
      'İnternet sitesi: ${SellerInfo.website}',
    ];

List<String> _buyerLines(LegalOrderData d) => [
      if (d.buyerName.trim().isNotEmpty) 'Ad soyad: ${d.buyerName.trim()}',
      if (d.buyerPhone.trim().isNotEmpty) 'Telefon: ${d.buyerPhone.trim()}',
      'Teslimat yeri: ${d.deliveryPlace.trim().isEmpty ? 'Siparişte seçilen teslimat yeri' : d.deliveryPlace.trim()}',
    ];

List<String> _orderLines(LegalOrderData d, MoneyFormat money) => [
      for (final l in d.lines)
        '${l.quantity} × ${l.name} — birim ${money(l.unitPrice)}, toplam ${money(l.total)}',
      'Ürünler toplamı: ${money(d.productsTotal)}',
      if (d.couponDiscount > 0) 'Kupon indirimi: −${money(d.couponDiscount)}',
      'Teslimat ücreti: ${switch (d.deliveryFee) {
        null => 'teslimat yeri seçilince hesaplanır, onaydan önce gösterilir',
        <= 0 => 'Ücretsiz',
        final fee => money(fee),
      }}',
      'Ödenecek toplam (KDV dahil): ${money(d.payable)}',
    ];

List<String> _paymentLines(LegalOrderData d) => [
      'Ödeme yöntemi: ${d.paymentMethod.isEmpty ? 'Kapıda nakit ya da kapıda kart (POS); siparişte seçilir' : d.paymentMethod}',
      'Ödeme, ürünler teslim edilirken kapıda yapılır. Sipariş sırasında kart '
          'bilgisi alınmaz.',
    ];

const _deliveryTerms = [
  'Ürünler, siparişte seçilen teslimat yerine satıcının kuryesiyle teslim '
      'edilir. Teslimat süresi bölgeye ve yoğunluğa göre değişir; bölgenin '
      'tahmini süresi uygulamada gösterilir ve yasal üst sınır olan 30 günü '
      'aşmaz.',
  'Teslimat ücreti uygulanıyorsa sipariş onayından önce ayrıca gösterilir ve '
      'toplam tutara dahildir.',
];

const _withdrawalTerms = [
  'Alıcı, teslimattan itibaren 14 gün içinde hiçbir gerekçe göstermeden ve '
      'cezai şart ödemeden sözleşmeden cayabilir. Cayma bildirimi '
      '${SellerInfo.email} adresine ya da uygulamadaki destek kanalına '
      'yapılabilir. Satıcı, bildirimin ulaşmasından itibaren 14 gün içinde '
      'ödenen tutarı iade eder.',
  'Mesafeli Sözleşmeler Yönetmeliği md. 15 gereği şu ürünlerde cayma hakkı '
      'kullanılamaz: çabuk bozulabilen ya da son kullanma tarihi geçebilecek '
      'ürünler (taze gıda, meyve, sebze, et, süt ürünleri vb.); teslimden sonra '
      'ambalajı, bandı, mührü açılmış ve sağlık ya da hijyen açısından iadesi '
      'uygun olmayan ürünler; alıcının isteği doğrultusunda kişiselleştirilen '
      'ürünler.',
  'Sipariş, teslim edilmeden önce uygulamadaki Siparişlerim ekranından iptal '
      'edilebilir.',
];

const _complaintTerms = [
  'Şikâyet ve itirazlar, Ticaret Bakanlığınca her yıl belirlenen parasal '
      'sınırlar içinde alıcının ya da satıcının yerleşim yerindeki Tüketici '
      'Hakem Heyetine, sınırı aşan uyuşmazlıklarda Tüketici Mahkemesine '
      'yapılabilir.',
];

/// Ön Bilgilendirme Formu (Yönetmelik md. 5)
LegalDocument buildPreInformationForm(LegalOrderData d, MoneyFormat money) =>
    LegalDocument('Ön Bilgilendirme Formu', [
      LegalSection('1. Satıcı', _sellerLines()),
      LegalSection('2. Alıcı', _buyerLines(d)),
      LegalSection('3. Siparişin konusu ve fiyatı', _orderLines(d, money)),
      LegalSection('4. Ödeme', _paymentLines(d)),
      const LegalSection('5. Teslimat', _deliveryTerms),
      const LegalSection('6. Cayma hakkı ve iptal', _withdrawalTerms),
      const LegalSection('7. Şikâyet ve itiraz', _complaintTerms),
      LegalSection('8. Bilgilendirme', [
        'Bu form ${_date(d.date)} tarihinde, sipariş onayından önce alıcıya '
            'uygulamada gösterilmiştir. Siparişin onaylanmasıyla alıcı, bu '
            'bilgileri okuduğunu ve elektronik ortamda teyit ettiğini kabul '
            'eder.',
      ]),
    ]);

/// Mesafeli Satış Sözleşmesi
LegalDocument buildDistanceSalesContract(LegalOrderData d, MoneyFormat money) =>
    LegalDocument('Mesafeli Satış Sözleşmesi', [
      LegalSection('Madde 1 – Taraflar', [
        'SATICI',
        ..._sellerLines(),
        'ALICI',
        ..._buyerLines(d),
      ]),
      LegalSection('Madde 2 – Konu', [
        'Bu sözleşme, alıcının ${SellerInfo.brand} mobil uygulamasından '
            'elektronik ortamda sipariş verdiği aşağıdaki ürünlerin satışı ve '
            'teslimine ilişkin tarafların hak ve yükümlülüklerini, 6502 '
            'sayılı Tüketicinin Korunması Hakkında Kanun ve Mesafeli '
            'Sözleşmeler Yönetmeliği hükümlerine göre düzenler.',
      ]),
      LegalSection('Madde 3 – Ürünler ve bedel', _orderLines(d, money)),
      LegalSection('Madde 4 – Ödeme', _paymentLines(d)),
      const LegalSection('Madde 5 – Teslimat', _deliveryTerms),
      const LegalSection('Madde 6 – Cayma hakkı ve iptal', _withdrawalTerms),
      const LegalSection('Madde 7 – Genel hükümler', [
        'Satıcı, ürünleri siparişe uygun, eksiksiz ve sağlam olarak teslim '
            'etmekle yükümlüdür. Stokta kalmayan ürün olursa alıcı bilgilendirilir '
            've o ürünün bedeli toplamdan düşülür.',
        'Alıcı, teslimat yeri ve iletişim bilgilerinin doğru olmasından '
            'sorumludur.',
      ]),
      const LegalSection('Madde 8 – Uyuşmazlık', _complaintTerms),
      LegalSection('Madde 9 – Yürürlük', [
        'Alıcı, ön bilgilendirme formunu okuduğunu ve bu sözleşmeyi '
            'elektronik ortamda onayladığını kabul eder. Sözleşme, siparişin '
            'onaylanmasıyla (${_date(d.date)}) kurulur.',
      ]),
    ]);
