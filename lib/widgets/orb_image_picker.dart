import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the system image picker, then shows the circular crop page.
/// Returns PNG bytes of the cropped circle, or null if cancelled.
Future<Uint8List?> pickAndCropOrbImage(BuildContext context) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 88,
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  if (!context.mounted) return null;

  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _CircularCropPage(bytes: bytes),
    ),
  );
}

// ── Circular crop full-screen page ─────────────────────────────────────────

class _CircularCropPage extends StatefulWidget {
  final Uint8List bytes;
  const _CircularCropPage({required this.bytes});

  @override
  State<_CircularCropPage> createState() => _CircularCropPageState();
}

class _CircularCropPageState extends State<_CircularCropPage> {
  static const double _cropSize = 270.0;

  final _repaintKey = GlobalKey();
  final _ctrl = TransformationController();
  bool _processing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onCrop() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final boundary =
          _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // Capture the square crop area at 2× for quality
      final captured = await boundary.toImage(pixelRatio: 2.0);

      // Clip the captured square to a circle
      final sz = captured.width.toDouble();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, sz, sz));
      canvas.clipPath(
          Path()..addOval(Rect.fromLTWH(0, 0, sz, sz)));
      canvas.drawImage(captured, Offset.zero, Paint());

      final picture = recorder.endRecording();
      final result = await picture.toImage(sz.toInt(), sz.toInt());
      final data =
          await result.toByteData(format: ui.ImageByteFormat.png);

      if (!mounted) return;
      Navigator.of(context).pop(data?.buffer.asUint8List());
    } catch (_) {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07080F),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Text(
              'DRAG & PINCH TO POSITION',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0x77FFFFFF),
                fontSize: 11,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 28),

            // Crop area
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ── The capture target: square interactive image ──────────
                  RepaintBoundary(
                    key: _repaintKey,
                    child: SizedBox.square(
                      dimension: _cropSize,
                      child: ClipRect(
                        child: InteractiveViewer(
                          transformationController: _ctrl,
                          minScale: 0.5,
                          maxScale: 5.0,
                          child: Image.memory(
                            widget.bytes,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Dark vignette outside the circle ─────────────────────
                  IgnorePointer(
                    child: CustomPaint(
                      size: const Size(_cropSize + 120, _cropSize + 120),
                      painter: _VignettePainter(radius: _cropSize / 2),
                    ),
                  ),

                  // ── Glowing ring ──────────────────────────────────────────
                  IgnorePointer(
                    child: Container(
                      width: _cropSize,
                      height: _cropSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF00FFEE),
                          width: 2.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x5500FFEE),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CropBtn(
                  label: 'CANCEL',
                  color: const Color(0x55FFFFFF),
                  onTap: () => Navigator.of(context).pop(null),
                ),
                const SizedBox(width: 20),
                _CropBtn(
                  label: _processing ? '...' : 'USE THIS',
                  color: const Color(0xFF00FFEE),
                  filled: true,
                  onTap: _processing ? null : _onCrop,
                ),
              ],
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

// ── Vignette: dark everywhere except inside the crop circle ─────────────────

class _VignettePainter extends CustomPainter {
  final double radius;
  const _VignettePainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = const Color(0xE607080F));
  }

  @override
  bool shouldRepaint(_VignettePainter old) => old.radius != radius;
}

// ── Crop button ───────────────────────────────────────────────────────────────

class _CropBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  const _CropBtn({
    required this.label,
    required this.color,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: filled ? color : Colors.transparent,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: filled ? const Color(0xFF07080F) : color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}
