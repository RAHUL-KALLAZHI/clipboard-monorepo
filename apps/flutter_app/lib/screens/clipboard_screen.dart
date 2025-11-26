import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/animated_route.dart';
import 'pairing_screen.dart';

class ClipboardScreen extends StatefulWidget {
  final String mobileToken;
  ClipboardScreen({required this.mobileToken});

  @override
  State<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends State<ClipboardScreen> {
  String clipboardText = "";
  final socketService = SocketService();

  @override
  void initState() {
    super.initState();
    socketService.connect(
      widget.mobileToken,
      (text) => setState(() => clipboardText = text),
      () => _onDisconnected(),
    );
  }

  void _onDisconnected() {
    Navigator.pushReplacement(
      context,
      AnimatedRoute.fade(PairingScreen()),
    );
  }

  Future<void> _disconnect() async {
    await ApiService.disconnect(widget.mobileToken);

    socketService.socket?.clearListeners();
    socketService.socket?.disconnect();
    socketService.socket?.dispose();
    socketService.socket = null;

    Navigator.pushReplacement(
      context,
      AnimatedRoute.fade(PairingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Synced Clipboard"),
        backgroundColor: Color(0xFF667EEA),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () async {
            final confirm = await showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text("Disconnect?"),
                content: Text("Do you want to unpair and go back?"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text("Cancel")),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text("Disconnect")),
                ],
              ),
            );

            if (confirm == true) _disconnect();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clipboard card
            buildClipboardCard(),
            SizedBox(height: 20),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Color(0xFF667EEA),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: clipboardText));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Copied!")),
                );
              },
              icon: Icon(Icons.copy),
              label: Text("Copy to Clipboard", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildClipboardCard() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(
          width: 1.2,
          color: Colors.white.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Row + Copy button inside the card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Synced Clipboard",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF444444),
                ),
              ),

              // Copy icon button
              IconButton(
                icon: Icon(Icons.copy_rounded, color: Color(0xFF667EEA)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: clipboardText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Copied to Clipboard!")),
                  );
                },
              ),
            ],
          ),

          SizedBox(height: 12),

          // A subtle line divider
          Container(
            height: 1,
            color: Colors.grey.withOpacity(0.2),
          ),

          SizedBox(height: 16),

          // Scrollable "note-like" content area
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            padding: EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                clipboardText.isEmpty ? "(empty clipboard)" : clipboardText,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  fontFamily: "monospace",
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          SizedBox(height: 12),

          // Gradient bar decoration at bottom
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}
