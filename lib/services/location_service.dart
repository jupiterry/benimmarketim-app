import 'package:geolocator/geolocator.dart';

import '../models/delivery.dart';
import 'app_logger.dart';

/// "Konumumu kullan" sonucu.
enum LocationOutcome { found, denied, deniedForever, serviceOff, failed }

/// Tek seferlik konum. Yalnızca kullanıcı butona bastığında, uygulama açıkken
/// çağrılır; arka planda konum alınmaz. İzin verilmezse adres konumsuz
/// kaydedilir.
class LocationService {
  const LocationService();

  Future<({LocationOutcome outcome, GeoPoint? point})> currentPoint() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (outcome: LocationOutcome.serviceOff, point: null);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return (outcome: LocationOutcome.deniedForever, point: null);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return (outcome: LocationOutcome.denied, point: null);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (
        outcome: LocationOutcome.found,
        point: GeoPoint(position.latitude, position.longitude),
      );
    } catch (e) {
      AppLogger.debug('Konum alınamadı: $e');
      return (outcome: LocationOutcome.failed, point: null);
    }
  }

  /// İzin kalıcı reddedildiyse uygulama ayarlarını açar.
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Konum servisi kapalıysa cihazın konum ayarlarını açar.
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
