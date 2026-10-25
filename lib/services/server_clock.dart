import 'package:flutter/foundation.dart';

/// Sunucu saati. Telefonun saati yanlış olabilir (elle ayarlanmış, saat
/// dilimi hatalı); flash sale'in başlayıp bitmesi ve geri sayımlar sunucu
/// saatine göre hesaplanır.
///
/// `/flash-sales/active` yanıtındaki `serverTime` ile
/// `fark = sunucu saati − telefon saati` bulunur; [now] telefonun saatine bu
/// farkı ekler. Fark henüz bilinmiyorsa telefonun saati kullanılır.
///
/// Fark belirgin biçimde (1 sn'den fazla) değişince dinleyenlere haber verilir
/// (ör. bitmiş sanılıp durmuş bir geri sayım yeniden başlar).
class ServerClock extends ChangeNotifier {
  ServerClock({DateTime Function()? deviceClock})
      : _deviceClock = deviceClock ?? DateTime.now;

  /// Uygulamanın ortak saati (ekrandaki geri sayımlar bunu okur).
  static final ServerClock instance = ServerClock();

  final DateTime Function() _deviceClock;
  Duration _offset = Duration.zero;
  bool _synced = false;

  /// Sunucu saati − telefon saati.
  Duration get offset => _offset;

  /// Sunucu saati en az bir kez okundu mu.
  bool get isSynced => _synced;

  /// Sunucuya göre şimdiki zaman.
  DateTime now() => _deviceClock().add(_offset);

  /// Telefonun kendi saati (fark eklenmemiş).
  DateTime deviceNow() => _deviceClock();

  /// [serverTime], telefonun saatiyle [deviceTime] anında okunmuş sunucu
  /// saatidir (verilmezse şimdi). İsteğin gidiş-dönüş süresinin ortası
  /// verilirse ağ gecikmesinin etkisi yarıya iner.
  void sync(DateTime serverTime, {DateTime? deviceTime}) {
    final next = serverTime.difference(deviceTime ?? _deviceClock());
    final changed = (next - _offset).abs() > const Duration(seconds: 1);
    _offset = next;
    _synced = true;
    if (changed) notifyListeners();
  }

  /// Yalnızca testler için: farkı sıfırlar.
  @visibleForTesting
  void reset() {
    _offset = Duration.zero;
    _synced = false;
  }
}
