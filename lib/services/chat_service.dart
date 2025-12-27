import 'package:dio/dio.dart';
import '../models/chat_model.dart';
import 'api_service.dart';
import 'token_manager.dart';

class ChatService {
  static const String baseUrl = ApiService.baseUrl;
  late Dio _dio;

  ChatService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Token interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenManager.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  /// Yeni sohbet başlat veya mevcut aktif sohbeti getir
  Future<ChatResponse> createChat({String? orderId, String type = 'general'}) async {
    try {
      print('ChatService: Creating chat - orderId: $orderId, type: $type');
      
      final response = await _dio.post('/chat/create', data: {
        'orderId': orderId,
        'type': orderId != null ? 'order' : type,
      });

      print('ChatService: Create response: ${response.data}');

      if (response.data['success'] == true) {
        final chat = ChatModel.fromJson(response.data['chat']);
        final isNew = response.data['isNew'] ?? false;
        MessageModel? welcomeMessage;
        
        if (response.data['welcomeMessage'] != null) {
          welcomeMessage = MessageModel.fromJson(response.data['welcomeMessage']);
        }

        return ChatResponse(
          success: true,
          chat: chat,
          isNew: isNew,
          welcomeMessage: welcomeMessage,
        );
      }

      throw Exception('Sohbet oluşturulamadı');
    } catch (e) {
      print('ChatService: Create chat error: $e');
      rethrow;
    }
  }

  /// Kullanıcının sohbetlerini getir
  Future<List<ChatModel>> getMyChats() async {
    try {
      print('ChatService: Getting my chats...');
      
      final response = await _dio.get('/chat/my-chats');

      print('ChatService: My chats response: ${response.data}');

      if (response.data['success'] == true && response.data['chats'] != null) {
        final List<dynamic> chatsData = response.data['chats'];
        return chatsData.map((json) => ChatModel.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('ChatService: Get my chats error: $e');
      return [];
    }
  }

  /// Sohbet mesajlarını getir
  Future<MessagesResponse> getChatMessages(String chatId, {int page = 1, int limit = 50}) async {
    try {
      print('ChatService: Getting messages for chat: $chatId');
      
      final response = await _dio.get(
        '/chat/$chatId',
        queryParameters: {'page': page, 'limit': limit},
      );

      print('ChatService: Messages response: ${response.data}');

      if (response.data['success'] == true) {
        final List<dynamic> messagesData = response.data['messages'] ?? [];
        final messages = messagesData.map((json) => MessageModel.fromJson(json)).toList();
        final chat = response.data['chat'] != null 
            ? ChatModel.fromJson(response.data['chat']) 
            : null;
        final hasMore = response.data['hasMore'] ?? false;

        return MessagesResponse(
          success: true,
          messages: messages,
          chat: chat,
          hasMore: hasMore,
        );
      }

      throw Exception('Mesajlar alınamadı');
    } catch (e) {
      print('ChatService: Get messages error: $e');
      rethrow;
    }
  }

  /// Mesaj gönder
  Future<MessageModel> sendMessage({
    required String chatId,
    required String content,
    String type = 'text',
    String? fileUrl,
    String? fileName,
  }) async {
    try {
      print('ChatService: Sending message to chat: $chatId');
      
      final response = await _dio.post('/chat/$chatId/send', data: {
        'content': content,
        'type': type,
        'fileUrl': fileUrl,
        'fileName': fileName,
      });

      print('ChatService: Send message response: ${response.data}');

      if (response.data['success'] == true && response.data['message'] != null) {
        return MessageModel.fromJson(response.data['message']);
      }

      throw Exception('Mesaj gönderilemedi');
    } catch (e) {
      print('ChatService: Send message error: $e');
      rethrow;
    }
  }

  /// Mesajları okundu olarak işaretle
  Future<bool> markAsRead(String chatId) async {
    try {
      print('ChatService: Marking messages as read for chat: $chatId');
      
      final response = await _dio.put('/chat/$chatId/read');

      return response.data['success'] == true;
    } catch (e) {
      print('ChatService: Mark as read error: $e');
      return false;
    }
  }
}

/// Chat oluşturma response'u
class ChatResponse {
  final bool success;
  final ChatModel chat;
  final bool isNew;
  final MessageModel? welcomeMessage;

  ChatResponse({
    required this.success,
    required this.chat,
    required this.isNew,
    this.welcomeMessage,
  });
}

/// Mesajları getirme response'u
class MessagesResponse {
  final bool success;
  final List<MessageModel> messages;
  final ChatModel? chat;
  final bool hasMore;

  MessagesResponse({
    required this.success,
    required this.messages,
    this.chat,
    required this.hasMore,
  });
}
