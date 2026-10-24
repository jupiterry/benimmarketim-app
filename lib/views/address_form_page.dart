import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/delivery.dart';
import '../services/api_service.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../viewmodels/delivery_viewmodel.dart';
import 'widgets/address_map.dart';
import 'widgets/custom_dialog.dart';
import 'widgets/delivery_ui.dart';
import 'widgets/market_ui.dart';
import 'widgets/zone_picker.dart';

/// Adres ekleme / düzenleme formu. Adres, Devrek bölgesine (ilçe merkezi)
/// eklenir; yeni adreste önce harita açılır: kullanıcı kendi konumunu ya da
/// aradığı sokağı görür, iğneyi Devrek sınırı içinde kapısına getirir.
/// Ardından mahalle, sokak ve bina no (haritadan otomatik dolar) ile
/// isteğe bağlı bilgileri girer.
///
/// * Devrek (ilce): haritada konum, mahalle, sokak/cadde ve bina no zorunlu;
///   konum teslimat alanının dışındaysa kaydedilmez (OUT_OF_AREA).
/// * Yurtlar adres değildir (ödemede teslimat noktası olarak seçilir); eski
///   bir yurt adresi düzenlenirse yalnızca "Blok / oda" tarifi kalır.
/// * Eski mahalle/köy bölgeleri kapalıdır; o adresler düzenlenirken açık bir
///   bölge seçilir.
///
/// Kaydedilince sayfa kaydedilen [DeliveryAddress] ile kapanır
/// (`context.pop(saved)`); ödeme ekranı yeni adresi buradan alır.
class AddressFormPage extends StatefulWidget {
  /// Düzenlenecek adres; null ise yeni adres.
  final DeliveryAddress? initial;

  /// Yeni adreste önceden seçili bölge (ör. ödeme ekranından gelince).
  final String? initialZoneId;

  /// Haritada konum göstermek için (testte sahte konum).
  final LocationService locationService;

  /// Haritadaki konumdan mahalle ve sokağı bulur, haritada adres arar; null
  /// ise uygulamanın servisi kullanılır.
  final GeocodingService? geocoding;

  const AddressFormPage({
    super.key,
    this.initial,
    this.initialZoneId,
    this.locationService = const LocationService(),
    this.geocoding,
  });

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  static const _labelPresets = ['Ev', 'İş'];

  late final TextEditingController _label;
  late final TextEditingController _neighborhood;
  late final TextEditingController _street;
  late final TextEditingController _buildingNo;
  late final TextEditingController _buildingName;
  late final TextEditingController _floor;
  late final TextEditingController _apartment;
  late final TextEditingController _directions;
  final FocusNode _labelFocus = FocusNode();

  // Hata olunca ilk hatalı alana kaydırmak için
  static const _errorOrder = [
    'zone',
    'location',
    'neighborhood',
    'street',
    'buildingNo',
  ];
  final Map<String, GlobalKey> _fieldKeys = {
    for (final key in _errorOrder) key: GlobalKey(),
  };

  String? _zoneId;
  GeoPoint? _location;

  /// Haritadan bulunan yer; boş (ya da önceki konumdan doldurulmuş) mahalle,
  /// sokak ve bina no alanları buradan dolar.
  late final GeocodingService _geocoding;
  bool _placeLoading = false;
  int _placeSeq = 0;
  final Map<TextEditingController, String> _autoFilled = {};

  late bool _makeDefault;

  /// "Diğer" etiketi seçildi (alan serbest yazılır)
  bool _customLabel = false;

  /// Kaydet'e bir kez basıldı: hatalar o andan itibaren canlı gösterilir
  bool _submitted = false;
  bool _saving = false;
  bool _saved = false;
  String? _serverError;

