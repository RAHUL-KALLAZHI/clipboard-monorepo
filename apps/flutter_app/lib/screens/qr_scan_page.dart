import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QRScanPage extends StatefulWidget {
  final void Function(String) onScanned;
  QRScanPage({required this.onScanned});
  @override
  State<StatefulWidget> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan Pairing QR')),
      body: Column(
        children: <Widget>[
          Expanded(
              flex: 4,
              child: QRView(key: qrKey, onQRViewCreated: _onQRViewCreated)),
          Expanded(child: Center(child: Text('Scan QR shown by desktop'))),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController ctrl) {
    this.controller = ctrl;
    ctrl.scannedDataStream.listen((scanData) {
      widget.onScanned(scanData.code ?? '');
      ctrl.pauseCamera();
      Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
