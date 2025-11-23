import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  static WebSocketService? _instance;
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  String? _userId;

  WebSocketService._();

  static WebSocketService get instance {
    _instance ??= WebSocketService._();
    return _instance!;
  }

  Stream<Map<String, dynamic>> get messageStream {
    _messageController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _messageController!.stream;
  }

  bool get isConnected => _isConnected;

  Future<void> connect({String? userId}) async {
    if (_isConnected) return;
    
    _userId = userId;
    
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://devrekbenimmarketim.com/ws'),
      );

      _channel!.stream.listen(
        (data) {
          try {
            final message = json.decode(data);
            _messageController?.add(message);
          } catch (e) {
            print('WebSocket message parse error: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          print('WebSocket connection closed');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      _isConnected = true;
      print('WebSocket connected');
      
      // Kullanıcı ID'si varsa gönder
      if (_userId != null) {
        sendMessage({
          'type': 'auth',
          'userId': _userId,
        });
      }
    } catch (e) {
      print('WebSocket connection error: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(json.encode(message));
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        connect(userId: _userId);
      }
    });
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _channel?.sink.close(status.goingAway);
    _isConnected = false;
    _messageController?.close();
    _messageController = null;
  }

  // Sipariş durumu güncellemeleri için
  void subscribeToOrderUpdates(String orderId) {
    sendMessage({
      'type': 'subscribe',
      'channel': 'order_updates',
      'orderId': orderId,
    });
  }

  // Genel bildirimler için
  void subscribeToNotifications() {
    sendMessage({
      'type': 'subscribe',
      'channel': 'notifications',
    });
  }
}
