import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img_lib;
import 'tips_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isCameraReady = false;
  List<CameraDescription>? _cameras;

  Interpreter? _interpreter;
  List<String> _labels = [];
  String _currentLabel = '';
  double _currentScore = 0.0;
  bool _isProcessingFrame = false;
  int _lastProcessMs = 0;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
    _loadModelAndLabels();
  }

  // Pedir permiso de cámara
  Future<void> _checkCameraPermission() async {
    var status = await Permission.camera.status;

    if (!status.isGranted) {
      status = await Permission.camera.request();
    }

    if (status.isGranted) {
      _initCamera();
    } else {
      // Usuario denegó el permiso
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de cámara denegado')),
        );
      }
    }
  }

  // Inicializar la cámara
  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras!.first,
        ResolutionPreset.medium,
      );

      try {
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraReady = true;
          });
        }
        // Iniciar stream de imagen para detección en tiempo real
        await _controller!.startImageStream(_processCameraImage);
      } catch (e) {
        debugPrint('Error inicializando cámara: $e');
      }
    } else {
      debugPrint('No se encontró ninguna cámara');
    }
  }

  void _processCameraImage(CameraImage cameraImage) async {
    if (_interpreter == null) return;
    if (_isProcessingFrame) return; // throttling simple
    _isProcessingFrame = true;

    try {
      // Throttle to at most one inference every 400ms
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastProcessMs < 400) return;
      _lastProcessMs = now;

      // Convert YUV420 to RGB image using package:image
      final img = _convertYUV420ToImage(cameraImage);
      if (img == null) return;

      // Resize to model input
      final inputSize = 224;
      final resized = img_lib.copyResize(img, width: inputSize, height: inputSize);

      // Build input NHWC [1, h, w, 3]
      final height = resized.height;
      final width = resized.width;
      final imgBytes = resized.getBytes();
      final input = List.generate(1, (_) => List.generate(height, (_) => List.generate(width, (_) => List.filled(3, 0.0))));

      final int pixels = width * height;
      final int bpp = imgBytes.length ~/ pixels; // bytes per pixel (3 or 4)

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final idx = (y * width + x) * bpp;
          if (idx + 2 >= imgBytes.length) continue; // safety
          final r = imgBytes[idx] / 255.0;
          final g = imgBytes[idx + 1] / 255.0;
          final b = imgBytes[idx + 2] / 255.0;
          input[0][y][x][0] = r;
          input[0][y][x][1] = g;
          input[0][y][x][2] = b;
        }
      }

      // Prepare output buffer
      final outputTensors = _interpreter?.getOutputTensors();
      if (outputTensors == null || outputTensors.isEmpty) return;
      final outShape = outputTensors[0].shape;
      final outLen = outShape.reduce((a, b) => a * b);
      final output = List.filled(outLen, 0.0);

      _interpreter?.run(input, output);

      // Find best
      int best = 0;
      for (int i = 1; i < output.length; i++) {
        if (output[i] > output[best]) best = i;
      }
      final score = output[best];
      final label = (best < _labels.length) ? _labels[best] : 'desconocido';

      if (mounted) {
        setState(() {
          _currentLabel = label;
          _currentScore = score;
        });
      }
    } catch (e) {
      debugPrint('Error procesando frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  img_lib.Image? _convertYUV420ToImage(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
  final img = img_lib.Image(width: width, height: height);

      final uvRowStride = image.planes[1].bytesPerRow;
      final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yp = image.planes[0].bytes[y * image.planes[0].bytesPerRow + x];

          final uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];

          int yVal = yp;
          int u = up - 128;
          int v = vp - 128;

          int r = (yVal + 1.403 * v).round();
          int g = (yVal - 0.344 * u - 0.714 * v).round();
          int b = (yVal + 1.770 * u).round();

          r = r.clamp(0, 255);
          g = g.clamp(0, 255);
          b = b.clamp(0, 255);

          img.setPixelRgba(x, y, r, g, b, 255);
        }
      }
      return img;
    } catch (e) {
      debugPrint('Error converting YUV420: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _loadModelAndLabels() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/best_float32.tflite');
      final rawLabels = await rootBundle.loadString('assets/models/labels.txt');
      _labels = rawLabels
          .split(RegExp(r"\r?\n"))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      debugPrint('Modelo y etiquetas cargadas: ${_labels.length} labels');
    } catch (e) {
      debugPrint('Error cargando modelo o etiquetas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cámara IA'),
      ),
      body: _isCameraReady
          ? GestureDetector(
              onTap: () async {
                // Tomar una foto y procesar
                try {
                  // Detener temporalmente el stream para tomar foto sin conflictos
                  try { await _controller?.stopImageStream(); } catch (_) {}
                  final file = await _controller!.takePicture();
                  final bytes = await file.readAsBytes();

                  // Preprocess usando package:image
                  final image = img_lib.decodeImage(bytes);
                  if (image == null) {
                    debugPrint('No se pudo decodificar la imagen');
                    return;
                  }

                  // Adaptar tamaño si el modelo necesita un tamaño específico
                  // Aquí asumimos que el modelo acepta 224x224. Ajusta según tu modelo.
                  final inputSize = 224;
                  final resized = img_lib.copyResize(image, width: inputSize, height: inputSize);

                  // Preparar entrada: convertir la imagen redimensionada a float32 normalizado [0,1]
                  final int width = resized.width;
                  final int height = resized.height;
                  // input shape: [1, height, width, 3]
                  final input = List.generate(1, (_) => List.generate(height, (_) => List.generate(width, (_) => List.filled(3, 0.0))));

                  // Obtener bytes RGBA planos
                  final imgBytes = resized.getBytes();
                  for (int y = 0; y < height; y++) {
                    for (int x = 0; x < width; x++) {
                      final idx = (y * width + x) * 4;
                      final r = imgBytes[idx] / 255.0;
                      final g = imgBytes[idx + 1] / 255.0;
                      final b = imgBytes[idx + 2] / 255.0;
                      input[0][y][x][0] = r;
                      input[0][y][x][1] = g;
                      input[0][y][x][2] = b;
                    }
                  }

                  // Preparar buffer de salida asumiendo un vector de scores
                  // Intentamos descubrir la forma del tensor de salida
                  final outputTensors = _interpreter?.getOutputTensors();
                  if (outputTensors == null || outputTensors.isEmpty) {
                    debugPrint('No se encontraron tensores de salida');
                    return;
                  }
                  final outShape = outputTensors[0].shape;
                  final outLen = outShape.reduce((a, b) => a * b);
                  final output = List.filled(outLen, 0.0);

                  try {
                    _interpreter?.run(input, output);
                  } catch (e) {
                    debugPrint('Error ejecutando intérprete: $e');
                    return;
                  }

                  // scores list
                  final scores = output.map((e) => e.toDouble()).toList();

                  int best = 0;
                  for (int i = 1; i < scores.length; i++) {
                    if (scores[i] > scores[best]) best = i;
                  }

                  final detected = (best < _labels.length) ? _labels[best] : 'desconocido';

                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TipsScreen(label: detected)),
                    );
                  }
                  // Reiniciar el stream
                  try { await _controller?.startImageStream(_processCameraImage); } catch (_) {}
                } catch (e) {
                  debugPrint('Error tomando foto o procesando: $e');
                }
              },
              child: CameraPreview(_controller!),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
