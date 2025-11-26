import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../services/api_service.dart';
import '../utils/animated_route.dart';
import 'clipboard_screen.dart';
import 'qr_scan_page.dart';

class PairingScreen extends StatefulWidget {
  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final pairingIdCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final String mobileDeviceId = Uuid().v4();
  String? error;

  void _pair(String pairingId, String code) async {
    setState(() => error = null);
    try {
      final result = await ApiService.confirmPair(
        pairingId,
        code,
        mobileDeviceId,
      );

      final mobileToken = result["mobileToken"];

      Navigator.pushReplacement(
        context,
        AnimatedRoute.slideFade(
          ClipboardScreen(mobileToken: mobileToken),
        ),
      );
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  void openQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRScanPage(
          onScanned: (result) {
            try {
              final obj = jsonDecode(result);
              _pair(obj["pairingId"], obj["code"]);
            } catch (_) {
              setState(() => error = "Invalid QR code");
            }
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    pairingIdCtrl.clear();
    codeCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      body: Column(
        children: [
          // 🔵 HEADER
          Container(
            padding: EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 40),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Clipboard Sync",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Pair your device to start syncing clipboard",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  // ⚠️ ERROR CARD
                  if (error != null)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(width: 10),
                          Expanded(
                              child: Text(error!,
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ),

                  SizedBox(height: 20),

                  // 🔍 SCAN QR BUTTON (CARD)
                  GestureDetector(
                    onTap: openQRScanner,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner,
                              color: Colors.white, size: 32),
                          SizedBox(width: 12),
                          Text(
                            "Scan QR Code",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 25),

                  // MANUAL PAIRING CARD
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Manual Pairing",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        SizedBox(height: 12),
                        TextField(
                          controller: pairingIdCtrl,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            labelText: "Pairing ID",
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: codeCtrl,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            labelText: "Pairing Code",
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            backgroundColor: Color(0xFF667EEA),
                          ),
                          onPressed: () => _pair(
                              pairingIdCtrl.text.trim(), codeCtrl.text.trim()),
                          child: Text("Pair Now",
                              style:
                                  TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
