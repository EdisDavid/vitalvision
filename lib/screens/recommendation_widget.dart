import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

class RecommendationWidget extends StatefulWidget {
  const RecommendationWidget({super.key});

  @override
  _RecommendationWidgetState createState() => _RecommendationWidgetState();
}

class _RecommendationWidgetState extends State<RecommendationWidget> {
  final TextEditingController _controller = TextEditingController();
  String result = "";

  late FlutterTts flutterTts;

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();

    _initTts();
  }

  void _initTts() async {
    await flutterTts.setLanguage("es-ES");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.9);
    await flutterTts.setVolume(1.0);

    flutterTts.setStartHandler(() {
      debugPrint("TTS playing");
    });
    flutterTts.setCompletionHandler(() {
      debugPrint("TTS completed");
    });
    flutterTts.setErrorHandler((msg) {
      debugPrint("TTS error: $msg");
    });
  }

  Future<void> getRecommendation(String word) async {
    final url = Uri.parse('http://localhost:5000/recommend'); // -> Cambiar si el microservicio está remoto
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'word': word}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rec = data['recommendation'] ?? 'No recommendation found';
        setState(() {
          result = rec;
        });
        _speakResult(rec);
      } else {
        setState(() {
          result = 'Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        result = 'Exception: $e';
      });
    }
  }

  Future<void> _speakResult(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Escribe la lesión',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final word = _controller.text.trim();
                if (word.isNotEmpty) getRecommendation(word);
              },
              child: const Text('Obtener recomendación'),
            ),
            const SizedBox(height: 20),
            Text(result, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
