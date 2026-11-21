import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';

class PadreLiveTrackingService {
  WebSocketChannel? _channel;

  Future<Stream<Map<String, dynamic>>> conectarWebSocketRuta(int rutaId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final uri = Uri.parse('${ApiClient.wsBaseUrl}/api/gps/ws/rutas/$rutaId?token=$token');
    _channel = WebSocketChannel.connect(uri);

    return _channel!.stream.map((mensajeTexto) {
      return jsonDecode(mensajeTexto as String) as Map<String, dynamic>;
    });
  }

  void desconectar() {
    _channel?.sink.close();
  }
}

