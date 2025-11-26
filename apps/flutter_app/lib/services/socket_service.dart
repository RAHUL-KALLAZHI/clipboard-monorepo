import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'api_service.dart';

class SocketService {
  IO.Socket? socket;

  IO.Socket connect(
      String token, Function(String) onClipboard, Function onDisconnected) {
    // If old socket exists → destroy it
    if (socket != null) {
      socket!.clearListeners();
      socket!.disconnect();
      socket!.dispose();
      socket = null;
    }

    socket = IO.io(ApiService.server, {
      'transports': ['websocket'],
      'query': {'token': token},
      'autoConnect': true,
      'forceNew': true,
      'reconnection': false,
    });

    socket!.on('connect', (_) => print("Socket connected"));

    socket!.on('new_clipboard', (data) {
      onClipboard(data["text"] ?? "");
    });

    socket!.on('disconnected', (_) {
      onDisconnected();
    });

    return socket!;
  }

  void disconnect() {
    if (socket != null) {
      socket!.clearListeners();
      socket!.disconnect();
      socket!.dispose();
      socket = null;
    }
  }
}
