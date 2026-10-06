import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'token_manager.dart';
import 'app_logger.dart';

class SocketService {
  static SocketService? _instance;
  IO.Socket? _socket;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _typingController =
      StreamController<String>.broadcast();

  bool _isConnected = false;
  String? _userId;
  String? _currentChatId;

  SocketService._();

  static SocketService get instance {
    _instance ??= SocketService._();
    return _instance!;
  }

  /// Mesaj stream'i
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Yazıyor göstergesi stream'i
  Stream<String> get typingStream => _typingController.stream;

  bool get isConnected => _isConnected;

  /// Socket.IO bağlantısını başlat
  Future<void> connect({String? userId}) async {
    if (_isConnected && _socket != null) {
      AppLogger.debug('SocketService: Already connected');
      return;
    }

    _userId = userId;

    try {
      final token = await TokenManager.getAccessToken();
      _socket = IO.io(
        'https://devrekbenimmarketim.com',
        IO.OptionBuilder()
            .setTransports(
                ['websocket', 'polling']) // Polling'i de ekle fallback için
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setAuth({'token': token})
            .build(),
      );

      _socket!.onConnect((_) {
        AppLogger.debug('SocketService: ✅ Connected to server');
        _isConnected = true;

        // Eğer aktif sohbet varsa yeniden katıl
        if (_currentChatId != null) {
          _socket!.emit('joinChat', _currentChatId);
          AppLogger.debug('SocketService: Reconnected, rejoined chat: $_currentChatId');
        }
      });

      _socket!.onDisconnect((_) {
        AppLogger.debug('SocketService: ❌ Disconnected from server');
        _isConnected = false;
      });

      _socket!.onConnectError((error) {
        AppLogger.debug('SocketService: ⚠️ Connection error: $error');
        _isConnected = false;
      });

      _socket!.onError((error) {
        AppLogger.debug('SocketService: ⚠️ Socket error: $error');
      });

      // Yeni mesaj event'i
      _socket!.on('newMessage', (data) {
        AppLogger.debug('SocketService: 📩 New message received');
        try {
          if (data is Map) {
            _messageController.add(Map<String, dynamic>.from(data));
          } else if (data is Map<String, dynamic>) {
            _messageController.add(data);
          } else {
            AppLogger.debug('SocketService: Unknown data type: ${data.runtimeType}');
          }
        } catch (e) {
          AppLogger.debug('SocketService: Error processing message: $e');
        }
      });

      // Mesaj okundu event'i
      _socket!.on('messagesRead', (data) {
        AppLogger.debug('SocketService: ✓ Messages read');
        try {
          Map<String, dynamic> result = {};
          if (data is Map) {
            result = Map<String, dynamic>.from(data);
          }
          result['type'] = 'messagesRead';
          _messageController.add(result);
        } catch (e) {
          AppLogger.debug('SocketService: Error processing messagesRead: $e');
        }
      });

      // Yazıyor göstergesi
      _socket!.on('userTyping', (data) {
        AppLogger.debug('SocketService: ⌨️ User typing');
        if (data is Map && data['chatId'] != null) {
          _typingController.add(data['chatId'].toString());
        }
      });

      _socket!.on('userStopTyping', (data) {
        AppLogger.debug('SocketService: ⌨️ User stop typing');
        if (data is Map && data['chatId'] != null) {
          _typingController.add(''); // Boş string = yazmıyor
        }
      });

      // Sohbet kapatıldı event'i
      _socket!.on('chatClosed', (data) {
        AppLogger.debug('SocketService: 🔒 Chat closed');
        try {
          Map<String, dynamic> result = {};
          if (data is Map) {
            result = Map<String, dynamic>.from(data);
          }
          result['type'] = 'chatClosed';
          _messageController.add(result);
        } catch (e) {
          AppLogger.debug('SocketService: Error processing chatClosed: $e');
        }
      });

      _socket!.connect();
    } catch (e) {
      AppLogger.debug('SocketService: ❌ Connection error: $e');
      _isConnected = false;
    }
  }

  /// Sohbet odasına katıl
  void joinChat(String chatId) {
    _currentChatId = chatId;
    if (_socket != null && _isConnected) {
      _socket!.emit('joinChat', chatId);
      AppLogger.debug('SocketService: 🚪 Joined chat room: $chatId');
    } else {
      AppLogger.debug(
          'SocketService: ⚠️ Not connected, will join $chatId when connected');
    }
  }

  /// Sohbet odasından ayrıl
  void leaveChat(String chatId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('leaveChat', chatId);
      AppLogger.debug('SocketService: 🚪 Left chat room: $chatId');
    }
    if (_currentChatId == chatId) {
      _currentChatId = null;
    }
  }

  /// Yazıyor göstergesi gönder
  void sendTyping(String chatId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('typing', {
        'chatId': chatId,
        'sender': 'user',
      });
    }
  }

  /// Yazmayı bıraktı göstergesi gönder
  void sendStopTyping(String chatId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('stopTyping', {
        'chatId': chatId,
        'sender': 'user',
      });
    }
  }

  /// Kullanıcı sohbete girdi - admin'e bildir
  void notifyUserInChat(String chatId,
      {String? userId,
      String? userName,
      String? platform,
      String? appVersion}) {
    if (_socket != null && _isConnected) {
      _socket!.emit('userInChat', {
        'chatId': chatId,
        'userId': userId ?? _userId,
        'userName': userName,
        'platform': platform,
        'appVersion': appVersion,
      });
      AppLogger.debug(
          'SocketService: 👀 User entered chat: $chatId (platform: $platform, v$appVersion)');
    }
  }

  /// Kullanıcı sohbetten çıktı - admin'e bildir
  void notifyUserLeftChat(String chatId, {String? userId}) {
    if (_socket != null && _isConnected) {
      _socket!.emit('userLeftChat', {
        'chatId': chatId,
        'userId': userId ?? _userId,
      });
      AppLogger.debug('SocketService: 👋 User left chat: $chatId');
    }
  }

  /// Bağlantıyı kes
  Future<void> disconnect() async {
    if (_currentChatId != null) {
      notifyUserLeftChat(_currentChatId!);
      leaveChat(_currentChatId!);
    }

    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    AppLogger.debug('SocketService: Disconnected');
  }

  /// Servisi temizle
  void dispose() {
    _messageController.close();
    _typingController.close();
    disconnect();
  }
}
