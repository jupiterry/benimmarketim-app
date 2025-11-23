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
  });

  factory Photocopy.fromJson(Map<String, dynamic> json) {
    return Photocopy(
      id: json['id'] ?? '',
      fileName: json['fileName'] ?? '',
      originalName: json['originalName'] ?? '',
      filePath: json['filePath'] ?? '',
      fileType: json['fileType'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      copies: json['copies'] ?? 1,
      color: json['color'] ?? 'black_white',
      paperSize: json['paperSize'] ?? 'A4',
      notes: json['notes'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
      price: json['price']?.toDouble(),
      downloadUrl: json['downloadUrl'],
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
    );
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Beklemede';
      case 'processing':
        return 'İşleniyor';
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
