class Photocopy {
  final String id;
  final String fileName;
  final String originalName;
  final String filePath;
  final String fileType;
  final int fileSize;
  final int copies;
  final String color;
  final String paperSize;
  final String notes;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final double? price;
  final String? downloadUrl;
  /// Ödeme alındı mı (admin işaretler)
  final bool isPaid;
  /// Marketin isteğe yazdığı not (varsa)
  final String adminNotes;

  Photocopy({
    required this.id,
    required this.fileName,
    required this.originalName,
    required this.filePath,
    required this.fileType,
    required this.fileSize,
    required this.copies,
    required this.color,
    required this.paperSize,
    required this.notes,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.price,
    this.downloadUrl,
    this.isPaid = false,
    this.adminNotes = '',
  });

  /// Sunucu belgesi: {_id, originalName, mimeType, fileSize, copies, color,
  /// paperSize, notes, adminNotes, status, isPaid, price, createdAt, updatedAt}
  factory Photocopy.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    final price = rawPrice is num ? rawPrice.toDouble() : null;
    return Photocopy(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      fileName: (json['fileName'] ?? json['originalName'] ?? '').toString(),
      originalName: (json['originalName'] ?? '').toString(),
      filePath: (json['filePath'] ?? '').toString(),
      fileType: (json['mimeType'] ?? json['fileType'] ?? '').toString(),
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      copies: (json['copies'] as num?)?.toInt() ?? 1,
      color: (json['color'] ?? 'black_white').toString(),
      paperSize: (json['paperSize'] ?? 'A4').toString(),
      notes: (json['notes'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      // Sunucuda fiyat varsayılan 0'dır; henüz belirlenmemişse gösterilmez.
      price: (price != null && price > 0) ? price : null,
      downloadUrl: json['downloadUrl']?.toString(),
      isPaid: json['isPaid'] == true,
      adminNotes: (json['adminNotes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'originalName': originalName,
      'filePath': filePath,
      'fileType': fileType,
      'fileSize': fileSize,
      'copies': copies,
      'color': color,
      'paperSize': paperSize,
      'notes': notes,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'price': price,
      'downloadUrl': downloadUrl,
      'isPaid': isPaid,
      'adminNotes': adminNotes,
    };
  }

  Photocopy copyWith({
    String? id,
    String? fileName,
    String? originalName,
    String? filePath,
    String? fileType,
    int? fileSize,
    int? copies,
    String? color,
    String? paperSize,
    String? notes,
    String? status,
    DateTime? createdAt,
    DateTime? completedAt,
    double? price,
    String? downloadUrl,
    bool? isPaid,
    String? adminNotes,
  }) {
    return Photocopy(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      originalName: originalName ?? this.originalName,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      copies: copies ?? this.copies,
      color: color ?? this.color,
      paperSize: paperSize ?? this.paperSize,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      price: price ?? this.price,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      isPaid: isPaid ?? this.isPaid,
      adminNotes: adminNotes ?? this.adminNotes,
    );
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Beklemede';
      case 'processing':
        return 'Hazırlanıyor';
      case 'ready':
        return 'Hazır';
      case 'completed':
        return 'Tamamlandı';
      case 'failed':
        return 'Başarısız';
      default:
        return 'Bilinmiyor';
    }
  }

  String get colorText {
    switch (color) {
      case 'black_white':
        return 'Siyah-Beyaz';
      case 'color':
        return 'Renkli';
      default:
        return 'Siyah-Beyaz';
    }
  }

  /// Dosya türü simgesi için sade ad: mime ("application/pdf") ya da uzantı
  /// ("pdf") gelebilir; ikisini de "pdf", "doc", "image" gibi gruplara indirger.
  String get fileKind {
    final type = fileType.toLowerCase();
    if (type.contains('pdf')) return 'pdf';
    if (type.contains('word') || type.contains('msword') || type == 'doc' || type == 'docx') {
      return 'doc';
    }
    if (type.startsWith('image/') ||
        const ['jpg', 'jpeg', 'png', 'tiff', 'bmp'].contains(type)) {
      return 'image';
    }
    return 'other';
  }

  String get fileSizeText {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
