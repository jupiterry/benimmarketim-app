class Feedback {
  final String id;
  final int rating;
  final Map<String, int> ratings;
  final String title;
  final String message;
  final String category;
  final String status;
  final String visibility;
  final DateTime createdAt;

  Feedback({
    required this.id,
    required this.rating,
    required this.ratings,
    required this.title,
    required this.message,
    required this.category,
    required this.status,
    required this.visibility,
    required this.createdAt,
  });

  factory Feedback.fromJson(Map<String, dynamic> json) {
    return Feedback(
      id: json['_id'] ?? '',
      rating: json['rating'] ?? 0,
      ratings: Map<String, int>.from(json['ratings'] ?? {}),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      category: json['category'] ?? 'Genel',
      status: json['status'] ?? 'Yeni',
      visibility: json['visibility'] ?? 'public',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      'ratings': ratings,
      'title': title,
      'message': message,
      'category': category,
    };
  }

  // Detaylı rating'ler için getter'lar
  int get usability => ratings['usability'] ?? 0;
  int get expectations => ratings['expectations'] ?? 0;
  int get repeat => ratings['repeat'] ?? 0;
  int get overall => ratings['overall'] ?? 0;

  // Status kontrolü
  bool get isNew => status == 'Yeni';
  bool get isUnderReview => status == 'İnceleniyor';
  bool get isResolved => status == 'Çözüldü';
  bool get isClosed => status == 'Kapatıldı';

  // Kategori kontrolü
  bool get isGeneral => category == 'Genel';
  bool get isSuggestion => category == 'Öneri';
  bool get isComplaint => category == 'Şikayet';
  bool get isBugReport => category == 'Hata Bildirimi';
}