  /// Yeni adreste harita adımı açıldı (bir kez)
  bool _mapStepShown = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final fields = initial?.fields ?? const AddressFields();
    _label = TextEditingController(text: initial?.label ?? '');
    _neighborhood = TextEditingController(text: fields.neighborhood);
    _street = TextEditingController(text: fields.street);
    _buildingNo = TextEditingController(text: fields.buildingNo);
    _buildingName = TextEditingController(text: fields.buildingName);
    _floor = TextEditingController(text: fields.floor);
    _apartment = TextEditingController(text: fields.apartment);
    _directions = TextEditingController(text: fields.directions);
    _location = fields.location;
    _zoneId = initial?.zoneId ?? widget.initialZoneId;
    _makeDefault = initial?.isDefault ?? false;
    _geocoding = widget.geocoding ?? GeocodingService.forApp();
    final label = _label.text.trim();
    _customLabel = label.isNotEmpty && !_labelPresets.contains(label);

    for (final controller in _controllers) {
      controller.addListener(_onChanged);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final delivery = context.read<DeliveryViewModel>();
      // İlk adres otomatik varsayılan olur; bunu bilmek için liste gerekir.
      if (!delivery.addressesLoaded) unawaited(delivery.loadAddresses());
      unawaited(_start(delivery));
    });
  }

  /// Bölgeler yüklenince yeni adreste bölge seçilir (tek adres bölgesi
  /// varsa o) ve harita adımı açılır.
  Future<void> _start(DeliveryViewModel delivery, {bool force = false}) async {
    await delivery.loadZones(force: force);
    if (!mounted || _isEdit) return;
    final zones = delivery.addressZones;
    if (_zoneId == null || delivery.zoneById(_zoneId) == null) {
      setState(() => _zoneId = zones.length == 1 ? zones.single.id : null);
    }
    final zone = delivery.zoneById(_zoneId);
    if (zone != null && _needsLocation(zone.type)) {
      await _pickLocation(firstStep: true);
    }
  }

  List<TextEditingController> get _controllers => [
        _label,
        _neighborhood,
        _street,
        _buildingNo,
        _buildingName,
        _floor,
        _apartment,
        _directions,
      ];

  void _onChanged() {
    if (!mounted) return;
    setState(() => _serverError = null);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _labelFocus.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Bölge
  // -------------------------------------------------------------------------

  /// Seçili bölge (açık bölgeler arasında yoksa null)
  DeliveryZone? _zone(DeliveryViewModel delivery) => delivery.zoneById(_zoneId);

  /// Seçili bölgenin tipi. Bölge listede yoksa (kapanmış) düzenlenen adresin
  /// kendi bilgisi kullanılır.
  DeliveryZoneType? _zoneType(DeliveryViewModel delivery) {
    final zone = _zone(delivery);
    if (zone != null) return zone.type;
    final initial = widget.initial;
    if (initial != null && _zoneId == initial.zoneId) return initial.zoneType;
    return null;
  }

  String? _zoneName(DeliveryViewModel delivery) {
    final zone = _zone(delivery);
    if (zone != null) return zone.name;
    final initial = widget.initial;
    if (initial != null && _zoneId == initial.zoneId) return initial.zoneName;
    return null;
  }

  /// Seçili bölge kapalı mı (bölgeler yüklendi ve listede yok, ya da
  /// düzenlenen adresin bölgesi kapalı işaretli)
  bool _zoneClosed(DeliveryViewModel delivery) {
    if (_zoneId == null) return false;
    final initial = widget.initial;
    if (delivery.zonesLoaded) return _zone(delivery) == null;
    return initial != null && _zoneId == initial.zoneId && !initial.zoneEnabled;
  }

  /// Haritada konum zorunlu mu? Devrek (ilçe) bölgesinde evet.
  static bool _needsLocation(DeliveryZoneType? type) =>
      type == DeliveryZoneType.ilce;

  Future<void> _pickZone() async {
    FocusManager.instance.primaryFocus?.unfocus();
    // Yurtlar adres değildir; ödemede teslimat noktası olarak seçilir.
    final zone = await showDeliveryZonePicker(
      context,
      selectedZoneId: _zoneId,
      includeDorms: false,
    );
    if (zone == null || !mounted) return;
    setState(() {
      _zoneId = zone.id;
      _serverError = null;
    });
    if (_needsLocation(zone.type) && _location == null) {
      await _pickLocation();
    }
  }

  // -------------------------------------------------------------------------
  // Konum
  // -------------------------------------------------------------------------

  /// Haritayı açar; seçilen noktayı konum yapar. [firstStep]: yeni adreste
  /// form açılınca ilk adım. Haritadan konum seçmeden çıkılırsa form da
  /// kapanır (adres eklemekten vazgeçildi).
  Future<void> _pickLocation({bool firstStep = false}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (firstStep) {
      if (_mapStepShown) return;
      _mapStepShown = true;
    }
    final delivery = context.read<DeliveryViewModel>();
    final zoneId = _zoneId;
    final point = await showAddressMapPicker(
      context,
      initial: _location,
      locationService: widget.locationService,
      geocoding: _geocoding,
      area: zoneId == null ? null : delivery.loadArea(zoneId),
    );
    if (!mounted) return;
    if (point == null) {
      if (firstStep && _location == null) context.pop();
      return;
    }
    setState(() {
      _location = point;
      _serverError = null;
    });
    unawaited(_lookupPlace());
  }

  /// Haritadaki konumdan mahalle/sokak/bina no bulur. Boş alanlar ya da
  /// önceki konumdan otomatik dolmuş (kullanıcının değiştirmediği) alanlar
  /// yenilenir.
  Future<void> _lookupPlace() async {
    final point = _location;
    if (point == null) return;
    final seq = ++_placeSeq;
    setState(() => _placeLoading = true);
    final place = await _geocoding.reverse(point);
    if (!mounted || seq != _placeSeq) return;
    setState(() {
      _placeLoading = false;
      if (place == null) return;
      _autofill(_neighborhood, place.area);
      _autofill(_street, place.road);
      _autofill(_buildingNo, place.houseNumber);
    });
  }

  void _autofill(TextEditingController controller, String value) {
    final current = controller.text.trim();
    final replaceable = current.isEmpty || current == _autoFilled[controller];
    if (!replaceable) return;
    controller.text = value;
    _autoFilled[controller] = value;
  }

  // -------------------------------------------------------------------------
  // Alanlar, doğrulama ve değişiklikler
  // -------------------------------------------------------------------------

  /// Bölge tipine göre gönderilecek alanlar. Yurtta yalnızca tarif kalır;
  /// gizli alanlar ve konum boş gönderilir.
  AddressFields _fields(DeliveryZoneType? type) {
    if (type == DeliveryZoneType.yurt) {
      return AddressFields(directions: _directions.text.trim());
    }
    return AddressFields(
      neighborhood: _neighborhood.text.trim(),
      street: _street.text.trim(),
      buildingNo: _buildingNo.text.trim(),
      buildingName: _buildingName.text.trim(),
      floor: _floor.text.trim(),
      apartment: _apartment.text.trim(),
      directions: _directions.text.trim(),
      location: _location,
    );
  }

  Map<String, String> _errors(DeliveryViewModel delivery) {
    final type = _zoneType(delivery);
    if (_zoneId == null || type == null) {
      return {'zone': 'Teslimat bölgeni seç'};
    }
    final errors = _fields(type).validate(type);
    if (_needsLocation(type) && _location == null) {
      errors['location'] = 'Haritada teslimat konumunu işaretle';
    }
    // Yeni adres yalnızca açık bölgeye eklenebilir.
    if (!_isEdit && _zoneClosed(delivery)) {
      errors['zone'] = zoneClosedNote;
    }
    return errors;
  }

  static Map<String, dynamic> _payload(
    String label,
    String? zoneId,
    AddressFields fields,
  ) =>
      {
        'label': label.trim(),
        'zoneId': zoneId,
        ...fields.toJson(),
      };

  static bool _same(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a['lat'] == b['lat'] && a['lng'] == b['lng'];
    }
    return a == b;
  }

  /// Düzenlemede yalnızca değişen alanlar (konum kaldırıldıysa
  /// `location: null`).
  Map<String, dynamic> _changes(DeliveryViewModel delivery) {
    final initial = widget.initial!;
    final before = _payload(initial.label, initial.zoneId, initial.fields);
    final now = _payload(_label.text, _zoneId, _fields(_zoneType(delivery)));
    return {
      for (final entry in now.entries)
        if (!_same(entry.value, before[entry.key])) entry.key: entry.value,
    };
  }

  /// Kayıtlı adres yok: yeni adres otomatik varsayılan olur.
  bool _isFirstAddress(DeliveryViewModel delivery) =>
      !_isEdit && delivery.addressesLoaded && delivery.addresses.isEmpty;

  bool _dirty(DeliveryViewModel delivery) {
    if (_saved) return false;
    final initial = widget.initial;
    if (initial != null) {
      return _changes(delivery).isNotEmpty ||
          (_makeDefault && !initial.isDefault);
    }
    return _location != null ||
        _controllers.any((c) => c.text.trim().isNotEmpty);
  }

  // -------------------------------------------------------------------------
  // Kaydet / geri
  // -------------------------------------------------------------------------

  Future<void> _save() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final delivery = context.read<DeliveryViewModel>();
    final errors = _errors(delivery);
    if (errors.isNotEmpty) {
      setState(() => _submitted = true);
      _scrollToFirstError(errors);
      return;
    }

    final type = _zoneType(delivery);
    setState(() {
      _submitted = true;
      _saving = true;
      _serverError = null;
    });
    try {
      final DeliveryAddress saved;
      final initial = widget.initial;
      if (initial == null) {
        saved = await delivery.createAddress(
          label: _label.text.trim(),
          zoneId: _zoneId!,
          fields: _fields(type),
          isDefault: _makeDefault || _isFirstAddress(delivery),
        );
      } else {
        var result = initial;
        final changes = _changes(delivery);
        if (changes.isNotEmpty) {
          result = await delivery.updateAddress(initial.id, changes);
        }
        if (_makeDefault && !initial.isDefault) {
          await delivery.setDefaultAddress(initial.id);
          result = delivery.addressById(initial.id) ?? result;
        }
        saved = result;
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      context.pop(saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverError = e.message;
      });
      switch (e.code) {
        case 'OUT_OF_AREA':
        case 'LOCATION_REQUIRED':
          // İğneyi teslimat alanı içine yeniden koydur
          unawaited(_pickLocation());
        case 'ZONE_CLOSED':
        case 'ZONE_NOT_FOUND':
          // Bölge kapanmış olabilir: listeyi yenile, seçici güncel olsun.
          unawaited(delivery.loadZones(force: true));
        case 'ADDRESS_ORDERING_DISABLED':
          unawaited(delivery.handleAddressOrderingDisabled());
        case 'ADDRESS_LIMIT':
          unawaited(delivery.loadAddresses());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverError =
            'Adresin kaydedilemedi. Bağlantını kontrol edip tekrar dene.';
      });
    }
  }

  void _scrollToFirstError(Map<String, String> errors) {
    for (final key in _errorOrder) {
      if (!errors.containsKey(key)) continue;
      final target = _fieldKeys[key]?.currentContext;
      if (target == null) continue;
      unawaited(Scrollable.ensureVisible(
        target,
        alignment: .2,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      ));
      return;
    }
  }

  Future<bool> _confirmDiscard() => showMarketConfirm(
        context,
        icon: Icons.edit_location_alt_outlined,
        title: 'Değişiklikler kaydedilmesin mi?',
        message: _isEdit
            ? 'Adresinde yaptığın değişiklikler kaybolacak.'
            : 'Yazdığın adres bilgileri kaybolacak.',
        confirmLabel: 'Kaydetmeden çık',
        cancelLabel: 'Düzenlemeye devam et',
        tone: MarketTone.danger,
      );

  Future<void> _back() async {
    if (_saving) return;
    final delivery = context.read<DeliveryViewModel>();
    if (_dirty(delivery) && !await _confirmDiscard()) return;
    if (!mounted) return;
    setState(() => _saved = true); // PopScope artık engellemez
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
    } else if (router != null) {
      router.go('/home');
    } else {
      Navigator.of(context).pop();
    }
  }

  // -------------------------------------------------------------------------
  // Görünüm
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final delivery = context.watch<DeliveryViewModel>();
    final type = _zoneType(delivery);
    final errors = _submitted ? _errors(delivery) : const <String, String>{};
    final limitReached =
        !_isEdit && delivery.addressesLoaded && !delivery.canAddAddress;
    final gutter = MarketSpace.gutterOf(context);
    final dirty = _dirty(delivery);

    // Yeni adres: bölgeler yükleniyor / alınamadı / adrese teslimat kapalı
    final Widget? blocker = _isEdit ? null : _buildBlocker(delivery);

    return PopScope(
      canPop: !_saving && !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        backgroundColor: MarketPalette.canvas,
        body: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const MarketScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: MarketHeader(
                title: _isEdit ? 'Adresi düzenle' : 'Yeni adres',
                subtitle: _isEdit
                    ? widget.initial!.title
                    : 'Teslimat adresini kaydet, siparişte hızlıca seç',
                compact: true,
                onBack: _back,
              ),
            ),
            if (blocker != null)
              SliverFillRemaining(hasScrollBody: false, child: blocker)
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32),
                sliver: SliverList.list(
                  children: [
                    if (limitReached) ...[
                      MarketNotice.warning(
                        icon: Icons.info_outline_rounded,
                        text:
                            'En fazla ${delivery.maxAddresses} adres kaydedebilirsin; yenisini eklemek için birini sil.',
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildZoneSection(delivery, errors['zone']),
                    if (type != null) ...[
                      if (type != DeliveryZoneType.yurt) ...[
                        const SizedBox(height: 14),
                        _buildLocationSection(type, errors['location']),
                      ],
                      const SizedBox(height: 14),
                      _buildFieldsSection(type, errors),
                      const SizedBox(height: 14),
                      _buildLabelSection(delivery),
                    ],
                  ],
                ),
              ),
          ],
        ),
        bottomNavigationBar: blocker != null
            ? null
            : _buildSaveBar(
                enabled: !limitReached && (!_isEdit || dirty),
              ),
      ),
    );
  }

  Widget? _buildBlocker(DeliveryViewModel delivery) {
    if (!delivery.zonesLoaded) {
      if (delivery.zonesError != null && !delivery.zonesLoading) {
        return MarketEmptyState.error(
          title: 'Teslimat bölgeleri yüklenemedi',
          message: delivery.zonesError!,
          onRetry: () => _start(delivery, force: true),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (delivery.addressZones.isEmpty) {
      return MarketEmptyState(
        icon: Icons.location_off_outlined,
        title: 'Şu an adrese teslimat yapılmıyor',
        message: 'Adrese teslimat açıldığında buradan adresini '
            'ekleyebileceksin. Şimdilik siparişini yurt teslimat noktasına '
            'verebilirsin.',
        secondaryLabel: 'Yenile',
        onSecondary: () => _start(delivery, force: true),
      );
    }
    return null;
  }

  Widget _buildZoneSection(DeliveryViewModel delivery, String? error) {
    final zone = _zone(delivery);
    final name = _zoneName(delivery);
    final closed = _zoneClosed(delivery);
    final loadingZone =
        name == null && _zoneId != null && !delivery.zonesLoaded;
    // Tek adres bölgesi (Devrek) seçiliyse değiştirilecek bir şey yok
    final fixed = zone != null &&
        !closed &&
        delivery.addressZones.length == 1 &&
        delivery.addressZones.single.id == zone.id;

    final String subtitle;
    if (loadingZone) {
      subtitle = 'Bölge bilgisi yükleniyor…';
    } else if (zone != null) {
      subtitle = zoneSubtitle(zone);
    } else if (name != null && closed) {
      // Uzun açıklama altta uyarı olarak çıkar (düzenlemede)
      subtitle = _isEdit ? 'Teslimat şu an kapalı' : zoneClosedNote;
    } else {
      subtitle = 'Adresinin bölgesini seç';
    }

    final row = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          MarketIconTile(
            icon: switch (_zoneType(delivery)) {
              DeliveryZoneType.koy => Icons.cottage_rounded,
              DeliveryZoneType.yurt => Icons.apartment_rounded,
              _ => Icons.location_city_rounded,
            },
            size: 40,
            background:
                closed ? MarketPalette.orangeSoft : MarketPalette.greenSoft,
            foreground:
                closed ? MarketPalette.orangeInk : MarketPalette.greenDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? (loadingZone ? 'Bölge' : 'Bölgeni seç'),
                  style: MarketText.label(size: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: MarketText.caption(
                    color: closed
                        ? MarketPalette.orangeInk
                        : zone != null && (zone.isFree || zone.deliveryFee <= 0)
                            ? MarketPalette.greenDark
                            : MarketPalette.muted,
                    weight: closed || zone != null
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!fixed) ...[
            const SizedBox(width: 8),
            Text(
              name == null ? 'Seç' : 'Değiştir',
              style: MarketText.label(color: MarketPalette.greenDark),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: MarketPalette.greenDark),
          ],
        ],
      ),
    );

    return KeyedSubtree(
      key: _fieldKeys['zone'],
      child: _FormSection(
        title: 'Teslimat bölgesi',
        trailing: fixed ? null : 'Zorunlu',
        error: error != null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: MarketPalette.canvas,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MarketRadius.md),
                side: BorderSide(
                  color: error != null
                      ? MarketPalette.red
                      : closed
                          ? MarketPalette.orange
                          : name == null
                              ? MarketPalette.lineStrong
                              : MarketPalette.green,
                  width: name == null && error == null ? 1 : 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: fixed
                  ? row
                  : InkWell(onTap: _saving ? null : _pickZone, child: row),
            ),
            if (error != null) _ErrorLine(error),
            if (_isEdit && closed && error == null)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: MarketNotice.warning(
                  icon: Icons.block_rounded,
                  text:
                      'Bu bölgeye şu an teslimat yok. Siparişte kullanmak için açık bir bölge seç.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldsSection(
      DeliveryZoneType type, Map<String, String> errors) {
    final directions = _AddressTextField(
      controller: _directions,
      label: type == DeliveryZoneType.yurt
          ? 'Blok / oda (isteğe bağlı)'
          : 'Adres tarifi (isteğe bağlı)',
      hint: type == DeliveryZoneType.yurt
          ? 'Örn. B Blok, oda 214'
          : 'Örn. Eczanenin karşısı, zil çalışmıyor',
      maxLength: AddressFields.directionsMax,
      showCounter: true,
      multiline: true,
    );

    if (type == DeliveryZoneType.yurt) {
      return _FormSection(
        title: 'Yurt bilgisi',
        trailing: 'İsteğe bağlı',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Siparişin yurdun girişinde teslim edilir. İstersen blok ve oda bilgini yaz.',
              style: MarketText.caption(size: 13),
            ),
            const SizedBox(height: 12),
            directions,
          ],
        ),
      );
    }

    final withNeighborhood = type == DeliveryZoneType.ilce;
    return _FormSection(
      title: 'Adres bilgileri',
      trailing: withNeighborhood
          ? 'Mahalle, sokak, bina no zorunlu'
          : 'Sokak zorunlu',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_placeLoading) ...[
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: MarketPalette.green),
                ),
                const SizedBox(width: 8),
                Text('Haritadaki konumundan adres bilgileri dolduruluyor…',
                    style: MarketText.caption()),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (withNeighborhood) ...[
            KeyedSubtree(
              key: _fieldKeys['neighborhood'],
              child: _AddressTextField(
                controller: _neighborhood,
                label: 'Mahalle',
                hint: 'Örn. Cumhuriyet Mahallesi',
                maxLength: AddressFields.neighborhoodMax,
                error: errors['neighborhood'],
                capitalize: true,
              ),
            ),
            const SizedBox(height: 12),
          ],
          KeyedSubtree(
            key: _fieldKeys['street'],
            child: _AddressTextField(
              controller: _street,
              label: 'Sokak / cadde',
              hint: 'Örn. Atatürk Caddesi',
              maxLength: AddressFields.streetMax,
              error: errors['street'],
              capitalize: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: KeyedSubtree(
                  key: _fieldKeys['buildingNo'],
                  child: _AddressTextField(
                    controller: _buildingNo,
                    label:
                        withNeighborhood ? 'Bina no' : 'Bina no (isteğe bağlı)',
                    hint: 'Örn. 5',
                    maxLength: AddressFields.buildingNoMax,
                    error: errors['buildingNo'],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: _AddressTextField(
                  controller: _buildingName,
                  label: 'Bina / site adı',
                  hint: 'Örn. Gül Apt.',
                  maxLength: AddressFields.buildingNameMax,
                  capitalize: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _AddressTextField(
                  controller: _floor,
                  label: 'Kat',
                  hint: 'Örn. 2',
                  maxLength: AddressFields.floorMax,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AddressTextField(
                  controller: _apartment,
                  label: 'Daire',
                  hint: 'Örn. 4',
                  maxLength: AddressFields.apartmentMax,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          directions,
        ],
      ),
    );
  }

  Widget _buildLocationSection(DeliveryZoneType type, String? error) {
    final location = _location;
    final required = _needsLocation(type);
    final Widget body;
    if (location != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AddressMapPreview(point: location),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickLocation,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(MarketSize.buttonSm),
              foregroundColor: MarketPalette.greenDark,
            ),
            icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
            label: const Text('Konumu değiştir'),
          ),
        ],
      );
    } else {
      body = FilledButton.tonalIcon(
        onPressed: _saving ? null : _pickLocation,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(MarketSize.buttonSm),
        ),
        icon: const Icon(Icons.map_outlined, size: 18),
        label: const Text('Haritada işaretle'),
      );
    }

    return KeyedSubtree(
      key: _fieldKeys['location'],
      child: _FormSection(
        title: 'Teslimat konumu',
        trailing: required ? 'Zorunlu' : 'Önerilir',
        error: error != null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              location != null
                  ? 'Kurye seni haritadaki bu noktada arayacak.'
                  : 'Kuryenin seni kolay bulması için kapını haritada işaretle.',
              style: MarketText.caption(size: 13),
            ),
            const SizedBox(height: 12),
            body,
            if (error != null) _ErrorLine(error),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelSection(DeliveryViewModel delivery) {
    final label = _label.text.trim();
    // İlk adres her zaman varsayılan olur; düzenlenen varsayılan adres de
    // ancak başka bir adres varsayılan yapılınca değişir.
    final firstAddress = _isFirstAddress(delivery);
    final alreadyDefault = widget.initial?.isDefault ?? false;
    final locked = firstAddress || alreadyDefault;
    final value = locked || _makeDefault;
    final String? caption = firstAddress
        ? 'İlk adresin otomatik olarak varsayılan olur.'
        : alreadyDefault
            ? 'Bu senin varsayılan adresin. Başka bir adresi varsayılan yapınca değişir.'
            : null;

    return _FormSection(
      title: 'Adres adı',
      trailing: 'İsteğe bağlı',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final preset in _labelPresets)
                MarketChip(
                  label: preset,
                  icon:
                      preset == 'Ev' ? Icons.home_rounded : Icons.work_rounded,
                  selected: !_customLabel && label == preset,
                  onTap: _saving
                      ? null
                      : () => setState(() {
                            _customLabel = false;
                            _label.text = preset;
                          }),
                ),
              MarketChip(
                label: 'Diğer',
                icon: Icons.edit_outlined,
                selected: _customLabel,
                onTap: _saving
                    ? null
                    : () {
                        setState(() => _customLabel = true);
                        if (_labelPresets.contains(_label.text.trim())) {
                          _label.clear();
                        }
                        _labelFocus.requestFocus();
                      },
              ),
            ],
          ),
          if (_customLabel) ...[
            const SizedBox(height: 10),
            _AddressTextField(
              controller: _label,
              focusNode: _labelFocus,
              label: 'Adres adı',
              hint: 'Örn. Annemlerin evi',
              maxLength: AddressFields.labelMax,
              capitalize: true,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Ad vermezsen adres, bölge adıyla görünür.',
            style: MarketText.caption(),
          ),
          const Divider(height: 28, color: MarketPalette.line),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Varsayılan yap', style: MarketText.label(size: 14)),
                    const SizedBox(height: 2),
                    Text(
                      caption ?? 'Siparişte bu adres seçili gelir.',
                      style: MarketText.caption(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: value,
                onChanged: locked || _saving
                    ? null
                    : (next) => setState(() => _makeDefault = next),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar({required bool enabled}) {
    return MarketBottomBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_serverError != null) ...[
            Semantics(
              liveRegion: true,
              child: MarketNotice(
                icon: Icons.error_outline_rounded,
                text: _serverError!,
                background: MarketPalette.redSoft,
                foreground: MarketPalette.red,
              ),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton(
            onPressed: enabled && !_saving ? _save : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(MarketSize.button),
              disabledBackgroundColor: _saving ? MarketPalette.green : null,
              disabledForegroundColor: _saving ? Colors.white : null,
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : Text(_isEdit ? 'Değişiklikleri kaydet' : 'Adresi kaydet'),
          ),
        ],
      ),
    );
  }
}

