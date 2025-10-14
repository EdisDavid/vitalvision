import 'package:flutter/material.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cámara IA'),
      ),
      body: const Center(
        child: Text(
          'Aquí irá la cámara con IA',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
