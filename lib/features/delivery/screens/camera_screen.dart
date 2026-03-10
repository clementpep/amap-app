import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../data/ocr_service.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/theme/app_theme.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitializing = true;
  bool _isTakingPhoto = false;
  bool _flashOn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _error = 'Aucune caméra disponible.';
          _isInitializing = false;
        });
        return;
      }
      final camera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Impossible d\'initialiser la caméra.';
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() => _isTakingPhoto = true);

    try {
      final file = await _controller!.takePicture();
      await _processImage(file.path);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Erreur lors de la capture.');
    } finally {
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked != null && mounted) {
      await _processImage(picked.path);
    }
  }

  Future<void> _processImage(String imagePath) async {
    if (!mounted) return;
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Padding(
          padding: EdgeInsets.all(24),
          child: LoadingWidget(message: 'Lecture du texte en cours...'),
        ),
      ),
    );

    try {
      final ocrService = ref.read(ocrServiceProvider);
      final lines = await ocrService.recognizeText(imagePath);

      if (mounted) {
        Navigator.of(context).pop(); // close loading dialog
        context.push('/deliveries/ocr-review', extra: {
          'imagePath': imagePath,
          'lines': lines,
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        showErrorSnackbar(context, 'Erreur OCR. Essayez avec une photo plus nette.');
        // Go to basket form anyway, user can input manually
        context.push('/deliveries/basket-form', extra: {'imagePath': imagePath});
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Prendre une photo'),
        actions: [
          IconButton(
            icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              final newMode = _flashOn ? FlashMode.off : FlashMode.torch;
              await _controller?.setFlashMode(newMode);
              setState(() => _flashOn = !_flashOn);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isInitializing
                ? const LoadingWidget(message: 'Initialisation caméra...')
                : _error != null
                    ? ErrorWidget(
                        message: _error!,
                        onRetry: () {
                          setState(() {
                            _isInitializing = true;
                            _error = null;
                          });
                          _initCamera();
                        },
                      )
                    : _controller != null
                        ? CameraPreview(_controller!)
                        : const SizedBox(),
          ),
          // Bottom controls
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery button
                IconButton(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined,
                      color: Colors.white, size: 32),
                ),
                // Shutter button
                GestureDetector(
                  onTap: _isTakingPhoto ? null : _takePicture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _isTakingPhoto ? Colors.grey : Colors.white,
                    ),
                    child: _isTakingPhoto
                        ? const CircularProgressIndicator(color: Colors.grey)
                        : null,
                  ),
                ),
                // Skip button (go straight to form)
                TextButton(
                  onPressed: () => context.push('/deliveries/basket-form'),
                  child: const Text(
                    'Passer',
                    style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
