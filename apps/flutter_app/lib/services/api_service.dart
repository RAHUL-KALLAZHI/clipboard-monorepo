import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String server = "https://clipboard-monorepo.onrender.com";

  static Future<Map<String, dynamic>> confirmPair(
      String pairingId, String code, String mobileDeviceId) async {
    final resp = await http.post(
      Uri.parse("$server/pair/confirm"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "pairingId": pairingId,
        "code": code,
        "mobileDeviceId": mobileDeviceId
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception(resp.body);
    }

    return jsonDecode(resp.body);
  }

  static Future<void> disconnect(String mobileToken) async {
    await http.post(
      Uri.parse("$server/pair/disconnect"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"mobileToken": mobileToken}),
    );
  }
}