/// Form bölümü: başlık, sağda "Zorunlu / İsteğe bağlı" notu ve içerik.
class _FormSection extends StatelessWidget {
  final String title;
  final String? trailing;
  final bool error;
  final Widget child;

  const _FormSection({
    required this.title,
    this.trailing,
    this.error = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MarketCard(
      borderColor: error ? MarketPalette.red : MarketPalette.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: MarketText.heading()),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(
                    trailing!,
                    textAlign: TextAlign.end,
                    style: MarketText.caption(),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Adres alanı: uzunluk sınırı sunucuyla aynı; sayaç yalnızca uzun alanda.
class _AddressTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? hint;
  final String? error;
  final int maxLength;
  final bool showCounter;
  final bool multiline;
  final bool capitalize;

  const _AddressTextField({
    required this.controller,
    this.focusNode,
    required this.label,
    this.hint,
    this.error,
    required this.maxLength,
    this.showCounter = false,
    this.multiline = false,
    this.capitalize = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLength: maxLength,
      minLines: multiline ? 2 : 1,
      maxLines: multiline ? 5 : 1,
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      textInputAction:
          multiline ? TextInputAction.newline : TextInputAction.next,
      textCapitalization: capitalize
          ? TextCapitalization.words
          : multiline
              ? TextCapitalization.sentences
              : TextCapitalization.none,
      style: MarketText.body(size: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        errorMaxLines: 3,
        fillColor: MarketPalette.canvas,
        alignLabelWithHint: multiline,
        counterText: showCounter ? null : '',
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  final String text;

  const _ErrorLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: MarketPalette.red),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: MarketText.caption(
                  color: MarketPalette.red, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
