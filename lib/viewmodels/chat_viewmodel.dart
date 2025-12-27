import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final SocketService _socketService = SocketService.instance;

  // State
  List<ChatModel> _chats = [];
  ChatModel? _activeChat;
  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _isTyping = false;
  String? _error;
  bool _hasMoreMessages = true;
  int _currentPage = 1;

  // Socket subscriptions
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;
  Timer? _typingTimer;

  // Getters
  List<ChatModel> get chats => _chats;
  ChatModel? get activeChat => _activeChat;
  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isTyping => _isTyping;
  String? get error => _error;
  bool get hasMoreMessages => _hasMoreMessages;
  
  /// Toplam okunmamış mesaj sayısı
  int get totalUnreadCount => _chats.fold(0, (sum, chat) => sum + chat.userUnreadCount);
  
  /// Sipariş saatleri içinde mi kontrol et (API'den güncel veri çekerek)
  Future<bool> isWithinChatHours() async {
    try {
      final apiService = ApiService();
      final settings = await apiService.getSettings();
      
      final now = DateTime.now();
      final currentHour = now.hour;
      final currentMinute = now.minute;
      
      final startHour = settings['orderStartHour'] ?? 10;
      final startMinute = settings['orderStartMinute'] ?? 0;
      final endHour = settings['orderEndHour'] ?? 1;
      final endMinute = settings['orderEndMinute'] ?? 0;
      
      final startTime = startHour * 60 + startMinute;
      final endTime = endHour * 60 + endMinute;
      final currentTime = currentHour * 60 + currentMinute;
      
      // Gece yarısını geçen saatler için özel kontrol
      if (endTime < startTime) {
        return currentTime >= startTime || currentTime <= endTime;
      } else {
        return currentTime >= startTime && currentTime <= endTime;
      }
    } catch (e) {
      print('ChatViewModel: Error checking chat hours: $e');
      return false; // Hata durumunda erişime izin verme
    }
  }
  
  /// Sipariş saatleri mesajını al
  Future<String> getChatHoursMessage() async {
    try {
      final apiService = ApiService();
      final settings = await apiService.getSettings();
      
      final startHour = (settings['orderStartHour'] ?? 10).toString().padLeft(2, '0');
      final startMinute = (settings['orderStartMinute'] ?? 0).toString().padLeft(2, '0');
      final endHour = (settings['orderEndHour'] ?? 1).toString().padLeft(2, '0');
      final endMinute = (settings['orderEndMinute'] ?? 0).toString().padLeft(2, '0');
      
      return 'Canlı destek sadece $startHour:$startMinute - $endHour:$endMinute saatleri arasında aktiftir.';
    } catch (e) {
      return 'Canlı destek şu an aktif değil.';
    }
  }

  ChatViewModel() {
    _initSocketListeners();
  }

  /// Socket dinleyicilerini başlat
  void _initSocketListeners() {
    _messageSubscription = _socketService.messageStream.listen((data) {
      _handleSocketMessage(data);
    });

    _typingSubscription = _socketService.typingStream.listen((chatId) {
      if (chatId.isNotEmpty && _activeChat?.id == chatId) {
        _isTyping = true;
        notifyListeners();
        
        // 3 saniye sonra typing'i kapat
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          _isTyping = false;
          notifyListeners();
        });
      } else {
        _isTyping = false;
        notifyListeners();
      }
    });
  }

  /// Socket mesajlarını işle
  void _handleSocketMessage(Map<String, dynamic> data) {
    final type = data['type'];
    
    if (type == 'messagesRead') {
      // Mesajlar okundu
      final chatId = data['chatId'];
      if (chatId == _activeChat?.id) {
        _messages = _messages.map((m) {
          if (m.sender == 'user' && !m.isRead) {
            return MessageModel(
              id: m.id,
              chatId: m.chatId,
              sender: m.sender,
              senderName: m.senderName,
              content: m.content,
              type: m.type,
              fileUrl: m.fileUrl,
              fileName: m.fileName,
              isRead: true,
              readAt: DateTime.now(),
              createdAt: m.createdAt,
            );
          }
          return m;
        }).toList();
        notifyListeners();
      }
    } else if (type == 'chatClosed') {
      // Sohbet kapatıldı
      final chatId = data['chatId'];
      if (chatId == _activeChat?.id) {
        _activeChat = ChatModel(
          id: _activeChat!.id,
          orderId: _activeChat!.orderId,
          type: _activeChat!.type,
          status: 'closed',
          lastMessage: _activeChat!.lastMessage,
          lastMessageAt: _activeChat!.lastMessageAt,
          lastMessageSender: _activeChat!.lastMessageSender,
          userUnreadCount: 0,
        );
        notifyListeners();
      }
    } else if (data['message'] != null) {
      // Yeni mesaj geldi
      final message = MessageModel.fromJson(data['message']);
      if (message.chatId == _activeChat?.id) {
        // Kullanıcının kendi gönderdiği mesajları tekrar ekleme (zaten API ile eklendi)
        if (message.sender != 'user') {
          // Aynı mesaj yoksa ekle
          if (!_messages.any((m) => m.id == message.id)) {
            _messages.add(message);
            notifyListeners();
          }
        }
      }
      
      // Sohbet listesini güncelle (sadece admin mesajları için)
      if (message.sender != 'user') {
        _updateChatInList(message);
      }
    }
  }

  /// Sohbet listesindeki son mesajı güncelle
  void _updateChatInList(MessageModel message) {
    final index = _chats.indexWhere((c) => c.id == message.chatId);
    if (index != -1) {
      final chat = _chats[index];
      
      // Aktif sohbetteyken okunmamış sayısını artırma
      final isInActiveChat = _activeChat?.id == message.chatId;
      final newUnreadCount = (message.sender == 'admin' && !isInActiveChat)
          ? chat.userUnreadCount + 1 
          : (isInActiveChat ? 0 : chat.userUnreadCount);
      
      _chats[index] = ChatModel(
        id: chat.id,
        orderId: chat.orderId,
        type: chat.type,
        status: chat.status,
        lastMessage: message.content,
        lastMessageAt: message.createdAt,
        lastMessageSender: message.sender,
        userUnreadCount: newUnreadCount,
      );
      
      // Listeyi son mesaja göre sırala
      _chats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      notifyListeners();
    }
  }

  /// Socket bağlantısını başlat
  Future<void> connectSocket({String? userId}) async {
    await _socketService.connect(userId: userId);
  }

  /// Kullanıcının sohbetlerini yükle
  Future<void> loadChats() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _chats = await _chatService.getMyChats();
      _chats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    } catch (e) {
      _error = 'Sohbetler yüklenirken hata oluştu';
      print('ChatViewModel: Load chats error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Yeni sohbet başlat
  Future<ChatModel?> startChat({String? orderId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Önce sipariş saatlerini kontrol et
      final isWithinHours = await isWithinChatHours();
      if (!isWithinHours) {
        final message = await getChatHoursMessage();
        _error = message;
        _isLoading = false;
        notifyListeners();
        return null;
      }
      
      // Aktif (kapanmamış) sohbet var mı kontrol et
      final activeChats = _chats.where((c) => c.status == 'active').toList();
      if (activeChats.isNotEmpty && orderId == null) {
        // Mevcut aktif sohbete yönlendir
        _error = 'Zaten aktif bir sohbetiniz var';
        _isLoading = false;
        notifyListeners();
        return activeChats.first; // Mevcut aktif sohbeti döndür
      }
      
      final response = await _chatService.createChat(orderId: orderId);
      
      if (response.isNew) {
        // Yeni sohbet, listeye ekle
        _chats.insert(0, response.chat);
      }

      // Aktif sohbeti ayarla
      _activeChat = response.chat;
      
      // Mesajları yükle
      await loadMessages(response.chat.id);

      // Socket odasına katıl ve admin'e bildir (platform ve versiyon ile)
      _socketService.joinChat(response.chat.id);
      _socketService.notifyUserInChat(
        response.chat.id,
        platform: Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'unknown'),
        appVersion: '3.0.0', // package_info_plus ile alınabilir
      );

      return response.chat;
    } catch (e) {
      _error = 'Sohbet başlatılırken hata oluştu';
      print('ChatViewModel: Start chat error: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mevcut sohbeti aç
  Future<void> openChat(ChatModel chat) async {
    // Önceki sohbetten çık
    if (_activeChat != null) {
      _socketService.notifyUserLeftChat(_activeChat!.id);
      _socketService.leaveChat(_activeChat!.id);
    }

    _activeChat = chat;
    _messages = [];
    _currentPage = 1;
    _hasMoreMessages = true;
    notifyListeners();

    // Mesajları yükle
    await loadMessages(chat.id);

    // Socket odasına katıl ve admin'e bildir (platform ve versiyon ile)
    _socketService.joinChat(chat.id);
    _socketService.notifyUserInChat(
      chat.id,
      platform: Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'unknown'),
      appVersion: '3.0.0', // package_info_plus ile alınabilir
    );

    // Mesajları okundu işaretle
    await markAsRead(chat.id);
  }

  /// Aktif sohbetten çık
  void closeActiveChat() {
    if (_activeChat != null) {
      // Admin'e kullanıcının çıktığını bildir
      _socketService.notifyUserLeftChat(_activeChat!.id);
      // Socket odasından ayrıl
      _socketService.leaveChat(_activeChat!.id);
      
      _activeChat = null;
      _messages = [];
      notifyListeners();
    }
  }

  /// Mesajları yükle
  Future<void> loadMessages(String chatId, {bool loadMore = false}) async {
    if (loadMore) {
      if (!_hasMoreMessages) return;
      _currentPage++;
    } else {
      _currentPage = 1;
      _messages = [];
    }

    _isLoading = !loadMore;
    notifyListeners();

    try {
      final response = await _chatService.getChatMessages(
        chatId,
        page: _currentPage,
      );

      if (loadMore) {
        _messages = [...response.messages, ..._messages];
      } else {
        _messages = response.messages;
      }

      _hasMoreMessages = response.hasMore;
      
      if (response.chat != null) {
        _activeChat = response.chat;
      }
    } catch (e) {
      _error = 'Mesajlar yüklenirken hata oluştu';
      print('ChatViewModel: Load messages error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mesaj gönder
  Future<bool> sendMessage(String content, {String type = 'text'}) async {
    if (_activeChat == null || content.trim().isEmpty) return false;

    _isSending = true;
    notifyListeners();

    // Geçici mesaj ekle (optimistic update)
    final tempMessage = MessageModel.temporary(
      chatId: _activeChat!.id,
      content: content,
      type: type,
    );
    _messages.add(tempMessage);
    notifyListeners();

    try {
      final message = await _chatService.sendMessage(
        chatId: _activeChat!.id,
        content: content,
        type: type,
      );

      // Geçici mesajı gerçek mesajla değiştir
      final index = _messages.indexWhere((m) => m.id == tempMessage.id);
      if (index != -1) {
        _messages[index] = message;
      }

      // Sohbet listesini güncelle
      _updateChatInList(message);

      return true;
    } catch (e) {
      // Geçici mesajı kaldır
      _messages.removeWhere((m) => m.id == tempMessage.id);
      _error = 'Mesaj gönderilemedi';
      print('ChatViewModel: Send message error: $e');
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Mesajları okundu işaretle
  Future<void> markAsRead(String chatId) async {
    await _chatService.markAsRead(chatId);
    
    // Lokal state'i güncelle
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      final chat = _chats[index];
      _chats[index] = ChatModel(
        id: chat.id,
        orderId: chat.orderId,
        type: chat.type,
        status: chat.status,
        lastMessage: chat.lastMessage,
        lastMessageAt: chat.lastMessageAt,
        lastMessageSender: chat.lastMessageSender,
        userUnreadCount: 0,
      );
      notifyListeners();
    }
  }

  /// Yazıyor göstergesi gönder
  void sendTyping() {
    if (_activeChat != null) {
      _socketService.sendTyping(_activeChat!.id);
    }
  }

  /// Yazmayı bıraktı göstergesi gönder
  void sendStopTyping() {
    if (_activeChat != null) {
      _socketService.sendStopTyping(_activeChat!.id);
    }
  }


  /// Hata mesajını temizle
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingTimer?.cancel();
    if (_activeChat != null) {
      _socketService.notifyUserLeftChat(_activeChat!.id);
      _socketService.leaveChat(_activeChat!.id);
    }
    super.dispose();
  }
}
