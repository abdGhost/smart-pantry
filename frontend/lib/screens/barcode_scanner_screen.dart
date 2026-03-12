import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/colors.dart';
import '../core/responsive.dart';
import '../providers/pantry_provider.dart';

/// Screen that opens the camera and scans a barcode, then adds the product to the pantry.
/// Uses Open Food Facts to resolve barcode to product name when possible.
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String?> _lookupProductName(String barcode) async {
    final dio = ref.read(dioProvider);
    try {
      final res = await dio.get<Map<String, dynamic>>(
        'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final data = res.data;
      if (data == null) return null;
      final status = data['status'] as int?;
      if (status != 1) return null;
      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;
      final name = product['product_name'] as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
      final generic = product['generic_name'] as String?;
      if (generic != null && generic.trim().isNotEmpty) return generic.trim();
    } catch (_) {
      // Ignore; fall back to barcode as name
    }
    return null;
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing || _hasScanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _isProcessing = true;
    final productName = await _lookupProductName(raw);
    final itemName = productName ?? 'Barcode $raw';

    final userId = ref.read(userIdProvider);
    final notifier = ref.read(pantryNotifierProvider(userId).notifier);
    final added = await notifier.addSingleItem(itemName: itemName);

    _hasScanned = true;
    _isProcessing = false;

    if (!mounted) return;
    Navigator.of(context).pop(added != null ? itemName : null);
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final r = Responsive.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Scan Barcode',
          style: r.titleStyle(context, fontSize: r.isNarrow ? 17 : 18).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(
            isIOS ? CupertinoIcons.back : Icons.arrow_back_rounded,
            size: r.isNarrow ? 22 : 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
            errorBuilder: (context, error, child) => Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: r.horizontalPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_rounded,
                      size: r.isNarrow ? 48 : 64,
                      color: Colors.white70,
                    ),
                    SizedBox(height: r.isNarrow ? 12 : 16),
                    Text(
                      error.errorDetails?.message ?? 'Camera error',
                      textAlign: TextAlign.center,
                      style: r.bodyStyle(context).copyWith(
                        color: Colors.white70,
                        fontSize: r.isNarrow ? 13 : 14,
                      ),
                    ),
                    SizedBox(height: r.isNarrow ? 18 : 24),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Close', style: r.bodyStyle(context).copyWith(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: r.isNarrow ? 12 : 16),
                    Text(
                      'Adding to pantry…',
                      style: r.bodyStyle(context).copyWith(
                        color: Colors.white,
                        fontSize: r.isNarrow ? 14 : 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.all(r.isNarrow ? 16 : 24),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.isNarrow ? 14 : 16,
                    vertical: r.isNarrow ? 10 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(r.isNarrow ? 14 : 16),
                  ),
                  child: Text(
                    'Point your camera at a product barcode',
                    style: r.bodyStyle(context, fontSize: r.isNarrow ? 13 : 14).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
