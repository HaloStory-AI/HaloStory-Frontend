import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/p2p_sync_service.dart';
import '../services/localization_service.dart';

class QrScannerScreen extends StatefulWidget {
  final String mode; // 'upload' (salin ke komputer) or 'download' (ambil dari komputer)
  final Map<String, dynamic>? payloadToUpload;
  final Function(Map<String, dynamic>? payload) onComplete;

  const QrScannerScreen({
    super.key,
    required this.mode,
    this.payloadToUpload,
    required this.onComplete,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code.startsWith('http')) {
        // Validate intent with QR
        final uri = Uri.parse(code);
        if ((widget.mode == 'download' && uri.path != '/download') ||
            (widget.mode == 'upload' && uri.path != '/upload')) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('p2p_scanner_invalid_qr'))),
           );
           return;
        }

        setState(() {
          _isProcessing = true;
        });

        _controller.stop();

        try {
          final result = await P2PSyncService.syncWithDesktop(
             code,
             payloadToUpload: widget.payloadToUpload
          );
          if (mounted) {
            widget.onComplete(result);
            Navigator.of(context).pop();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text(tr('p2p_scanner_error').replaceAll('{}', e.toString()))),
            );
            setState(() {
               _isProcessing = false;
            });
            _controller.start();
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.mode == 'download' ? tr('p2p_scanner_receiving') : tr('p2p_scanner_sending')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          
          // Scanner Overlay mask
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2.0),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Text(
              _isProcessing 
                 ? tr('p2p_scanner_processing') 
                 : tr('p2p_scanner_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          
          if (_isProcessing)
             const Center(
                child: CircularProgressIndicator(color: Colors.white),
             )
        ],
      ),
    );
  }
}
