/// Referral status enum
enum ReferralStatus {
  pending,    // Kayıt oldu, sipariş vermedi
  completed,  // İlk siparişini verdi
  rewarded,   // Ödül verildi (kod devre dışı oldu)
}

/// Extension to convert string to ReferralStatus
extension ReferralStatusExtension on String {
  ReferralStatus toReferralStatus() {
    switch (toLowerCase()) {
      case 'pending':
        return ReferralStatus.pending;
      case 'completed':
        return ReferralStatus.completed;
      case 'rewarded':
        return ReferralStatus.rewarded;
      default:
        return ReferralStatus.pending;
    }
  }
}

/// Referred user model
class ReferredUser {
  final String name;
  final ReferralStatus status;
  final DateTime signedUpAt;
  final DateTime? firstOrderAt;

  ReferredUser({
    required this.name,
    required this.status,
    required this.signedUpAt,
    this.firstOrderAt,
  });

  factory ReferredUser.fromJson(Map<String, dynamic> json) {
    return ReferredUser(
      name: json['name'] ?? '',
      status: (json['status'] as String? ?? 'pending').toReferralStatus(),
      signedUpAt: json['signedUpAt'] != null
          ? DateTime.parse(json['signedUpAt'])
          : DateTime.now(),
      firstOrderAt: json['firstOrderAt'] != null
          ? DateTime.parse(json['firstOrderAt'])
          : null,
    );
  }

  /// Get status display text in Turkish
  String get statusText {
    switch (status) {
      case ReferralStatus.pending:
        return 'Beklemede';
      case ReferralStatus.completed:
        return 'Sipariş Verdi';
      case ReferralStatus.rewarded:
        return 'Ödül Verildi';
    }
  }

  /// Get status color
  String get statusColorHex {
    switch (status) {
      case ReferralStatus.pending:
        return '#FFA500'; // Orange
      case ReferralStatus.completed:
        return '#2196F3'; // Blue
      case ReferralStatus.rewarded:
        return '#4CAF50'; // Green
    }
  }
}

/// Main referral model
class Referral {
  final String code;
  final String link;
  final int totalReferrals;
  final int successfulReferrals;
  final int totalRewardsEarned;
  final List<ReferredUser> referredUsers;

  Referral({
    required this.code,
    required this.link,
    required this.totalReferrals,
    required this.successfulReferrals,
    required this.totalRewardsEarned,
    required this.referredUsers,
  });

  factory Referral.fromJson(Map<String, dynamic> json) {
    return Referral(
      code: json['code'] ?? '',
      link: json['link'] ?? '',
      totalReferrals: json['totalReferrals'] ?? 0,
      successfulReferrals: json['successfulReferrals'] ?? 0,
      totalRewardsEarned: json['totalRewardsEarned'] ?? 0,
      referredUsers: (json['referredUsers'] as List<dynamic>?)
              ?.map((user) => ReferredUser.fromJson(user))
              .toList() ??
          [],
    );
  }

  /// Check if referral code is still active (not yet used successfully)
  bool get isActive => successfulReferrals == 0;
}

/// Referral code check response
class ReferralCodeCheck {
  final bool isValid;
  final String? referrerName;
  final String message;

  ReferralCodeCheck({
    required this.isValid,
    this.referrerName,
    required this.message,
  });

  factory ReferralCodeCheck.fromJson(Map<String, dynamic> json, bool success) {
    return ReferralCodeCheck(
      isValid: success,
      referrerName: json['referrerName'],
      message: json['message'] ?? '',
    );
  }
}
