/// Chat ve Message modelleri

class ChatModel {
  final String id;
  final String? orderId;
  final String type; // "order" | "general"
  final String status; // "active" | "closed"
  final String lastMessage;
  final DateTime lastMessageAt;
  final String lastMessageSender;
  final int userUnreadCount;

  ChatModel({
    required this.id,
    this.orderId,
    required this.type,
    required this.status,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastMessageSender,
    required this.userUnreadCount,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    // order alanı Map (populated) veya String (sadece ID) olabilir
    String? orderId;
    if (json['order'] != null) {
      if (json['order'] is Map) {
        orderId = json['order']['_id']?.toString();
      } else if (json['order'] is String) {
        orderId = json['order'];
      }
    }
    
    return ChatModel(
      id: json['_id'] ?? '',
      orderId: orderId,
      type: json['type'] ?? 'general',
      status: json['status'] ?? 'active',
      lastMessage: json['lastMessage'] ?? '',
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'])
          : DateTime.now(),
      lastMessageSender: json['lastMessageSender'] ?? 'user',
      userUnreadCount: json['userUnreadCount'] is int 
          ? json['userUnreadCount'] 
          : (int.tryParse(json['userUnreadCount']?.toString() ?? '0') ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'order': orderId,
      'type': type,
      'status': status,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'lastMessageSender': lastMessageSender,
      'userUnreadCount': userUnreadCount,
    };
  }
}

class MessageModel {
  final String id;
  final String chatId;
  final String sender; // "user" | "admin"
  final String senderName;
  final String content;
  final String type; // "text" | "image" | "file" | "system"
  final String? fileUrl;
  final String? fileName;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.sender,
    required this.senderName,
    required this.content,
    required this.type,
    this.fileUrl,
    this.fileName,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id'] ?? '',
      chatId: json['chat'] ?? '',
      sender: json['sender'] ?? 'user',
      senderName: json['senderName'] ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      isRead: json['isRead'] ?? false,
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'chat': chatId,
      'sender': sender,
      'senderName': senderName,
      'content': content,
      'type': type,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Geçici mesaj oluştur (gönderim öncesi)
  factory MessageModel.temporary({
    required String chatId,
    required String content,
    String type = 'text',
    String? fileUrl,
    String? fileName,
  }) {
    return MessageModel(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      chatId: chatId,
      sender: 'user',
      senderName: '',
      content: content,
      type: type,
      fileUrl: fileUrl,
      fileName: fileName,
      isRead: false,
      createdAt: DateTime.now(),
    );
  }
}
