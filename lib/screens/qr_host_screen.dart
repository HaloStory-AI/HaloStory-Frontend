import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/p2p_sync_service.dart';
import '../services/localization_service.dart';

class QrHostScreen extends StatefulWidget {
  final String mode; // 'download' (menyalin dari desktop) or 'upload' (mengirim ke desktop)
  final Future<Map<String, dynamic>> Function()? getDownloadPayload;
  final Function(Map<String, dynamic> payload)? onUploadReceived;

  const QrHostScreen({
    super.key,
    required this.mode,
    this.getDownloadPayload,
    this.onUploadReceived,
  });

  @override
  State<QrHostScreen> createState() => _QrHostScreenState();
}

class _QrHostScreenState extends State<QrHostScreen> {
  String? _qrData;
  bool _isLoading = true;
  String _statusMessage = tr('p2p_host_running');

  @override
  void initState() {
    super.initState();
    _startHost();
  }

  Future<void> _startHost() async {
    try {
      final uri = await P2PSyncService.startHost(
        mode: widget.mode,
        getDownloadPayload: widget.getDownloadPayload ?? () async => {},
        onUploadReceived: (payload) {
          if (mounted) {
            setState(() {
              _statusMessage = tr('p2p_host_received');
            });
            if (widget.onUploadReceived != null) {
              widget.onUploadReceived!(payload);
            }
          }
        },
        onTimeout: () {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text(tr('p2p_host_timeout'))),
            );
          }
        },
      );

      if (mounted) {
        setState(() {
          _qrData = uri;
          _isLoading = false;
          _statusMessage = widget.mode == 'download' 
              ? tr('p2p_host_scan_download') 
              : tr('p2p_host_scan_upload');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = tr('p2p_host_failed').replaceAll('{}', e.toString());
        });
      }
    }
  }

  @override
  void dispose() {
    P2PSyncService.stopHost();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      appBar: AppBar(
        title: Text(tr('p2p_host_title'), style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_qrData != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: QrImageView(
                  data: _qrData!,
                  version: QrVersions.auto,
                  size: 300.0,
                  backgroundColor: Colors.white,
                ),
              ),
            const SizedBox(height: 32),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 18, color: Colors.blueGrey, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (!_isLoading && _qrData != null) ...[
              const SizedBox(height: 16),
              Text(
                tr('p2p_host_connection_note'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
