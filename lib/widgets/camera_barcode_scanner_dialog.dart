import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/constants.dart';
import '../services/feedback_service.dart';

/// Function type that processes a scanned barcode value.
/// Returns an optional feedback String message to display briefly in the scanner UI.
typedef BarcodeScanCallback = String? Function(String barcode);

class CameraBarcodeScannerDialog extends StatefulWidget {
  final String title;
  final BarcodeScanCallback onScanned;
  final bool continuous;

  const CameraBarcodeScannerDialog({
    super.key,
    this.title = 'Scan Product Barcode',
    required this.onScanned,
    this.continuous = false,
  });

  /// Helper static method to open the scanner dialog cleanly.
  static Future<String?> show(
    BuildContext context, {
    String title = 'Scan Product Barcode',
    required BarcodeScanCallback onScanned,
    bool continuous = false,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CameraBarcodeScannerDialog(
        title: title,
        onScanned: onScanned,
        continuous: continuous,
      ),
    );
  }

  @override
  State<CameraBarcodeScannerDialog> createState() => _CameraBarcodeScannerDialogState();
}

class _CameraBarcodeScannerDialogState extends State<CameraBarcodeScannerDialog> {
  late MobileScannerController _controller;
  bool _isTorchOn = false;
  bool _isProcessingScan = false;
  String? _feedbackMessage;
  bool _isFeedbackSuccess = true;
  DateTime? _lastScanTime;
  String? _lastScannedBarcode;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcodeDetect(BarcodeCapture capture) async {
    if (_isProcessingScan) return;

    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        final cleanValue = rawValue.trim();

        // Throttle duplicate scans within 1.5s if in continuous mode
        final now = DateTime.now();
        if (_lastScannedBarcode == cleanValue &&
            _lastScanTime != null &&
            now.difference(_lastScanTime!).inMilliseconds < 1500) {
          return;
        }

        setState(() {
          _isProcessingScan = true;
          _lastScannedBarcode = cleanValue;
          _lastScanTime = now;
        });

        // Play high-pitch barcode scanner beep audio + heavy haptic vibration
        FeedbackService.playScannerBeep();

        final feedback = widget.onScanned(cleanValue);
        final isSuccess = feedback != null && !feedback.toLowerCase().contains('no product') && !feedback.toLowerCase().contains('error') && !feedback.toLowerCase().contains('not found');

        if (mounted) {
          setState(() {
            _feedbackMessage = feedback ?? 'Scanned: $cleanValue';
            _isFeedbackSuccess = isSuccess;
          });
        }

        if (!widget.continuous) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            Navigator.of(context).pop(cleanValue);
          }
          return;
        }

        // Delay to allow user to re-target next barcode
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          setState(() {
            _isProcessingScan = false;
            _feedbackMessage = null;
          });
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        color: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.colorScheme.surface,
              child: Row(
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: _isTorchOn ? Colors.amber : Colors.grey,
                    ),
                    tooltip: 'Toggle Flashlight',
                    onPressed: () {
                      _controller.toggleTorch();
                      setState(() {
                        _isTorchOn = !_isTorchOn;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close Scanner',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Camera View & Scanner Overlay
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _handleBarcodeDetect,
                    errorBuilder: (context, error, child) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        color: Colors.black,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt_outlined, color: Colors.redAccent, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Camera Access Required',
                              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Please grant camera permission in your phone settings to scan barcodes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Scanner Framing Box Overlay
                  Container(
                    width: 240,
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isProcessingScan
                            ? (_isFeedbackSuccess ? AppColors.accentGreen : Colors.redAccent)
                            : theme.colorScheme.primary,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.transparent,
                    ),
                  ),

                  // Scanning Prompt Banner
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.continuous
                              ? 'Point camera at barcode (Continuous Mode)'
                              : 'Align barcode inside the frame',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),

                  // Scanned Feedback Toast Overlay
                  if (_feedbackMessage != null)
                    Positioned(
                      bottom: 20,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isFeedbackSuccess ? AppColors.accentGreen : Colors.red,
                          borderRadius: BorderRadius.circular(AppRadius.m),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isFeedbackSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _feedbackMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: theme.colorScheme.surface,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.continuous ? 'Continuous Scan Active' : 'Single Scan Mode',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.done_rounded, size: 18),
                    label: Text(widget.continuous ? 'Done Scanning' : 'Cancel'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
