import 'package:flutter/foundation.dart';
import '../models/referral.dart';
import '../models/coupon.dart';
import '../services/api_service.dart';

/// ViewModel for referral system
class ReferralViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  Referral? _referral;
  List<Coupon> _coupons = [];
  bool _isLoading = false;
  bool _couponsLoaded = false;
  String? _error;

  // For code checking on register page
  ReferralCodeCheck? _codeCheck;
  bool _isCheckingCode = false;

  // Getters
  Referral? get referral => _referral;
  List<Coupon> get coupons => _coupons;
  List<Coupon> get validCoupons => _coupons.where((c) => c.isValid).toList();
  List<Coupon> get referralCoupons =>
      _coupons.where((c) => c.isReferralCoupon && c.isValid).toList();
  bool get isLoading => _isLoading;
  bool get couponsLoaded => _couponsLoaded;
  String? get error => _error;
  ReferralCodeCheck? get codeCheck => _codeCheck;
  bool get isCheckingCode => _isCheckingCode;

  /// Load user's referral information
  Future<void> loadReferralInfo() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _referral = await _apiService.getMyReferrals();
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      print('ReferralViewModel loadReferralInfo error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if a referral code is valid (for registration)
  Future<ReferralCodeCheck> checkReferralCode(String code) async {
    if (code.isEmpty) {
      _codeCheck = null;
      notifyListeners();
      return ReferralCodeCheck(isValid: false, message: '');
    }

    _isCheckingCode = true;
    notifyListeners();

    try {
      _codeCheck = await _apiService.checkReferralCode(code);
      return _codeCheck!;
    } catch (e) {
      _codeCheck = ReferralCodeCheck(
        isValid: false,
        message: 'Kod kontrol edilemedi',
      );
      return _codeCheck!;
    } finally {
      _isCheckingCode = false;
      notifyListeners();
    }
  }

  /// Clear the code check result
  void clearCodeCheck() {
    _codeCheck = null;
    notifyListeners();
  }

  /// Regenerate referral code
  Future<bool> regenerateCode() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newReferral = await _apiService.regenerateReferralCode();

      // Update the current referral with new code
      if (_referral != null) {
        _referral = Referral(
          code: newReferral.code,
          link: newReferral.link,
          totalReferrals: _referral!.totalReferrals,
          successfulReferrals: _referral!.successfulReferrals,
          totalRewardsEarned: _referral!.totalRewardsEarned,
          referredUsers: _referral!.referredUsers,
          active: _referral!.active,
          maxReferrals: _referral!.maxReferrals,
          remainingInvites: _referral!.remainingInvites,
          inviteeDiscountPercent: _referral!.inviteeDiscountPercent,
          rewardDiscountPercent: _referral!.rewardDiscountPercent,
          rewardExpiresInDays: _referral!.rewardExpiresInDays,
        );
      } else {
        _referral = newReferral;
      }

      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      print('ReferralViewModel regenerateCode error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load user's coupons
  Future<void> loadCoupons({bool force = false}) async {
    if (_isLoading || (_couponsLoaded && !force)) return;
    _isLoading = true;
    try {
      _coupons = await _apiService.getUserCoupons();
    } catch (e) {
      print('ReferralViewModel loadCoupons error: $e');
    } finally {
      _isLoading = false;
      _couponsLoaded = true;
      notifyListeners();
    }
  }

  /// Clear all data (on logout)
  void clear() {
    _referral = null;
    _coupons = [];
    _couponsLoaded = false;
    _error = null;
    _codeCheck = null;
    notifyListeners();
  }
}
