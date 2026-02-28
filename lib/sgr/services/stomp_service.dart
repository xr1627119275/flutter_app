import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../services/api_service.dart';
import '../utils/storage.dart';

class StompService {
  static StompClient? _stompClient;
  static bool _isConnected = false;

  /// Function to be called when STOMP successfully connects.
  static void Function()? onConnectCallback;

  static bool get isConnected => _isConnected;

  /// Map of topic to list of callbacks.
  static final Map<String, List<void Function(Map<String, dynamic>)>> _subscriptions = {};

  /// Connect to the STOMP endpoint.
  Future<void> connect(void Function() onConnect, void Function(dynamic) onError) async {
    if (_stompClient != null && _isConnected) {
      onConnect();
      return;
    }

    onConnectCallback = onConnect;

    // Build the WebSocket URL from ApiService.baseUrl.
    // When using SockJS, the URL must be http/https, as SockJS will handle the info request
    // and WebSocket upgrade internally.
    String url = ApiService.baseUrl;
    if (!url.endsWith('/')) {
      url += '/';
    }
    url += 'ws-endpoint';

    _stompClient = StompClient(
      config: StompConfig(
        url: url,
        onConnect: _onConnect,
        onWebSocketError: (dynamic error) {
          print('[Stomp] WebSocket error: $error');
          onError(error);
        },
        onStompError: (dynamic error) {
          print('[Stomp] Error: $error');
          onError(error);
        },
        onDisconnect: (dynamic frame) {
          print('[Stomp] Disconnected');
          _isConnected = false;
        },
        stompConnectHeaders: {
          // 'token': await Storage.getToken() ?? '', // Can add headers if backend requires for WS
        },
        webSocketConnectHeaders: {
          // Add auth if necessary
        },
        connectionTimeout: const Duration(seconds: 10),
        useSockJS: true,
      ),
    );

    _stompClient!.activate();
  }

  static void _onConnect(StompFrame frame) {
    print('[Stomp] Connected');
    _isConnected = true;
    
    // Trigger onConnect callback
    if (onConnectCallback != null) {
      onConnectCallback!();
    }

    // Restore subscriptions on reconnect
    _resubscribeAll();
  }

  static void disconnect() {
    if (_stompClient != null) {
      _stompClient!.deactivate();
      _stompClient = null;
      _isConnected = false;
      _subscriptions.clear();
      print('[Stomp] Deactivated');
    }
  }

  /// Subscribe to a specific topic
  static void subscribe(String topic, void Function(Map<String, dynamic>) callback) {
    if (_stompClient == null || !_isConnected) {
      print('[Stomp] Cannot subscribe to $topic: StompClient is not connected.');
      return;
    }

    if (!_subscriptions.containsKey(topic)) {
      _subscriptions[topic] = [];
      _stompClient!.subscribe(
        destination: topic,
        callback: (StompFrame frame) {
          try {
            if (frame.body != null) {
              final Map<String, dynamic> body = jsonDecode(frame.body!);
              final callbacks = _subscriptions[topic];
              if (callbacks != null) {
                for (var cb in callbacks) {
                  cb(body);
                }
              }
            }
          } catch (e) {
            print('[Stomp] JSON Parsing Error for topic $topic: $e');
          }
        },
      );
    }

    if (!_subscriptions[topic]!.contains(callback)) {
      _subscriptions[topic]!.add(callback);
    }
  }

  /// Unsubscribe a specific callback from a topic. (Simplified to just remove the callback for now)
  static void unsubscribe(String topic, void Function(Map<String, dynamic>) callback) {
    if (_subscriptions.containsKey(topic)) {
      _subscriptions[topic]!.remove(callback);
      // Actual STOMP unsubscribe logic should be here if we want to cancel the STOMP subscription entirely
      // However stomp_dart_client returns an unsubscribe fn when you subscribe.
      // To keep it simple like the JS version, we just manage the callbacks array and optionally disconnect.
    }
  }

  static void _resubscribeAll() {
    for (String topic in _subscriptions.keys) {
      _stompClient!.subscribe(
        destination: topic,
        callback: (StompFrame frame) {
          try {
            if (frame.body != null) {
              final Map<String, dynamic> body = jsonDecode(frame.body!);
              final callbacks = _subscriptions[topic];
              if (callbacks != null) {
                for (var cb in callbacks) {
                  cb(body);
                }
              }
            }
          } catch (e) {
            print('[Stomp] JSON Parsing Error: $e');
          }
        },
      );
    }
  }

  /// Send message to a destination
  static void send(String destination, Map<String, dynamic> payload) {
    if (_stompClient == null || !_isConnected) {
      print('[Stomp] Not connected, cannot send message.');
      return;
    }
    _stompClient!.send(
      destination: destination,
      body: jsonEncode(payload),
    );
  }
}
